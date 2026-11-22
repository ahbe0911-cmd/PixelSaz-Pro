import 'dart:io';
import 'package:image/image.dart' as img;

/// Converts the PixelSaz brand artwork into density-specific Android launcher
/// resources. Run after flutter create and flutter pub get.
void main() {
  final source = img.decodeJpg(
    File('assets/branding/pixelsaz_icon.jpg').readAsBytesSync(),
  );
  if (source == null) throw StateError('PixelSaz icon could not be decoded');
  const sizes = <String, int>{
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in sizes.entries) {
    final resized = img.copyResize(
      source,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final file = File(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(resized));
  }

  final foreground = img.Image(width: 432, height: 432, numChannels: 4);
  img.fill(foreground, color: img.ColorRgba8(0, 0, 0, 0));
  final centered = img.copyResize(
    source,
    width: 300,
    height: 300,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(foreground, centered, dstX: 66, dstY: 66);
  final foregroundFile = File(
    'android/app/src/main/res/drawable-nodpi/pixelsaz_foreground.png',
  );
  foregroundFile.parent.createSync(recursive: true);
  foregroundFile.writeAsBytesSync(img.encodePng(foreground));

  final background = img.Image(width: 432, height: 432, numChannels: 3);
  img.fill(background, color: img.ColorRgb8(15, 26, 69));
  final backgroundFile = File(
    'android/app/src/main/res/drawable-nodpi/pixelsaz_background.png',
  );
  backgroundFile.writeAsBytesSync(img.encodePng(background));

  final xmlFile = File(
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
  );
  xmlFile.parent.createSync(recursive: true);
  xmlFile.writeAsStringSync('''
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/pixelsaz_background"/>
    <foreground android:drawable="@drawable/pixelsaz_foreground"/>
</adaptive-icon>
''');
  stdout.writeln('PixelSaz launcher icons generated');
}
