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

  /// Bounded native conversion queue. A failing file never aborts other files.
  Future<void> processBatch() async {
    if (!state.canStart) return;
    _cancelRequested = false;
    final items = List<BatchImageItem>.from(state.items);
    final targetBytes = state.targetBytes;
    final maxWorkers = Platform.numberOfProcessors >= 8 && items.length >= 8 ? 3 : 2;
    final runningProgress = <String, double>{};
    var next = 0;
    var finished = 0;

    state = state.copyWith(
      items: items.map((item) => item.copyWith(
        status: BatchImageStatus.selected,
        stage: 'منتظر پردازش',
        progress: 0,
        clearError: true,
        clearOutput: true,
      )).toList(growable: false),
      isProcessing: true,
      isCancelling: false,
      overallProgress: 0,
      completedCount: 0,
      clearSessionDirectory: true,
      clearError: true,
    );

    double overall() {
      var amount = finished.toDouble();
      for (final progress in runningProgress.values) {
        amount += progress;
      }
      return (amount / items.length).clamp(0.0, 1.0).toDouble();
    }

    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}${Platform.pathSeparator}'
        'pixelsaz_pro${Platform.pathSeparator}converted${Platform.pathSeparator}'
        '${const Uuid().v4()}',
      );
      await directory.create(recursive: true);
      state = state.copyWith(sessionDirectory: directory.path);

      Future<void> runOne(BatchImageItem item) async {
        runningProgress[item.id] = 0;
        final start = _findItem(item.id);
        if (start != null) {
          _replaceItem(item.id, start.copyWith(
            status: BatchImageStatus.processing,
            progress: 0,
            stage: 'پردازش نیتیو تصویر',
            clearError: true,
            clearOutput: true,
          ));
        }
        try {
          final result = await _processingService.compressToJpeg(
            inputPath: item.path,
            options: ImageCompressionOptions(targetBytes: targetBytes),
            onProgress: (ImageProcessingProgress progress) {
              final current = _findItem(item.id);
              if (current == null) return;
              runningProgress[item.id] = progress.fraction.clamp(0.0, 1.0).toDouble();
              _replaceItem(item.id, current.copyWith(
                progress: progress.fraction,
                stage: _stageLabel(progress.stage),
              ));
              state = state.copyWith(overallProgress: overall());
            },
          );
          final output = File(
            '${directory.path}${Platform.pathSeparator}${item.id}.jpg',
          );
          await output.writeAsBytes(result.bytes, flush: false);
          final current = _findItem(item.id);
          if (current != null) {
            _replaceItem(item.id, current.copyWith(
              status: BatchImageStatus.completed,
              progress: 1,
              stage: 'آماده خروجی',
              outputPath: output.path,
              outputSizeBytes: result.outputSizeBytes,
              outputWidth: result.width,
              outputHeight: result.height,
              quality: result.quality,
              resizeCount: result.resizeCount,
              targetReached: result.targetReached,
              sourceFormat: result.sourceFormat,
              clearError: true,
            ));
          }
        } catch (error) {
          final current = _findItem(item.id);
          if (current != null) {
            _replaceItem(item.id, current.copyWith(
              status: BatchImageStatus.failed,
              stage: 'پردازش ناموفق',
              progress: 0,
              errorMessage: _processingErrorMessage(error),
            ));
          }
        } finally {
          runningProgress.remove(item.id);
          finished++;
          state = state.copyWith(
            completedCount: finished,
            overallProgress: overall(),
          );
        }
      }

      Future<void> worker() async {
        while (!_cancelRequested) {
          final index = next++;
          if (index >= items.length) break;
          await runOne(items[index]);
        }
      }

      await Future.wait<void>(
        List<Future<void>>.generate(
          maxWorkers < items.length ? maxWorkers : items.length,
          (_) => worker(),
          growable: false,
        ),
      );
      final cancelled = _cancelRequested;
      state = state.copyWith(
        isProcessing: false,
        isCancelling: false,
        overallProgress: cancelled ? overall() : 1,
        errorMessage: cancelled
            ? 'پردازش تصاویر منتظر متوقف شد و خروجی‌های آماده محفوظ هستند.'
            : state.failedCount > 0
                ? '${state.failedCount} فایل خراب بود؛ سایر تصاویر پردازش شدند.'
                : null,
        clearError: !cancelled && state.failedCount == 0,
      );
    } catch (error) {
      state = state.copyWith(
        isProcessing: false,
        isCancelling: false,
        errorMessage: 'آماده‌سازی فضای خروجی ناموفق بود: $error',
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
      case 'finalizing':
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
