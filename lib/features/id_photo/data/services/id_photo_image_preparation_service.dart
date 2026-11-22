import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/image_processing/data/datasources/heic_conversion_data_source.dart';
import '../../../../core/image_processing/data/datasources/image_format_detector.dart';
import '../../../../core/image_processing/data/datasources/native_image_codec.dart';

/// Creates an upright JPEG for the native cropper using the platform image
/// decoder. No Dart bitmap decode/encode or pixel iteration is involved.
class IdPhotoImagePreparationService {
  IdPhotoImagePreparationService({
    NativeImageCodec? nativeCodec,
    HeicConversionDataSource? heicConverter,
  })  : _nativeCodec = nativeCodec ?? const PlatformNativeImageCodec(),
        _heicConverter = heicConverter ?? HeicConversionDataSource();

  final NativeImageCodec _nativeCodec;
  final HeicConversionDataSource _heicConverter;
  static const Uuid _uuid = Uuid();

  Future<String> prepareForCrop(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const FileSystemException('فایل تصویر پیدا نشد.');
    final size = await source.length();
    if (size <= 0 || size > 120 * 1024 * 1024) {
      throw const FileSystemException('حجم تصویر ورودی معتبر نیست.');
    }
    final handle = await source.open();
    late final List<int> header;
    try {
      header = await handle.read(64);
    } finally {
      await handle.close();
    }
    final format = ImageFormatDetector.detect(
      // Header signatures only; no image allocation.
      Uint8List.fromList(header), sourcePath,
    );
    if (!ImageFormatDetector.isSupported(format)) {
      throw FormatException('فرمت تصویر پشتیبانی نمی‌شود: $format');
    }
    final cache = await getTemporaryDirectory();
    final workingDirectory = Directory(
      '${cache.path}${Platform.pathSeparator}pixelsaz_pro'
      '${Platform.pathSeparator}id_photo_work',
    );
    await workingDirectory.create(recursive: true);
    final output = File('${workingDirectory.path}${Platform.pathSeparator}${_uuid.v4()}_upright.jpg');
    String currentPath = sourcePath;
    File? heifFallback;
    try {
      NativeEncodeResult result;
      try {
        result = await _nativeCodec.encode(NativeEncodeRequest(
          inputPath: currentPath, sourceFormat: format,
          minQuality: 90, maxQuality: 98, resizeTriggerQuality: 72,
          minShortEdge: 160, idPhoto: false,
        ));
      } catch (_) {
        if (!ImageFormatDetector.isHeif(format)) rethrow;
        final bytes = await _heicConverter.convertToJpeg(sourcePath);
        heifFallback = File('${workingDirectory.path}${Platform.pathSeparator}${_uuid.v4()}_heif.jpg');
        await heifFallback.writeAsBytes(bytes, flush: false);
        currentPath = heifFallback.path;
        result = await _nativeCodec.encode(NativeEncodeRequest(
          inputPath: currentPath, sourceFormat: 'jpeg',
          minQuality: 90, maxQuality: 98, resizeTriggerQuality: 72,
          minShortEdge: 160, idPhoto: false,
        ));
      }
      await output.writeAsBytes(result.bytes, flush: false);
      return output.path;
    } finally {
      try { if (heifFallback != null && await heifFallback.exists()) await heifFallback.delete(); } catch (_) { }
    }
  }
}
