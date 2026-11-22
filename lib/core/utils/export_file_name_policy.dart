/// Cross-platform filename policy for generated JPEG files.
///
/// The user edits only the base name. This policy removes known image
/// extensions, replaces filesystem-reserved characters, and appends `.jpg`
/// exactly once at export time.
class ExportFileNamePolicy {
  ExportFileNamePolicy._();

  static final RegExp _knownImageExtension = RegExp(
    r'\.(?:jpe?g|png|webp|bmp|heic|heif)$',
    caseSensitive: false,
  );
  static final RegExp _invalidCharacters = RegExp(
    r'[\u0000-\u001F\u007F/\\:*?"<>|]',
  );
  static final RegExp _multipleSpaces = RegExp(r'\s+');
  static final RegExp _leadingDotsAndSpaces = RegExp(r'^[. ]+');
  static final RegExp _trailingDotsAndSpaces = RegExp(r'[. ]+$');

  static String removeKnownImageExtension(String value) {
    var result = value.trim();
    while (_knownImageExtension.hasMatch(result)) {
      result = result.replaceFirst(_knownImageExtension, '');
    }
    return result;
  }

  static String sanitizeBaseName(String value, {int maxRunes = 80}) {
    var result = removeKnownImageExtension(value);
    result = result.replaceAll(_invalidCharacters, '_');
    result = result.replaceAll(_multipleSpaces, ' ').trim();
    result = result.replaceAll(_leadingDotsAndSpaces, '');
    result = result.replaceAll(_trailingDotsAndSpaces, '');
    result = result.replaceAll(RegExp(r'_{2,}'), '_');

    if (result.isEmpty || result == '.' || result == '..') {
      throw const FormatException('نام فایل معتبر نیست. یک نام غیرخالی وارد کنید.');
    }

    final upper = result.toUpperCase();
    const reservedWindowsNames = <String>{
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    };
    if (reservedWindowsNames.contains(upper)) {
      result = '_$result';
    }

    final runes = result.runes.toList(growable: false);
    if (runes.length > maxRunes) {
      result = String.fromCharCodes(runes.take(maxRunes));
      result = result.replaceAll(_trailingDotsAndSpaces, '');
    }
    if (result.isEmpty) {
      throw const FormatException('نام فایل پس از پاک‌سازی خالی شده است.');
    }
    return result;
  }

  static String buildJpegFileName(String baseName) =>
      '${sanitizeBaseName(baseName)}.jpg';

  static List<String> buildUniqueJpegFileNames(Iterable<String> baseNames) {
    final names = baseNames.map(buildJpegFileName).toList(growable: false);
    final seen = <String>{};
    for (final name in names) {
      if (!seen.add(name.toLowerCase())) {
        throw const FormatException(
          'نام دو یا چند تصویر یکسان است. نام فایل‌ها را یکتا کنید.',
        );
      }
    }
    return names;
  }
}
