import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/core/utils/export_file_name_policy.dart';

void main() {
  group('ExportFileNamePolicy', () {
    test('removes an existing image extension before adding JPG', () {
      expect(
        ExportFileNamePolicy.buildJpegFileName('گزارش نهایی.HEIC'),
        'گزارش نهایی.jpg',
      );
      expect(
        ExportFileNamePolicy.buildJpegFileName('photo.jpg.jpg'),
        'photo.jpg',
      );
    });

    test('replaces filesystem-reserved characters', () {
      expect(
        ExportFileNamePolicy.buildJpegFileName('scan/2026:final'),
        'scan_2026_final.jpg',
      );
    });

    test('rejects empty names after normalization', () {
      expect(
        () => ExportFileNamePolicy.buildJpegFileName(' .jpg '),
        throwsFormatException,
      );
    });

    test('limits names by Unicode code points without splitting Persian text', () {
      final name = 'آ'.padRight(100, 'ب');
      final normalized = ExportFileNamePolicy.sanitizeBaseName(name);
      expect(normalized.runes.length, 80);
      expect(normalized, startsWith('آ'));
    });

    test('rejects duplicate names without regard to case', () {
      expect(
        () => ExportFileNamePolicy.buildUniqueJpegFileNames(
          <String>['Profile', 'profile.JPG'],
        ),
        throwsFormatException,
      );
    });

    test('preserves unique batch names with numbered suffixes', () {
      expect(
        ExportFileNamePolicy.buildUniqueJpegFileNames(
          <String>['مدارک_علی_1', 'مدارک_علی_2'],
        ),
        <String>['مدارک_علی_1.jpg', 'مدارک_علی_2.jpg'],
      );
    });
  });
}
