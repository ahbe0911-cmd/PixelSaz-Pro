import '../../../constants/app_constants.dart';

/// Compression policy for a regular image-to-JPEG conversion.
///
/// [targetBytes] is a hard upper bound when the image can reasonably be
/// encoded below it. If the source is unusually complex or the minimum
/// dimensions are reached, [targetReached] on the result reports that fact.
class ImageCompressionOptions {
  const ImageCompressionOptions({
    this.targetBytes = AppConstants.defaultTargetSizeBytes,
    this.minQuality = 65,
    this.maxQuality = 98,
    this.resizeTriggerQuality = 70,
    this.resizeScale = 0.90,
    this.minShortEdge = 160,
    this.preserveOriginalIfAlreadyUnderTarget = true,
  });

  final int targetBytes;
  final int minQuality;
  final int maxQuality;
  final int resizeTriggerQuality;
  final double resizeScale;
  final int minShortEdge;
  final bool preserveOriginalIfAlreadyUnderTarget;

  void validate() {
    if (targetBytes <= 0) {
      throw ArgumentError.value(targetBytes, 'targetBytes', 'Must be greater than zero.');
    }
    if (minQuality < 1 || maxQuality > 100 || minQuality > maxQuality) {
      throw ArgumentError('JPEG quality range must be between 1 and 100.');
    }
    if (resizeTriggerQuality < minQuality || resizeTriggerQuality > maxQuality) {
      throw ArgumentError.value(
        resizeTriggerQuality,
        'resizeTriggerQuality',
        'Must be inside the configured JPEG quality range.',
      );
    }
    if (resizeScale <= 0 || resizeScale >= 1) {
      throw ArgumentError.value(resizeScale, 'resizeScale', 'Must be greater than 0 and less than 1.');
    }
    if (minShortEdge < 32) {
      throw ArgumentError.value(minShortEdge, 'minShortEdge', 'Must be at least 32 pixels.');
    }
  }

  Map<String, Object?> toWorkerMap() => <String, Object?>{
        'targetBytes': targetBytes,
        'minQuality': minQuality,
        'maxQuality': maxQuality,
        'resizeTriggerQuality': resizeTriggerQuality,
        'resizeScale': resizeScale,
        'minShortEdge': minShortEdge,
        'preserveOriginalIfAlreadyUnderTarget': preserveOriginalIfAlreadyUnderTarget,
      };
}

/// Output policy for the 3×4 ID-photo pipeline.
///
/// A null [targetBytes] means print-quality mode: encode at [maxQuality]
/// without reducing the fixed 354×472 output dimensions.
class IdPhotoOptions {
  const IdPhotoOptions({
    this.targetBytes = AppConstants.defaultTargetSizeBytes,
    this.minQuality = 65,
    this.maxQuality = 98,
  });

  final int? targetBytes;
  final int minQuality;
  final int maxQuality;

  void validate() {
    if (targetBytes != null && targetBytes! <= 0) {
      throw ArgumentError.value(targetBytes, 'targetBytes', 'Must be greater than zero or null.');
    }
    if (minQuality < 1 || maxQuality > 100 || minQuality > maxQuality) {
      throw ArgumentError('JPEG quality range must be between 1 and 100.');
    }
  }

  Map<String, Object?> toWorkerMap() => <String, Object?>{
        'targetBytes': targetBytes,
        'minQuality': minQuality,
        'maxQuality': maxQuality,
      };
}
