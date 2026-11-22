import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixelsaz_pro/core/image_processing/data/datasources/jpeg_dpi_metadata.dart';
import 'package:pixelsaz_pro/core/image_processing/data/datasources/native_image_codec.dart';
import 'package:pixelsaz_pro/core/image_processing/data/repositories/image_processing_service.dart';
import 'package:pixelsaz_pro/core/image_processing/domain/entities/image_compression_options.dart';

class FakeNativeCodec implements NativeImageCodec {
  FakeNativeCodec(this.response);
  final NativeEncodeResult response;
  final List<NativeEncodeRequest> requests = <NativeEncodeRequest>[];

  @override
  Future<NativeEncodeResult> encode(NativeEncodeRequest request) async {
    requests.add(request);
    return response;
  }
}

NativeEncodeResult fakeResult(int width, int height, {int passCount = 2}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(90, 140, 190));
  return NativeEncodeResult(
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 85)),
    width: width, height: height, quality: 85,
    resizeCount: 0, passCount: passCount,
  );
}

void main() {
  group('native ImageProcessingService adapter', () {
    late Directory temporaryDirectory;
    setUp(() async => temporaryDirectory = await Directory.systemTemp.createTemp('pixelsaz_fast_test_'));
    tearDown(() async {
      if (await temporaryDirectory.exists()) await temporaryDirectory.delete(recursive: true);
    });

    test('routes PNG to native encoder and respects target limit', () async {
      final image = img.Image(width: 640, height: 480);
      final input = File('${temporaryDirectory.path}/source.png');
      await input.writeAsBytes(img.encodePng(image));
      final fake = FakeNativeCodec(fakeResult(640, 480));
      final service = ImageProcessingService(nativeCodec: fake);
      final result = await service.compressToJpeg(
        inputPath: input.path,
        options: const ImageCompressionOptions(targetBytes: 495 * 1024),
      );
      expect(fake.requests, hasLength(1));
      expect(fake.requests.single.sourceFormat, 'png');
      expect(fake.requests.single.idPhoto, isFalse);
      expect(result.targetReached, isTrue);
      expect(result.width, 640);
      expect(result.height, 480);
      expect(result.wasReencoded, isTrue);
    });

    test('ID photo stays 354x472 and adds 300 DPI without Dart decode', () async {
      final image = img.Image(width: 800, height: 600);
      final input = File('${temporaryDirectory.path}/photo.png');
      await input.writeAsBytes(img.encodePng(image));
      final fake = FakeNativeCodec(fakeResult(354, 472, passCount: 1));
      final result = await ImageProcessingService(nativeCodec: fake).createIdPhotoJpeg(
        inputPath: input.path, options: const IdPhotoOptions(targetBytes: null),
      );
      expect(fake.requests.single.idPhoto, isTrue);
      expect(JpegDpiMetadata.readJfifDpi(result.bytes), (300, 300));
      expect(result.dpi300Applied, isTrue);
      expect(result.width, 354);
      expect(result.height, 472);
      expect(result.targetReached, isTrue);
    });

    test('rejects a native codec that violates maximum 3 passes', () async {
      final image = img.Image(width: 600, height: 400);
      final input = File('${temporaryDirectory.path}/bad.png');
      await input.writeAsBytes(img.encodePng(image));
      final fake = FakeNativeCodec(fakeResult(600, 400, passCount: 4));
      await expectLater(
        ImageProcessingService(nativeCodec: fake).compressToJpeg(inputPath: input.path),
        throwsA(isA<Exception>()),
      );
    });
  });
}
