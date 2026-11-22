# PixelSaz Pro

Flutter image compressor, batch converter and ID photo studio.

## Android build

GitHub Actions creates the Android host project from the source overlay and builds `app-release.apk`.
Navigate to **Actions → Build PixelSaz Pro Android APK** and download the `PixelSaz-Pro-APK` artifact from the successful run.

Local setup: `flutter create --project-name pixelsaz_pro --org com.pixelsaz --platforms=android .`, then `flutter pub get`, `flutter test`, and `flutter build apk --release`.

Note: Release APK is signed using the default Android debug signing key unless production signing is configured; do not publish it to stores until signed with a production key.
