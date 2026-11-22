import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../errors/image_processing_exception.dart';
import '../../domain/entities/image_compression_options.dart';
import '../../domain/entities/image_processing_progress.dart';
import '../../domain/entities/image_processing_result.dart';
import '../../domain/repositories/image_processing_repository.dart';
import '../datasources/fast_jpeg_dpi_patcher.dart';
import '../datasources/heic_conversion_data_source.dart';
import '../datasources/image_format_detector.dart';
import '../datasources/jpeg_dimension_reader.dart';
import '../datasources/native_image_codec.dart';

/// Runs JPEG conversion on platform image codecs, not Dart pixel processing.
///
/// A file is decoded only by the native image pipeline. Android decodes the
/// bitmap once per image; Apple uses the platform-native compression plugin.
/// Output bytes are returned for compatibility with export use cases.
class ImageProcessingService implements ImageProcessingRepository {
  ImageProcessingService({
    NativeImageCodec? nativeCodec,
    HeicConversionDataSource? heicConversionDataSource,
  })  : _nativeCodec = nativeCodec ?? const PlatformNativeImageCodec(),
        _heicConverter = heicConversionDataSource ?? HeicConversionDataSource();

  static const int maximumInputBytes = 120 * 1024 * 1024;
  final NativeImageCodec _nativeCodec;
  final HeicConversionDataSource _heicConverter;

