import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/image_processing/data/datasources/heic_conversion_data_source.dart';
import '../../../../core/image_processing/data/datasources/image_format_detector.dart';

/// Normalizes formats that native cropper libraries may not decode uniformly.
/// All formats, including JPEG, are converted into upright RGB pixels.
/// EXIF rotation is baked once and stripped before native cropping, because
/// Android crop plugins do not interpret every camera orientation consistently.
class IdPhotoImagePreparationService {
  IdPhotoImagePreparationService({HeicConversionDataSource? heicConverter})
      : _heicConverter = heicConverter ?? HeicConversionDataSource();

  final HeicConversionDataSource _heicConverter;
  static const Uuid _uuid = Uuid();

  Future<String> prepareForCrop(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('فایل تصویر پیدا نشد.');
    }

    final sourceLength = await source.length();
    if (sourceLength > 120 * 1024 * 1024) {
      throw const FileSystemException('حجم تصویر ورودی نباید بیشتر از ۱۲۰ مگابایت باشد.');
    }
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('فایل تصویر خالی است.');
    }

    final format = ImageFormatDetector.detect(bytes, sourcePath);
    if (!ImageFormatDetector.isSupported(format)) {
      throw FormatException('فرمت تصویر برای عکس پرسنلی پشتیبانی نمی‌شود: $format');
    }

    final Uint8List jpegBytes;
    if (ImageFormatDetector.isHeif(format)) {
      final converted = await _heicConverter.convertToJpeg(sourcePath);
      jpegBytes = await Isolate.run<Uint8List>(
        () => normalizeIdPhotoBytes(converted),
      );
    } else {
      jpegBytes = await Isolate.run<Uint8List>(() => normalizeIdPhotoBytes(bytes));
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final workingDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}pixelsaz_pro'
      '${Platform.pathSeparator}id_photo_work',
    );
    await workingDirectory.create(recursive: true);
    final output = File(
      '${workingDirectory.path}${Platform.pathSeparator}${_uuid.v4()}_normalized.jpg',
    );
    await output.writeAsBytes(jpegBytes, flush: true);
    return output.path;
  }
}

/// Pure, independently testable EXIF-orientation normalization.
Uint8List normalizeIdPhotoBytes(Uint8List bytes) {
  img.Decoder.defaultMaxPixels = 40000000;
  final decoded = img.decodeImage(bytes, frame: 0);
  if (decoded == null) {
    throw const FormatException('رمزگشایی تصویر انتخاب‌شده امکان‌پذیر نیست.');
  }

  // Phone portrait JPEGs commonly contain landscape pixel arrays and EXIF=6/8.
  // Bake EXIF so uCrop never incorrectly opens a portrait in landscape.
  final oriented = img.bakeOrientation(decoded);
  final background = img.Image(
    width: oriented.width,
    height: oriented.height,
    numChannels: 3,
  );
  img.fill(background, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(background, oriented);
  return Uint8List.fromList(img.encodeJpg(background, quality: 100));
}
