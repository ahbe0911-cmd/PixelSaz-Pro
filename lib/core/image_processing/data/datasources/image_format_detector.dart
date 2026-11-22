import 'dart:typed_data';

abstract final class ImageFormatDetector {
  static String detect(Uint8List bytes, String inputPath) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpeg';
    }

    const pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (_startsWith(bytes, pngSignature)) return 'png';

    if (bytes.length >= 12 &&
        _ascii(bytes, 0, 4) == 'RIFF' &&
        _ascii(bytes, 8, 4) == 'WEBP') {
      return 'webp';
    }

    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'bmp';
    }

    final extension = inputPath.toLowerCase().split('.').last;
    if (extension == 'heic' || extension == 'heif') return extension;

    if (bytes.length >= 12 && _ascii(bytes, 4, 4) == 'ftyp') {
      final brand = _ascii(bytes, 8, 4);
      if (brand == 'heic' || brand == 'heix' || brand == 'hevc' || brand == 'hevx') {
        return 'heic';
      }
      if (brand == 'mif1' || brand == 'msf1') return 'heif';
      if (brand == 'avif' || brand == 'avis') return 'avif';
    }

    return 'unknown';
  }

  static bool isHeif(String format) => format == 'heic' || format == 'heif';

  static bool isSupported(String format) =>
      format == 'jpeg' || format == 'png' || format == 'webp' || format == 'bmp' || isHeif(format);

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  static String _ascii(Uint8List bytes, int offset, int length) {
    if (offset + length > bytes.length) return '';
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }
}
