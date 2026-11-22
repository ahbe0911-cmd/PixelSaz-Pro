import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixelsaz_pro/core/image_processing/data/datasources/jpeg_dimension_reader.dart';

/// Actual Android ExifInterface orientation is exercised by the native
/// integration pipeline on-device; this test guards the JPEG size reader
/// used to validate native outputs without a Dart image decode.
void main() {
  test('native JPEG dimension reader extracts upright portrait dimensions', () {
    final image = img.Image(width: 354, height: 472);
    final jpeg = img.encodeJpg(image, quality: 95);
    expect(JpegDimensionReader.read(jpeg), (354, 472));
  });
}
