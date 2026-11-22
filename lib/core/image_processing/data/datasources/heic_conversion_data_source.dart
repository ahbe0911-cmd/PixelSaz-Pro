import 'dart:io';
import 'dart:typed_data';

import 'package:heif_converter/heif_converter.dart';

import '../../../errors/image_processing_exception.dart';

/// HEIC/HEIF is decoded by the platform-native ImageIO/Android pipeline.
/// This method must run on the root isolate because the plugin uses a platform
/// channel. The resulting JPEG bytes are then passed to the Dart worker isolate.
class HeicConversionDataSource {
  Future<Uint8List> convertToJpeg(String inputPath) async {
    String? convertedPath;
    try {
      convertedPath = await HeifConverter.convert(inputPath, format: 'jpg');
      if (convertedPath == null || convertedPath.isEmpty) {
        throw const ImageProcessingException(
          code: 'heic_conversion_failed',
          message: 'مبدل HEIC نتوانست فایل را به JPEG تبدیل کند.',
        );
      }

      final convertedFile = File(convertedPath);
      if (!await convertedFile.exists()) {
        throw const ImageProcessingException(
          code: 'heic_output_missing',
          message: 'فایل JPEG تولیدشده توسط مبدل HEIC پیدا نشد.',
        );
      }

      final bytes = await convertedFile.readAsBytes();
      if (bytes.isEmpty) {
        throw const ImageProcessingException(
          code: 'heic_output_empty',
          message: 'فایل JPEG تولیدشده خالی است.',
        );
      }
      return bytes;
    } on ImageProcessingException {
      rethrow;
    } catch (error) {
      throw ImageProcessingException(
        code: 'heic_conversion_exception',
        message: 'تبدیل HEIC/HEIF ناموفق بود. فایل ممکن است خراب یا رمزگذاری‌نشده باشد.',
        cause: error,
      );
    } finally {
      if (convertedPath != null && convertedPath.isNotEmpty) {
        try {
          final output = File(convertedPath);
          final originalPath = File(inputPath).absolute.path;
          if (output.absolute.path != originalPath && await output.exists()) {
            await output.delete();
          }
        } catch (_) {
          // A temporary conversion file must not make a successful conversion fail.
        }
      }
    }
  }
}
