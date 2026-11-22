import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/image_processing/data/repositories/image_processing_service.dart';
import '../../../../core/image_processing/domain/entities/image_compression_options.dart';
import '../../../../core/image_processing/domain/entities/image_processing_progress.dart';
import '../../data/datasources/gallery_image_picker.dart';
import '../providers/batch_conversion_dependencies.dart';
import '../../domain/entities/batch_image_item.dart';
import 'batch_conversion_state.dart';

class BatchConversionController extends Notifier<BatchConversionState> {
  late ImageProcessingService _processingService;
  late GalleryImagePicker _galleryPicker;
  bool _cancelRequested = false;

  @override
  BatchConversionState build() {
    _processingService = ref.read(imageProcessingServiceProvider);
    _galleryPicker = ref.read(galleryImagePickerProvider);
    unawaited(_recoverLostPickerData());
    return const BatchConversionState();
  }

  Future<void> pickImages() async {
    if (state.isPicking || state.isProcessing) return;

    final remaining = AppConstants.maximumBatchSelection - state.items.length;
    if (remaining <= 0) {
      state = state.copyWith(
        errorMessage: 'حداکثر ${AppConstants.maximumBatchSelection} تصویر قابل انتخاب است.',
      );
      return;
    }

    state = state.copyWith(isPicking: true, clearError: true);
    try {
      final picked = await _galleryPicker.pickImages(limit: remaining);
      if (picked.isEmpty) {
        state = state.copyWith(isPicking: false);
        return;
      }

      _appendPickedImages(picked);
      state = state.copyWith(isPicking: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isPicking: false,
        errorMessage: _pickerErrorMessage(error),
      );
    }
  }


