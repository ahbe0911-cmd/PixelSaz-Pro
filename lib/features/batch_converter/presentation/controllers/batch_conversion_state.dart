import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/batch_image_item.dart';

class BatchConversionState {
  const BatchConversionState({
    this.items = const <BatchImageItem>[],
    this.targetBytes = AppConstants.defaultTargetSizeBytes,
    this.isPicking = false,
    this.isProcessing = false,
    this.isCancelling = false,
    this.overallProgress = 0,
    this.completedCount = 0,
    this.sessionDirectory,
    this.errorMessage,
  });

  final List<BatchImageItem> items;
  final int targetBytes;
  final bool isPicking;
  final bool isProcessing;
  final bool isCancelling;
  final double overallProgress;
  final int completedCount;
  final String? sessionDirectory;
  final String? errorMessage;

  int get totalCount => items.length;
  int get successfulCount => items.where((item) => item.isCompleted).length;
  int get failedCount => items.where((item) => item.hasFailed).length;
  int get pendingCount => items.where((item) => item.status == BatchImageStatus.selected).length;

  int get totalSavedBytes => items.fold<int>(
        0,
        (total, item) => total +
            (item.outputSizeBytes == null
                ? 0
                : (item.sourceSizeBytes - item.outputSizeBytes!).clamp(0, item.sourceSizeBytes).toInt()),
      );

  bool get canStart => items.isNotEmpty && !isPicking && !isProcessing;
  bool get hasResults => successfulCount > 0 || failedCount > 0;

  BatchConversionState copyWith({
    List<BatchImageItem>? items,
    int? targetBytes,
    bool? isPicking,
    bool? isProcessing,
    bool? isCancelling,
    double? overallProgress,
    int? completedCount,
    String? sessionDirectory,
    String? errorMessage,
    bool clearError = false,
    bool clearSessionDirectory = false,
  }) {
    return BatchConversionState(
      items: items ?? this.items,
      targetBytes: targetBytes ?? this.targetBytes,
      isPicking: isPicking ?? this.isPicking,
      isProcessing: isProcessing ?? this.isProcessing,
      isCancelling: isCancelling ?? this.isCancelling,
      overallProgress: (overallProgress ?? this.overallProgress)
          .clamp(0.0, 1.0)
          .toDouble(),
      completedCount: completedCount ?? this.completedCount,
      sessionDirectory: clearSessionDirectory
          ? null
          : sessionDirectory ?? this.sessionDirectory,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
