import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/core/image_processing/data/datasources/fast_jpeg_dpi_patcher.dart';
import 'package:pixelsaz_pro/core/image_processing/data/datasources/jpeg_dpi_metadata.dart';

void main() {
  test('patches existing JFIF in place with 300 pixels per inch', () {
    final input = Uint8List.fromList(<int>[
      0xFF, 0xD8,
      0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
      0x01, 0x01, 0x00, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00,
      0xFF, 0xD9,
    ]);
    final updated = FastJpegDpiPatcher.apply300Dpi(input);
    expect(identical(updated, input), isTrue);
    expect(JpegDpiMetadata.readJfifDpi(updated), (300, 300));
    expect(updated.length, input.length);
  });

  test('inserts exactly 18 bytes of JFIF after JPEG SOI', () {
    final input = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
    final updated = FastJpegDpiPatcher.apply300Dpi(input);
    expect(updated.length, input.length + 18);
    expect(updated.sublist(0, 4), <int>[0xFF, 0xD8, 0xFF, 0xE0]);
    expect(updated.sublist(updated.length - 2), <int>[0xFF, 0xD9]);
    expect(JpegDpiMetadata.readJfifDpi(updated), (300, 300));
  });

  test('rejects malformed data rather than writing corrupt JPEG', () {
    expect(() => FastJpegDpiPatcher.apply300Dpi(Uint8List(5)), throwsFormatException);
  });
}
