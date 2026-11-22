import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/features/id_photo/domain/entities/id_photo_specification.dart';

void main() {
  group('IdPhotoSpecification', () {
    test('uses exact requested output pixel dimensions', () {
      expect(IdPhotoSpecification.width, 354);
      expect(IdPhotoSpecification.height, 472);
      expect(IdPhotoSpecification.dpi, 300);
    });

    test('keeps the portrait aspect ratio at three to four', () {
      expect(IdPhotoSpecification.width / IdPhotoSpecification.height, closeTo(0.75, 0.000001));
      expect(IdPhotoSpecification.aspectRatio, closeTo(0.75, 0.000001));
    });
  });
}
