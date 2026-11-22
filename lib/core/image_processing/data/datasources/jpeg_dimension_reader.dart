import 'dart:typed_data';

/// Reads JPEG SOF dimensions without allocating or decoding a bitmap.
abstract final class JpegDimensionReader {
  static (int width, int height)? read(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    var index = 2;
    while (index + 8 < bytes.length) {
      if (bytes[index] != 0xFF) return null;
      while (index < bytes.length && bytes[index] == 0xFF) index++;
      if (index >= bytes.length) return null;
      final marker = bytes[index++];
      if (marker == 0xDA || marker == 0xD9) break;
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) continue;
      if (index + 2 > bytes.length) break;
      final length = (bytes[index] << 8) | bytes[index + 1];
      if (length < 2 || index + length > bytes.length) break;
      if (<int>{0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
              .contains(marker) &&
          length >= 7) {
        final height = (bytes[index + 3] << 8) | bytes[index + 4];
        final width = (bytes[index + 5] << 8) | bytes[index + 6];
        if (height > 0 && width > 0) return (width, height);
      }
      index += length;
    }
    return null;
  }
}
