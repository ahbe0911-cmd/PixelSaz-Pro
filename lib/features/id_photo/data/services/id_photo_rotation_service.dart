import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Applies small-angle rotation off the UI isolate and fills exposed corners
/// with white. Angles are in degrees and are intentionally limited by UI.
class IdPhotoRotationService {
  static const Uuid _uuid = Uuid();

  Future<String> rotateFile({
    required String sourcePath,
    required double angleDegrees,
  }) async {
    if (angleDegrees.abs() < 0.01) return sourcePath;

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('فایل تصویر برای چرخش پیدا نشد.');
    }

    final sourceLength = await source.length();
    if (sourceLength > 120 * 1024 * 1024) {
      throw const FileSystemException('حجم تصویر برای چرخش بیش از حد مجاز است.');
    }
    final bytes = await source.readAsBytes();
    final rotatedBytes = await Isolate.run<Uint8List>(
      () => _rotateImageBytes(<String, Object?>{
        'bytes': bytes,
        'angle': angleDegrees,
      }),
    );

    final temporaryDirectory = await getTemporaryDirectory();
    final workingDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}pixelsaz_pro'
      '${Platform.pathSeparator}id_photo_work',
    );
    await workingDirectory.create(recursive: true);
    final output = File(
      '${workingDirectory.path}${Platform.pathSeparator}${_uuid.v4()}_rotated.jpg',
    );
    await output.writeAsBytes(rotatedBytes, flush: true);
    return output.path;
  }
}

Uint8List _rotateImageBytes(Map<String, Object?> arguments) {
  final bytes = arguments['bytes'] as Uint8List;
  final angle = (arguments['angle'] as num).toDouble();
  img.Decoder.defaultMaxPixels = 40000000;

  final decoded = img.decodeImage(bytes, frame: 0);
  if (decoded == null) {
    throw const FormatException('تصویر برای چرخش قابل رمزگشایی نیست.');
  }

  final oriented = img.bakeOrientation(decoded);
  final rotated = img.copyRotate(
    oriented,
    angle: angle,
    interpolation: img.Interpolation.cubic,
  );
  final background = img.Image(
    width: rotated.width,
    height: rotated.height,
    numChannels: 3,
  );
  img.fill(background, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(background, rotated);
  return Uint8List.fromList(img.encodeJpg(background, quality: 98));
}
