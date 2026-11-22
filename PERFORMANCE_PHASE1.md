# PixelSaz Pro · Phase 1 / Native conversion

This phase changes the **compression engine**, not the application UI. Android
performs bitmap decode (with EXIF orientation), white-background compositing,
JPEG quality selection and optional downsampling on its own background executor,
using `BitmapFactory` and `Bitmap.compress`. The Dart engine no longer decodes
image pixels or runs repeated JPEG encodes. On iOS, the existing
`flutter_image_compress` native platform implementation is used as a bounded
fallback with strict dimensions validation for ID photos. HEIF compatibility
still depends on OS/device codec support, with the existing native
`heif_converter` as an optional fallback.

- Native target-search policy: **at most 3 encode attempts**. The 92–99% band
  is a preferred quality-size window, **not a guarantee**. A result whose size
  is still greater than the target reports `targetReached = false`. Users
  should not be told that a file met its target if it did not.
- Android decode is sampled to limit raw bitmaps to about 6 megapixels for
  batch items and 2.5 megapixels for 3×4 ID photos, avoiding dozens of
  50-megapixel bitmap allocations. Higher quality can be traded for higher
  memory consumption if this is changed later.
- The batch controller uses **2 workers**, or **3 workers on 8-core devices**
  for eight or more files, with independent per-file exceptions. Cancellation
  stops dispatching pending items and retains finished outputs.
- JFIF 300-DPI metadata is patched directly in JPEG bytes; it does not
  decode or encode pixels in Dart. ID photo pixel dimensions stay 354×472.
- JPEG input already below the target can be passed through unchanged.
- The real performance gain and millisecond latency **must be benchmarked on
  target devices**. No fixed 10–30× improvement or <400ms SLA is claimed.

## Environment and build

The project uses locally packaged `Vazirmatn` Regular, Medium, Bold, and
ExtraBold. Run `python3 tool/fetch_local_fonts.py` once before local Flutter
build. In GitHub Actions this is an automated, pinned, SHA-verified download
before `flutter pub get`. The TTF assets are then part of the APK and require
no Internet access from the installed app. The project remains subject to the
font SIL OFL 1.1 license.

Build diagnostics:

```sh
python3 tool/fetch_local_fonts.py
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

## Android device acceptance tests

1. Convert ten PNG/JPEG/WebP/HEIC photos with the 495-KiB target. Record both
   elapsed time and output dimensions. One corrupt item must not abort others.
2. Test cancellation halfway through a batch, then start another batch. There
   must not be a stuck `isProcessing` state.
3. Use a portrait JPEG with EXIF orientation 6/8 and an HEIC portrait. Confirm
   they remain upright in the ID photo crop screen and output JPEG.
4. Confirm JFIF `Units=1`, X/Y density `300` and pixel dimensions 354×472.
5. Compare Android 10–16 performance and monitor memory with Android Profiler.

Release/market signing and the compact UI redesign belong to later validation
and phase 2/3 respectively.
