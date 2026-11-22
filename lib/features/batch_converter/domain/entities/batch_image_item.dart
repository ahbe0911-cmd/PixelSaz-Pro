/// Processing state of one image in a batch conversion queue.
enum BatchImageStatus {
  selected,
  processing,
  completed,
  failed,
}

/// Lightweight metadata for a picked image and its generated JPEG output.
///
/// The output bytes are deliberately not retained in memory. They are written
/// to the app's private support directory so a batch of up to 50 images does
/// not keep dozens of decoded/encoded buffers alive at once.
class BatchImageItem {
  const BatchImageItem({
    required this.id,
    required this.path,
    required this.originalName,
    required this.sourceSizeBytes,
    this.status = BatchImageStatus.selected,
    this.progress = 0,
    this.stage = 'منتظر پردازش',
    this.outputPath,
    this.outputSizeBytes,
    this.outputWidth,
    this.outputHeight,
    this.quality,
    this.resizeCount,
    this.targetReached,
    this.sourceFormat,
    this.errorMessage,
    this.exportBaseName,
  });

  final String id;
  final String path;
  final String originalName;
  final int sourceSizeBytes;
  final BatchImageStatus status;
  final double progress;
  final String stage;
  final String? outputPath;
  final int? outputSizeBytes;
  final int? outputWidth;
  final int? outputHeight;
  final int? quality;
  final int? resizeCount;
  final bool? targetReached;
  final String? sourceFormat;
  final String? errorMessage;
  final String? exportBaseName;

  String get suggestedExportBaseName {
    final normalizedPath = originalName.replaceAll('\\', '/');
    final fileName = normalizedPath.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  String get effectiveExportBaseName =>
      exportBaseName ?? suggestedExportBaseName;

  bool get isCompleted => status == BatchImageStatus.completed;
  bool get hasFailed => status == BatchImageStatus.failed;

  BatchImageItem copyWith({
    BatchImageStatus? status,
    double? progress,
    String? stage,
    String? outputPath,
    int? outputSizeBytes,
    int? outputWidth,
    int? outputHeight,
    int? quality,
    int? resizeCount,
    bool? targetReached,
    String? sourceFormat,
    String? errorMessage,
    String? exportBaseName,
    bool clearExportBaseName = false,
    bool clearError = false,
    bool clearOutput = false,
  }) {
    return BatchImageItem(
      id: id,
      path: path,
      originalName: originalName,
      sourceSizeBytes: sourceSizeBytes,
      status: status ?? this.status,
      progress: (progress ?? this.progress).clamp(0.0, 1.0).toDouble(),
      stage: stage ?? this.stage,
      outputPath: clearOutput ? null : outputPath ?? this.outputPath,
      outputSizeBytes: clearOutput ? null : outputSizeBytes ?? this.outputSizeBytes,
      outputWidth: clearOutput ? null : outputWidth ?? this.outputWidth,
      outputHeight: clearOutput ? null : outputHeight ?? this.outputHeight,
      quality: clearOutput ? null : quality ?? this.quality,
      resizeCount: clearOutput ? null : resizeCount ?? this.resizeCount,
      targetReached: clearOutput ? null : targetReached ?? this.targetReached,
      sourceFormat: clearOutput ? null : sourceFormat ?? this.sourceFormat,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      exportBaseName: clearExportBaseName
          ? null
          : exportBaseName ?? this.exportBaseName,
    );
  }
}