  @override
  Future<ImageProcessingResult> compressToJpeg({
    required String inputPath,
    ImageCompressionOptions options = const ImageCompressionOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) {
    options.validate();
    return _process(
      inputPath: inputPath,
      targetBytes: options.targetBytes,
      minQuality: options.minQuality,
      maxQuality: options.maxQuality,
      resizeTriggerQuality: options.resizeTriggerQuality,
      minShortEdge: options.minShortEdge,
      preserveSmallJpeg: options.preserveOriginalIfAlreadyUnderTarget,
      idPhoto: false,
      onProgress: onProgress,
    );
  }

  @override
  Future<ImageProcessingResult> createIdPhotoJpeg({
    required String inputPath,
    IdPhotoOptions options = const IdPhotoOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) {
    options.validate();
    return _process(
      inputPath: inputPath,
      targetBytes: options.targetBytes,
      minQuality: options.minQuality,
      maxQuality: options.maxQuality,
      resizeTriggerQuality: 72,
      minShortEdge: 160,
      preserveSmallJpeg: false,
      idPhoto: true,
      onProgress: onProgress,
    );
  }

  Future<ImageProcessingResult> _process({
    required String inputPath,
    required int? targetBytes,
    required int minQuality,
    required int maxQuality,
    required int resizeTriggerQuality,
    required int minShortEdge,
    required bool preserveSmallJpeg,
    required bool idPhoto,
    ImageProcessingProgressCallback? onProgress,
  }) async {
    if (inputPath.trim().isEmpty) {
      throw const ImageProcessingException(
        code: 'empty_input_path', message: 'مسیر تصویر مشخص نشده است.',
      );
    }
    final source = File(inputPath);
    if (!await source.exists()) {
      throw const ImageProcessingException(
        code: 'input_missing', message: 'فایل ورودی پیدا نشد.',
      );
    }
    final inputLength = await source.length();
    if (inputLength <= 0 || inputLength > maximumInputBytes) {
      throw const ImageProcessingException(
        code: 'invalid_input_size', message: 'حجم تصویر باید بین ۱ بایت و ۱۲۰ مگابایت باشد.',
      );
    }
    onProgress?.call(const ImageProcessingProgress(fraction: 0.05, stage: 'reading_source'));
    final handle = await source.open();
    late final Uint8List header;
    try {
      header = await handle.read(64);
    } finally {
      await handle.close();
    }
    final sourceFormat = ImageFormatDetector.detect(header, inputPath);
    if (!ImageFormatDetector.isSupported(sourceFormat)) {
      throw ImageProcessingException(
        code: 'unsupported_format', message: 'فرمت ${sourceFormat.toUpperCase()} پشتیبانی نمی‌شود.',
      );
    }

    if (!idPhoto && preserveSmallJpeg && sourceFormat == 'jpeg' &&
        targetBytes != null && inputLength <= targetBytes) {
      final bytes = await source.readAsBytes();
      final dimensions = JpegDimensionReader.read(bytes);
      if (dimensions != null) {
        onProgress?.call(const ImageProcessingProgress(fraction: 1, stage: 'complete'));
        return ImageProcessingResult(
          bytes: bytes, originalSizeBytes: inputLength,
          outputSizeBytes: bytes.length, width: dimensions.$1, height: dimensions.$2,
          quality: 100, resizeCount: 0, targetReached: true,
          sourceFormat: sourceFormat, dpi300Applied: false, wasReencoded: false,
        );
      }
    }

    onProgress?.call(const ImageProcessingProgress(fraction: 0.17, stage: 'compressing'));
    final request = NativeEncodeRequest(
      inputPath: inputPath,
      sourceFormat: sourceFormat,
      targetBytes: targetBytes,
      minQuality: minQuality,
      maxQuality: maxQuality,
      resizeTriggerQuality: resizeTriggerQuality.clamp(minQuality, maxQuality).toInt(),
      minShortEdge: minShortEdge,
      idPhoto: idPhoto,
    );
    NativeEncodeResult nativeResult;
    try {
      nativeResult = await _nativeCodec.encode(request);
    } on PlatformException catch (error) {
      if (!ImageFormatDetector.isHeif(sourceFormat)) {
        throw ImageProcessingException(
          code: 'native_processing_failed',
          message: 'پردازش تصویر با موتور نیتیو ناموفق بود: ${error.message ?? error.code}',
          cause: error,
        );
      }
      // Older Android devices may not decode HEIC natively. Convert once
      // with the dedicated native HEIF plugin, then use the native JPEG engine.
      onProgress?.call(const ImageProcessingProgress(fraction: 0.27, stage: 'converting_heic'));
      final bytes = await _heicConverter.convertToJpeg(inputPath);
      final cache = await getTemporaryDirectory();
      final fallback = File('${cache.path}${Platform.pathSeparator}heif_${const Uuid().v4()}.jpg');
      try {
        await fallback.writeAsBytes(bytes, flush: false);
        nativeResult = await _nativeCodec.encode(NativeEncodeRequest(
          inputPath: fallback.path,
          sourceFormat: 'jpeg',
          targetBytes: targetBytes,
          minQuality: minQuality,
          maxQuality: maxQuality,
          resizeTriggerQuality: resizeTriggerQuality.clamp(minQuality, maxQuality).toInt(),
          minShortEdge: minShortEdge,
          idPhoto: idPhoto,
        ));
      } finally {
        try { if (await fallback.exists()) await fallback.delete(); } catch (_) { }
      }
    }

    onProgress?.call(const ImageProcessingProgress(fraction: 0.92, stage: 'finalizing'));
    if (nativeResult.bytes.isEmpty || nativeResult.width <= 0 || nativeResult.height <= 0) {
      throw const ImageProcessingException(
        code: 'invalid_native_output', message: 'موتور نیتیو تصویر JPEG معتبری برنگرداند.',
      );
    }
    if (nativeResult.passCount < 1 || nativeResult.passCount > 3) {
      throw const ImageProcessingException(
        code: 'invalid_native_pass_count', message: 'تعداد تلاش‌های موتور نیتیو نامعتبر است.',
      );
    }
    if (idPhoto && (nativeResult.width != 354 || nativeResult.height != 472)) {
      throw const ImageProcessingException(
        code: 'id_photo_size_mismatch',
        message: 'ابعاد عکس پرسنلی باید دقیقاً ۳۵۴×۴۷۲ پیکسل باشد.',
      );
    }
    final output = idPhoto
        ? FastJpegDpiPatcher.apply300Dpi(nativeResult.bytes)
        : nativeResult.bytes;
    final dimensions = JpegDimensionReader.read(output);
    if (dimensions == null ||
        dimensions.$1 != nativeResult.width || dimensions.$2 != nativeResult.height) {
      throw const ImageProcessingException(
        code: 'incorrect_jpeg_dimensions', message: 'ابعاد JPEG خروجی قابل تأیید نیست.',
      );
    }
    final result = ImageProcessingResult(
      bytes: output,
      originalSizeBytes: inputLength,
      outputSizeBytes: output.length,
      width: nativeResult.width,
      height: nativeResult.height,
      quality: nativeResult.quality,
      resizeCount: nativeResult.resizeCount,
      targetReached: targetBytes == null || output.length <= targetBytes,
      sourceFormat: sourceFormat,
      dpi300Applied: idPhoto,
      wasReencoded: true,
    );
    onProgress?.call(ImageProcessingProgress(
      fraction: 1, stage: 'complete', quality: result.quality,
      width: result.width, height: result.height,
    ));
    return result;
  }
}
