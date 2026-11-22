import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixelsaz_pro/core/image_processing/data/datasources/jpeg_dpi_metadata.dart';
import 'package:pixelsaz_pro/core/image_processing/data/repositories/image_processing_service.dart';
import 'package:pixelsaz_pro/core/image_processing/domain/entities/image_compression_options.dart';

void main() {
  group('ImageProcessingService', () {
    late Directory temporaryDirectory;
    late ImageProcessingService service;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp('pixelsaz_test_');
      service = ImageProcessingService();
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('converts PNG to JPEG and respects the target size', () async {
      final sourceImage = img.Image(width: 640, height: 480, numChannels: 3);
      img.fill(sourceImage, color: img.ColorRgb8(80, 130, 190));
      final sourceBytes = img.encodePng(sourceImage);
      final sourceFile = File('${temporaryDirectory.path}/sample.png');
      await sourceFile.writeAsBytes(sourceBytes, flush: true);

      final result = await service.compressToJpeg(
        inputPath: sourceFile.path,
        options: const ImageCompressionOptions(targetBytes: 495 * 1024),
      );

      expect(result.bytes[0], 0xFF);
      expect(result.bytes[1], 0xD8);
      expect(result.outputSizeBytes, lessThanOrEqualTo(495 * 1024));
      expect(result.width, 640);
      expect(result.height, 480);
      expect(result.sourceFormat, 'png');
      expect(result.targetReached, isTrue);
    });

    test('creates a 354×472 JPEG with 300 DPI metadata', () async {
      final sourceImage = img.Image(width: 800, height: 600, numChannels: 3);
      for (final pixel in sourceImage) {
        pixel
          ..r = (pixel.x * 255 / sourceImage.width).round()
          ..g = (pixel.y * 255 / sourceImage.height).round()
          ..b = 110;
      }
      final sourceFile = File('${temporaryDirectory.path}/portrait.png');
      await sourceFile.writeAsBytes(img.encodePng(sourceImage), flush: true);

      final result = await service.createIdPhotoJpeg(
        inputPath: sourceFile.path,
        options: const IdPhotoOptions(targetBytes: null),
      );

      final decoded = img.decodeImage(result.bytes);
      expect(decoded, isNotNull);
      final decodedImage = decoded!;
      expect(decodedImage.width, 354);
      expect(decodedImage.height, 472);
      expect(JpegDpiMetadata.readJfifDpi(result.bytes), (300, 300));
      expect(result.dpi300Applied, isTrue);
      expect(result.targetReached, isTrue);
    });
  });
}
