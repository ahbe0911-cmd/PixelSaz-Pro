import 'dart:io';
import 'dart:typed_data';

import '../../../errors/image_processing_exception.dart';
import '../../domain/entities/image_compression_options.dart';
import '../../domain/entities/image_processing_progress.dart';
import '../../domain/entities/image_processing_result.dart';
import '../../domain/repositories/image_processing_repository.dart';
import '../datasources/heic_conversion_data_source.dart';
import '../datasources/image_format_detector.dart';
import '../datasources/image_processing_isolate.dart';

/// Public processing engine used by the application and feature use cases.
///
/// HEIC/HEIF conversion is delegated to a native platform plugin on the root
/// isolate. Decoding, orientation normalization, resizing, JPEG encoding,
/// target-size search and DPI metadata injection run in a worker isolate.
class ImageProcessingService implements ImageProcessingRepository {
  ImageProcessingService({
    HeicConversionDataSource? heicConversionDataSource,
    ImageProcessingIsolate? processingIsolate,
  })  : _heicConversionDataSource = heicConversionDataSource ?? HeicConversionDataSource(),
        _processingIsolate = processingIsolate ?? ImageProcessingIsolate();

  static const int maximumInputBytes = 120 * 1024 * 1024;

  final HeicConversionDataSource _heicConversionDataSource;
  final ImageProcessingIsolate _processingIsolate;

  @override
  Future<ImageProcessingResult> compressToJpeg({
    required String inputPath,
    ImageCompressionOptions options = const ImageCompressionOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) async {
    options.validate();
    return _processFile(
      inputPath: inputPath,
      options: options.toWorkerMap(),
      idPhoto: false,
      onProgress: onProgress,
    );
  }

  @override
  Future<ImageProcessingResult> createIdPhotoJpeg({
    required String inputPath,
    IdPhotoOptions options = const IdPhotoOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) async {
    options.validate();
    return _processFile(
      inputPath: inputPath,
      options: options.toWorkerMap(),
      idPhoto: true,
      onProgress: onProgress,
    );
  }

  Future<ImageProcessingResult> _processFile({
    required String inputPath,
    required Map<String, Object?> options,
    required bool idPhoto,
    ImageProcessingProgressCallback? onProgress,
  }) async {
    if (inputPath.trim().isEmpty) {
      throw const ImageProcessingException(
        code: 'empty_input_path',
        message: 'مسیر فایل ورودی مشخص نشده است.',
      );
    }

    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw ImageProcessingException(
        code: 'input_file_not_found',
        message: 'فایل ورودی پیدا نشد: $inputPath',
      );
    }

    final inputLength = await inputFile.length();
    if (inputLength <= 0) {
      throw const ImageProcessingException(
        code: 'empty_input_file',
        message: 'فایل ورودی خالی است.',
      );
    }
    if (inputLength > maximumInputBytes) {
      throw const ImageProcessingException(
        code: 'input_file_too_large',
        message: 'حجم فایل ورودی از سقف پشتیبانی‌شده ۱۲۰ مگابایت بیشتر است.',
      );
    }

    onProgress?.call(
      const ImageProcessingProgress(fraction: 0.02, stage: 'reading_source'),
    );

    final originalBytes = await inputFile.readAsBytes();
    final sourceFormat = ImageFormatDetector.detect(originalBytes, inputPath);
    if (!ImageFormatDetector.isSupported(sourceFormat)) {
      throw ImageProcessingException(
        code: 'unsupported_image_format',
        message: 'فرمت تصویر پشتیبانی نمی‌شود: ${sourceFormat.toUpperCase()}.',
      );
    }

    Uint8List processingBytes;
    if (ImageFormatDetector.isHeif(sourceFormat)) {
      onProgress?.call(
        const ImageProcessingProgress(fraction: 0.06, stage: 'converting_heic'),
      );
      processingBytes = await _heicConversionDataSource.convertToJpeg(inputPath);
    } else {
      processingBytes = originalBytes;
    }

    if (processingBytes.length > maximumInputBytes) {
      throw const ImageProcessingException(
        code: 'decoded_input_too_large',
        message: 'حجم فایل پس از تبدیل اولیه از سقف پشتیبانی‌شده ۱۲۰ مگابایت بیشتر است.',
      );
    }

    final result = await _processingIsolate.process(
      sourceBytes: processingBytes,
      originalSizeBytes: originalBytes.length,
      sourceFormat: sourceFormat,
      options: options,
      idPhoto: idPhoto,
      onProgress: onProgress,
    );

    onProgress?.call(
      ImageProcessingProgress(
        fraction: 1,
        stage: 'complete',
        quality: result.quality,
        width: result.width,
        height: result.height,
      ),
    );
    return result;
  }
}
