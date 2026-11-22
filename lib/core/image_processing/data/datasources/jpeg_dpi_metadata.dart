import 'dart:typed_data';

/// Writes physical print-density metadata into a JPEG container.
///
/// Both the JFIF APP0 density fields and an EXIF APP1 IFD0 block are written.
/// Pixel dimensions are not changed by this class.
abstract final class JpegDpiMetadata {
  static const int _markerApp0 = 0xE0;
  static const int _markerApp1 = 0xE1;
  static const int _markerSos = 0xDA;
  static const int _markerEoi = 0xD9;
  static const int _markerSoi = 0xD8;
  static const int _markerTem = 0x01;

  static Uint8List apply300Dpi(Uint8List jpegBytes) {
    if (jpegBytes.length < 4 || jpegBytes[0] != 0xFF || jpegBytes[1] != _markerSoi) {
      throw const FormatException('The supplied bytes are not a valid JPEG stream.');
    }

    final preservedSegments = <Uint8List>[];
    var offset = 2;
    var reachedImageData = false;

    while (offset < jpegBytes.length) {
      if (jpegBytes[offset] != 0xFF) {
        preservedSegments.add(jpegBytes.sublist(offset));
        offset = jpegBytes.length;
        break;
      }

      final segmentStart = offset;
      while (offset < jpegBytes.length && jpegBytes[offset] == 0xFF) {
        offset++;
      }
      if (offset >= jpegBytes.length) {
        preservedSegments.add(jpegBytes.sublist(segmentStart));
        break;
      }

      final marker = jpegBytes[offset];
      offset++;

      if (marker == _markerSos || marker == _markerEoi) {
        preservedSegments.add(jpegBytes.sublist(segmentStart));
        reachedImageData = true;
        break;
      }

      if (marker == _markerSoi || marker == _markerTem || (marker >= 0xD0 && marker <= 0xD7)) {
        preservedSegments.add(jpegBytes.sublist(segmentStart, offset));
        continue;
      }

      if (offset + 2 > jpegBytes.length) {
        throw const FormatException('JPEG segment length is truncated.');
      }

      final segmentLength = (jpegBytes[offset] << 8) | jpegBytes[offset + 1];
      if (segmentLength < 2) {
        throw const FormatException('JPEG segment has an invalid length.');
      }

      final segmentEnd = offset + segmentLength;
      if (segmentEnd > jpegBytes.length) {
        throw const FormatException('JPEG segment extends beyond the input buffer.');
      }

      final payloadOffset = offset + 2;
      final isJfif = marker == _markerApp0 &&
          _hasAsciiIdentifier(jpegBytes, payloadOffset, const <int>[0x4A, 0x46, 0x49, 0x46, 0x00]);
      final isExif = marker == _markerApp1 &&
          _hasAsciiIdentifier(jpegBytes, payloadOffset, const <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00]);

      // Replace only JFIF and EXIF metadata. Other APP segments (for example
      // ICC profiles) and all coding tables are preserved byte-for-byte.
      if (!isJfif && !isExif) {
        preservedSegments.add(jpegBytes.sublist(segmentStart, segmentEnd));
      }
      offset = segmentEnd;
    }

    if (!reachedImageData && offset < jpegBytes.length) {
      preservedSegments.add(jpegBytes.sublist(offset));
    }

    final jfif = _buildJfifApp0(300);
    final exif = _buildExifApp1(300);
    final output = BytesBuilder(copy: false)
      ..add(jpegBytes.sublist(0, 2))
      ..add(jfif)
      ..add(exif);

    for (final segment in preservedSegments) {
      output.add(segment);
    }