  Future<void> _recoverLostPickerData() async {
    try {
      final recovered = await _galleryPicker.retrieveLostImages();
      if (recovered.isNotEmpty) {
        _appendPickedImages(recovered);
      }
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'بازیابی تصاویر انتخاب‌شده کامل نشد: $error',
      );
    }
  }

  void _appendPickedImages(List<PickedImageFile> picked) {
    final existingPaths = state.items.map((item) => item.path).toSet();
    final nextItems = List<BatchImageItem>.from(state.items);
    for (final file in picked) {
      if (existingPaths.contains(file.path)) continue;
      if (nextItems.length >= AppConstants.maximumBatchSelection) break;
      nextItems.add(
        BatchImageItem(
          id: const Uuid().v4(),
          path: file.path,
          originalName: file.name,
          sourceSizeBytes: file.sizeBytes,
        ),
      );
      existingPaths.add(file.path);
    }
    state = state.copyWith(items: nextItems);
  }

  void setExportBaseName(String id, String value) {
    final current = _findItem(id);
    if (current == null || !current.isCompleted) return;
    _replaceItem(id, current.copyWith(exportBaseName: value));
  }

  void applyBatchRename(String prefix) {
    final successfulItems = state.items
        .where((item) => item.status == BatchImageStatus.completed)
        .toList(growable: false);
    if (successfulItems.isEmpty) return;

    final updatedItems = List<BatchImageItem>.from(state.items);
    for (var index = 0; index < successfulItems.length; index++) {
      final item = successfulItems[index];
      final itemIndex = updatedItems.indexWhere((candidate) => candidate.id == item.id);
      if (itemIndex >= 0) {
        updatedItems[itemIndex] = item.copyWith(
          exportBaseName: '${prefix}_${index + 1}',
        );
      }
    }
    state = state.copyWith(items: updatedItems, clearError: true);
  }

  void removeImage(String id) {
    if (state.isProcessing || state.isPicking) return;
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(growable: false),
      clearError: true,
    );
  }

  void clearSelection() {
    if (state.isProcessing || state.isPicking) return;
    state = BatchConversionState(targetBytes: state.targetBytes);
  }

  void setTargetBytes(int bytes) {
    if (state.isProcessing || bytes <= 0) return;
    state = state.copyWith(targetBytes: bytes, clearError: true);
  }

  void cancelBatch() {
    if (!state.isProcessing || state.isCancelling) return;
    _cancelRequested = true;
    state = state.copyWith(isCancelling: true);
  }

  Future<void> processBatch() async {
    if (!state.canStart) return;

    _cancelRequested = false;
    final batchItems = List<BatchImageItem>.from(state.items);
    final batchId = const Uuid().v4();

    state = state.copyWith(
      isProcessing: true,
      isCancelling: false,
      overallProgress: 0,
      completedCount: 0,
      clearError: true,
      clearSessionDirectory: true,
    );

    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final outputDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}'
        'pixelsaz_pro${Platform.pathSeparator}converted${Platform.pathSeparator}$batchId',
      );
      await outputDirectory.create(recursive: true);
      state = state.copyWith(sessionDirectory: outputDirectory.path);

      for (var index = 0; index < batchItems.length; index++) {
        if (_cancelRequested) break;

        final queuedItem = batchItems[index];
        _replaceItem(
          queuedItem.id,
          queuedItem.copyWith(
            status: BatchImageStatus.processing,
            progress: 0,
            stage: 'آماده‌سازی تصویر',
            clearError: true,
            clearOutput: true,
          ),
        );

        try {
          final result = await _processingService.compressToJpeg(
            inputPath: queuedItem.path,
            options: ImageCompressionOptions(targetBytes: state.targetBytes),
            onProgress: (ImageProcessingProgress progress) {
              final current = _findItem(queuedItem.id);
              if (current == null) return;
              _replaceItem(
                queuedItem.id,
                current.copyWith(
                  progress: progress.fraction,
                  stage: _stageLabel(progress.stage),
                ),
              );
              state = state.copyWith(
                overallProgress: (index + progress.fraction) / batchItems.length,
              );
            },
          );

          final outputFile = File(
            '${outputDirectory.path}${Platform.pathSeparator}${queuedItem.id}.jpg',
          );
          await outputFile.writeAsBytes(result.bytes, flush: true);

          final current = _findItem(queuedItem.id);
          if (current != null) {
            _replaceItem(
              queuedItem.id,
              current.copyWith(
                status: BatchImageStatus.completed,
                progress: 1,
                stage: 'آماده خروجی',
                outputPath: outputFile.path,
                outputSizeBytes: result.outputSizeBytes,
                outputWidth: result.width,
                outputHeight: result.height,
                quality: result.quality,
                resizeCount: result.resizeCount,
                targetReached: result.targetReached,
                sourceFormat: result.sourceFormat,
                clearError: true,
              ),
            );
          }
        } catch (error) {
          final current = _findItem(queuedItem.id);
          if (current != null) {
            _replaceItem(
              queuedItem.id,
              current.copyWith(
                status: BatchImageStatus.failed,
                progress: 0,
                stage: 'پردازش ناموفق',
                errorMessage: _processingErrorMessage(error),
              ),
            );
          }
        }

        state = state.copyWith(
          completedCount: index + 1,
          overallProgress: (index + 1) / batchItems.length,
        );
      }

      final stoppedEarly = _cancelRequested;
      state = state.copyWith(
        isProcessing: false,
        isCancelling: false,
        overallProgress: stoppedEarly
            ? state.overallProgress
            : 1,
        errorMessage: stoppedEarly
            ? 'صف پردازش پس از پایان تصویر جاری متوقف شد.'
            : state.failedCount > 0
                ? '${state.failedCount} تصویر با خطا مواجه شد؛ سایر تصاویر پردازش شدند.'
                : null,
        clearError: !stoppedEarly && state.failedCount == 0,
      );
    } catch (error) {
      state = state.copyWith(
        isProcessing: false,
        isCancelling: false,
        errorMessage: 'ایجاد فضای خروجی یا شروع پردازش ناموفق بود: $error',
      );
    } finally {
      _cancelRequested = false;
    }
  }

  void _replaceItem(String id, BatchImageItem updated) {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final nextItems = List<BatchImageItem>.from(state.items);
    nextItems[index] = updated;
    state = state.copyWith(items: nextItems);
  }

  BatchImageItem? _findItem(String id) {
    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'reading_source':
        return 'خواندن فایل';
      case 'converting_heic':
        return 'تبدیل HEIC';
      case 'decoding':
        return 'رمزگشایی تصویر';
      case 'preparing':
        return 'آماده‌سازی تصویر';
      case 'compressing':
      case 'searching_quality':
        return 'بهینه‌سازی کیفیت و حجم';
      case 'resizing':
        return 'تنظیم ابعاد تصویر';
      case 'complete':
        return 'تکمیل شد';
      default:
        return 'در حال پردازش';
    }
  }

  String _pickerErrorMessage(Object error) {
    final description = error.toString();
    if (description.contains('photo_access_denied') ||
        description.contains('permission')) {
      return 'دسترسی انتخاب تصویر انجام نشد. دوباره تلاش کنید.';
    }
    return 'انتخاب تصاویر ناموفق بود: $description';
  }

  String _processingErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
