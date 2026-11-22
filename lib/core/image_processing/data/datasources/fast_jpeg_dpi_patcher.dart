import 'dart:typed_data';

/// Updates a JPEG's JFIF print density without decoding any image pixels.
///
/// The native encoder returns an owned, mutable [Uint8List]. When a JFIF APP0
/// header exists directly after SOI, the same buffer is updated in place.
/// Otherwise a single 18-byte APP0 segment is inserted before existing data.
/// Native output is encoded with EXIF retention disabled to avoid conflicting
/// XResolution/YResolution metadata from the source photograph.
abstract final class FastJpegDpiPatcher {
  static const List<int> _jfif300 = <int>[
    0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
    0x01, 0x01, 0x01, 0x01, 0x2C, 0x01, 0x2C, 0x00, 0x00,
  ];

  static Uint8List apply300Dpi(Uint8List jpeg) {
    if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
      throw const FormatException('Input is not a JPEG stream.');
    }

    // APP0 is immediately after SOI and has at least 16 bytes (incl. length).
    if (jpeg.length >= 20 &&
        jpeg[2] == 0xFF &&
        jpeg[3] == 0xE0 &&
        ((jpeg[4] << 8) | jpeg[5]) >= 16 &&
        (4 + ((jpeg[4] << 8) | jpeg[5])) <= jpeg.length &&
        jpeg[6] == 0x4A && jpeg[7] == 0x46 &&
        jpeg[8] == 0x49 && jpeg[9] == 0x46 && jpeg[10] == 0x00) {
      // Segment-local offsets: Units=11, Xdensity=12..13, Ydensity=14..15.
      jpeg[13] = 0x01;
      jpeg[14] = 0x01;
      jpeg[15] = 0x2C;
      jpeg[16] = 0x01;
      jpeg[17] = 0x2C;
      return jpeg;
    }

    final output = Uint8List(jpeg.length + _jfif300.length);
    output.setRange(0, 2, jpeg);
    output.setRange(2, 2 + _jfif300.length, _jfif300);
    output.setRange(2 + _jfif300.length, output.length, jpeg, 2);
    return output;
  }
}
