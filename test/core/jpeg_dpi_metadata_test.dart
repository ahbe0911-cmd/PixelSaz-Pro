import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/core/image_processing/data/datasources/jpeg_dpi_metadata.dart';

void main() {
  group('JpegDpiMetadata', () {
    test('writes JFIF density in pixels per inch', () {
      final minimalJpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
      final output = JpegDpiMetadata.apply300Dpi(minimalJpeg);

      expect(output[0], 0xFF);
      expect(output[1], 0xD8);
      expect(JpegDpiMetadata.readJfifDpi(output), (300, 300));
    });

    test('writes an EXIF APP1 block and keeps the JPEG end marker', () {
      final minimalJpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
      final output = JpegDpiMetadata.apply300Dpi(minimalJpeg);

      var app1Found = false;
      for (var index = 2; index + 1 < output.length; index++) {
        if (output[index] == 0xFF && output[index + 1] == 0xE1) {
          app1Found = true;
          expect(output[index + 4], 0x45); // E
          expect(output[index + 5], 0x78); // x
          expect(output[index + 6], 0x69); // i
          expect(output[index + 7], 0x66); // f
          break;
        }
      }

      expect(app1Found, isTrue);
      expect(output.sublist(output.length - 2), <int>[0xFF, 0xD9]);
    });

    test('writes EXIF X/Y resolution as 300/1 with inch units', () {
      final minimalJpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
      final output = JpegDpiMetadata.apply300Dpi(minimalJpeg);

      // The generated header is SOI (2 bytes), JFIF APP0 (18 bytes),
      // then EXIF APP1. The TIFF payload starts after the six-byte Exif ID.
      const tiffOffset = 30;
      const xResolutionOffset = tiffOffset + 50;
      const yResolutionOffset = tiffOffset + 58;
      const resolutionUnitEntryOffset = tiffOffset + 34;

      expect(output.sublist(xResolutionOffset, xResolutionOffset + 8), <int>[
        0x2C, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
      ]);
      expect(output.sublist(yResolutionOffset, yResolutionOffset + 8), <int>[
        0x2C, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
      ]);
      expect(output[resolutionUnitEntryOffset + 8], 2);
      expect(output[resolutionUnitEntryOffset + 9], 0);
    });

    test('replaces existing JFIF density rather than duplicating it', () {
      final minimalJpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
      final first = JpegDpiMetadata.apply300Dpi(minimalJpeg);
      final second = JpegDpiMetadata.apply300Dpi(first);

      expect(JpegDpiMetadata.readJfifDpi(second), (300, 300));
      var jfifCount = 0;
      for (var index = 2; index + 1 < second.length; index++) {
        if (second[index] == 0xFF && second[index + 1] == 0xE0) {
          jfifCount++;
        }
      }
      expect(jfifCount, 1);
    });
  });
}
