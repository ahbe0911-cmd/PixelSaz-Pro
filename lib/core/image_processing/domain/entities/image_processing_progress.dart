/// Progress update emitted by the processing isolate.
class ImageProcessingProgress {
  const ImageProcessingProgress({
    required this.fraction,
    required this.stage,
    this.quality,
    this.width,
    this.height,
  });

  /// A normalized value in the inclusive range 0.0–1.0.
  final double fraction;
  final String stage;
  final int? quality;
  final int? width;
  final int? height;
}

typedef ImageProcessingProgressCallback = void Function(
  ImageProcessingProgress progress,
);
