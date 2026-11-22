import 'dart:typed_data';

/// Immutable output returned by the image-processing engine.
class ImageProcessingResult {
  const ImageProcessingResult({
    required this.bytes,
    required this.originalSizeBytes,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
    required this.quality,
    required this.resizeCount,
    required this.targetReached,
    required this.sourceFormat,
    required this.dpi300Applied,
    required this.wasReencoded,
  });

  final Uint8List bytes;
  final int originalSizeBytes;
  final int outputSizeBytes;
  final int width;
  final int height;
  final int quality;
  final int resizeCount;
  final bool targetReached;
  final String sourceFormat;
  final bool dpi300Applied;
  final bool wasReencoded;

  int get savedBytes => originalSizeBytes - outputSizeBytes;

  double get reductionPercent {
    if (originalSizeBytes <= 0) return 0;
    return (savedBytes / originalSizeBytes) * 100;
  }

  bool get outputIsSmaller => outputSizeBytes < originalSizeBytes;
}
