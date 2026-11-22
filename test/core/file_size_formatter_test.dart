import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/core/utils/file_size_formatter.dart';

void main() {
  group('formatFileSize', () {
    test('formats bytes using Persian digits', () {
      expect(formatFileSize(512), '۵۱۲ بایت');
    });

    test('formats kibibytes using base 1024', () {
      expect(formatFileSize(495 * 1024), '۴۹۵ کیلوبایت');
    });

    test('formats mebibytes using base 1024', () {
      expect(formatFileSize(2 * 1024 * 1024), '۲.۰۰ مگابایت');
    });

    test('normalizes Persian and Arabic digits for numeric fields', () {
      expect(normalizeDigits('۴۹۵'), '495');
      expect(normalizeDigits('٢٠٠'), '200');
    });

    test('handles negative input safely', () {
      expect(formatFileSize(-1), '—');
    });
  });
}