    return output.takeBytes();
  }

  /// Returns the JFIF horizontal/vertical density when the unit is DPI.
  /// Returns null if no valid JFIF density segment is present.
  static (int, int)? readJfifDpi(Uint8List jpegBytes) {
    if (jpegBytes.length < 4 || jpegBytes[0] != 0xFF || jpegBytes[1] != _markerSoi) {
      return null;
    }

    var offset = 2;
    while (offset + 4 <= jpegBytes.length && jpegBytes[offset] == 0xFF) {
      while (offset < jpegBytes.length && jpegBytes[offset] == 0xFF) {
        offset++;
      }
      if (offset >= jpegBytes.length) return null;

      final marker = jpegBytes[offset++];
      if (marker == _markerSos || marker == _markerEoi) return null;
      if (marker == _markerSoi || marker == _markerTem || (marker >= 0xD0 && marker <= 0xD7)) {
        continue;
      }
      if (offset + 2 > jpegBytes.length) return null;

      final length = (jpegBytes[offset] << 8) | jpegBytes[offset + 1];
      if (length < 2 || offset + length > jpegBytes.length) return null;
      final payloadOffset = offset + 2;

      if (marker == _markerApp0 &&
          _hasAsciiIdentifier(jpegBytes, payloadOffset, const <int>[0x4A, 0x46, 0x49, 0x46, 0x00])) {
        if (length < 16 || payloadOffset + 12 > jpegBytes.length) return null;
        final units = jpegBytes[payloadOffset + 7];
        if (units != 1) return null;
        final x = (jpegBytes[payloadOffset + 8] << 8) | jpegBytes[payloadOffset + 9];
        final y = (jpegBytes[payloadOffset + 10] << 8) | jpegBytes[payloadOffset + 11];
        return (x, y);
      }

      offset += length;
    }
    return null;
  }

  static Uint8List _buildJfifApp0(int dpi) {
    return Uint8List.fromList(<int>[
      0xFF,
      _markerApp0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x02,
      0x01,
      (dpi >> 8) & 0xFF,
      dpi & 0xFF,
      (dpi >> 8) & 0xFF,
      dpi & 0xFF,
      0x00,
      0x00,
    ]);
  }

  static Uint8List _buildExifApp1(int dpi) {
    // Little-endian TIFF payload. IFD0 contains:
    // XResolution (RATIONAL), YResolution (RATIONAL), ResolutionUnit (SHORT=2/inch).
    final tiff = Uint8List(66);
    tiff[0] = 0x49; // I
    tiff[1] = 0x49; // I
    _writeUint16(tiff, 2, 42);
    _writeUint32(tiff, 4, 8);
    _writeUint16(tiff, 8, 3);

    _writeIfdEntry(tiff, 10, tag: 0x011A, type: 5, count: 1, value: 50);
    _writeIfdEntry(tiff, 22, tag: 0x011B, type: 5, count: 1, value: 58);
    _writeIfdEntry(tiff, 34, tag: 0x0128, type: 3, count: 1, value: 2);
    _writeUint32(tiff, 46, 0);

    _writeUint32(tiff, 50, dpi);
    _writeUint32(tiff, 54, 1);
    _writeUint32(tiff, 58, dpi);
    _writeUint32(tiff, 62, 1);

    final payload = Uint8List(6 + tiff.length)
      ..setRange(0, 6, const <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00])
      ..setRange(6, 6 + tiff.length, tiff);

    final segmentLength = payload.length + 2;
    final segment = Uint8List(4 + payload.length);
    segment[0] = 0xFF;
    segment[1] = _markerApp1;
    segment[2] = (segmentLength >> 8) & 0xFF;
    segment[3] = segmentLength & 0xFF;
    segment.setRange(4, segment.length, payload);
    return segment;
  }

  static void _writeIfdEntry(
    Uint8List bytes,
    int offset, {
    required int tag,
    required int type,
    required int count,
    required int value,
  }) {
    _writeUint16(bytes, offset, tag);
    _writeUint16(bytes, offset + 2, type);
    _writeUint32(bytes, offset + 4, count);
    if (type == 3 && count == 1) {
      _writeUint16(bytes, offset + 8, value);
      _writeUint16(bytes, offset + 10, 0);
    } else {
      _writeUint32(bytes, offset + 8, value);
    }
  }

  static void _writeUint16(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
  }

  static void _writeUint32(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
    bytes[offset + 2] = (value >> 16) & 0xFF;
    bytes[offset + 3] = (value >> 24) & 0xFF;
  }

  static bool _hasAsciiIdentifier(Uint8List bytes, int offset, List<int> identifier) {
    if (offset + identifier.length > bytes.length) return false;
    for (var index = 0; index < identifier.length; index++) {
      if (bytes[offset + index] != identifier[index]) return false;
    }
    return true;
  }
}
