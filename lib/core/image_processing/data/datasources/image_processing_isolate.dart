import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../constants/app_constants.dart';
import '../../../errors/image_processing_exception.dart';
import '../../domain/entities/image_processing_progress.dart';
import '../../domain/entities/image_processing_result.dart';
import 'jpeg_dpi_metadata.dart';

/// Runs decode/resize/JPEG encoding in a dedicated isolate and streams progress
/// messages back to the caller. No Flutter platform-channel plugin is invoked
/// from this isolate.
class ImageProcessingIsolate {
  Future<ImageProcessingResult> process({
    required Uint8List sourceBytes,
    required int originalSizeBytes,
    required String sourceFormat,
    required Map<String, Object?> options,
    required bool idPhoto,
    ImageProcessingProgressCallback? onProgress,
  }) async {
    final replyPort = ReceivePort();
    final errorPort = ReceivePort();
    final completer = Completer<ImageProcessingResult>();

    final replySubscription = replyPort.listen((dynamic message) {
      if (message == null) {
        if (!completer.isCompleted) {
          completer.completeError(
            const ImageProcessingException(
              code: 'isolate_exited_early',
              message: 'پردازش پس‌زمینه پیش از تولید خروجی متوقف شد.',
            ),
          );
        }
        return;
      }
      if (message is! Map) return;
      final type = message['type'];

      if (type == 'progress') {
        final fraction = (message['fraction'] as num?)?.toDouble() ?? 0;
        final stage = message['stage'] as String? ?? 'processing';
        try {
          onProgress?.call(
            ImageProcessingProgress(
              fraction: fraction.clamp(0.0, 1.0).toDouble(),
              stage: stage,
              quality: message['quality'] as int?,
              width: message['width'] as int?,
              height: message['height'] as int?,
            ),
          );
        } catch (_) {
          // A UI progress listener must not interrupt background processing.
        }
        return;
      }

      if (type == 'success' && !completer.isCompleted) {
        try {
          final resultMap = Map<String, Object?>.from(message['result'] as Map);
          final transferable = resultMap['bytes'] as TransferableTypedData;
          final outputBytes = transferable.materialize().asUint8List();
          completer.complete(
            ImageProcessingResult(
              bytes: outputBytes,
              originalSizeBytes: resultMap['originalSizeBytes'] as int,
              outputSizeBytes: outputBytes.length,
              width: resultMap['width'] as int,
              height: resultMap['height'] as int,
              quality: resultMap['quality'] as int,
              resizeCount: resultMap['resizeCount'] as int,
              targetReached: resultMap['targetReached'] as bool,
              sourceFormat: resultMap['sourceFormat'] as String,
              dpi300Applied: resultMap['dpi300Applied'] as bool,
              wasReencoded: resultMap['wasReencoded'] as bool,
            ),
          );
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
        return;
      }

      if (type == 'error' && !completer.isCompleted) {
        completer.completeError(
          ImageProcessingException(
            code: message['code'] as String? ?? 'processing_failed',
            message: message['message'] as String? ?? 'پردازش تصویر ناموفق بود.',
            cause: message['stackTrace'] as String?,
          ),
        );
      }
    });

    final errorSubscription = errorPort.listen((dynamic errorData) {
      if (completer.isCompleted) return;
      final description = errorData is List && errorData.isNotEmpty
          ? errorData.first.toString()
          : errorData.toString();
      completer.completeError(
        ImageProcessingException(
          code: 'isolate_uncaught_error',
          message: 'پردازش پس‌زمینه با خطای پیش‌بینی‌نشده متوقف شد.',
          cause: description,
        ),
      );
    });

    Isolate? worker;
    try {
      worker = await Isolate.spawn<Map<String, Object?>>(
        _imageProcessingWorker,
        <String, Object?>{
          'replyPort': replyPort.sendPort,
          'sourceBytes': TransferableTypedData.fromList(<Uint8List>[sourceBytes]),
          'originalSizeBytes': originalSizeBytes,
          'sourceFormat': sourceFormat,
          'options': options,
          'idPhoto': idPhoto,
        },
        onError: errorPort.sendPort,
        onExit: replyPort.sendPort,
        errorsAreFatal: true,
        debugName: idPhoto ? 'PixelSaz.IdPhotoProcessor' : 'PixelSaz.ImageProcessor',
      );
      return await completer.future;
    } finally {
      worker?.kill(priority: Isolate.immediate);
      await replySubscription.cancel();
      await errorSubscription.cancel();
      replyPort.close();
      errorPort.close();
    }
  }
}

void _imageProcessingWorker(Map<String, Object?> message) {
  final replyPort = message['replyPort'] as SendPort;
  try {
    final sourceTransfer = message['sourceBytes'] as TransferableTypedData;
    final sourceBytes = sourceTransfer.materialize().asUint8List();
    final originalSizeBytes = message['originalSizeBytes'] as int;
    final sourceFormat = message['sourceFormat'] as String;
    final options = Map<String, Object?>.from(message['options'] as Map);
    final idPhoto = message['idPhoto'] as bool;

    final result = _processImageBytes(
      sourceBytes: sourceBytes,
      originalSizeBytes: originalSizeBytes,
      sourceFormat: sourceFormat,
      options: options,
      idPhoto: idPhoto,
      sendProgress: (fraction, stage, quality, width, height) {
        replyPort.send(<String, Object?>{
          'type': 'progress',
          'fraction': fraction,
          'stage': stage,
          'quality': quality,
          'width': width,
          'height': height,
        });
      },
    );

    replyPort.send(<String, Object?>{
      'type': 'success',
      'result': <String, Object?>{
        'bytes': TransferableTypedData.fromList(<Uint8List>[result.bytes]),
        'originalSizeBytes': result.originalSizeBytes,
        'width': result.width,
        'height': result.height,
        'quality': result.quality,
        'resizeCount': result.resizeCount,
        'targetReached': result.targetReached,
        'sourceFormat': result.sourceFormat,
        'dpi300Applied': result.dpi300Applied,
        'wasReencoded': result.wasReencoded,
      },
    });
  } catch (error, stackTrace) {
    replyPort.send(<String, Object?>{
      'type': 'error',
      'code': 'image_decode_or_encode_failed',
      'message': error is FormatException
          ? 'فرمت تصویر معتبر نیست یا رمزگشایی آن پشتیبانی نمی‌شود.'
          : 'در پردازش تصویر خطایی رخ داد: $error',
      'stackTrace': stackTrace.toString(),
    });
  }
}

ImageProcessingResult _processImageBytes({
  required Uint8List sourceBytes,
  required int originalSizeBytes,
  required String sourceFormat,
  required Map<String, Object?> options,
  required bool idPhoto,
  required void Function(double, String, int?, int?, int?) sendProgress,
}) {
  if (sourceBytes.isEmpty) {
    throw const FormatException('Image input is empty.');
  }

  sendProgress(0.06, 'decoding', null, null, null);
  // Bound decoded pixel allocation to protect mobile devices from malformed
  // headers and extremely large images. The setting is isolate-local.
  img.Decoder.defaultMaxPixels = 40000000;
  final decoded = img.decodeImage(sourceBytes, frame: 0);
  if (decoded == null) {
    throw const FormatException('No decoder accepted the image bytes.');
  }

  var workingImage = img.bakeOrientation(decoded);
  final sourceWidth = workingImage.width;
  final sourceHeight = workingImage.height;

  if (idPhoto) {
    workingImage = _cropToAspectRatio(
      workingImage,
      AppConstants.idPhotoWidthPx / AppConstants.idPhotoHeightPx,
    );
    workingImage = img.copyResize(
      workingImage,
      width: AppConstants.idPhotoWidthPx,
      height: AppConstants.idPhotoHeightPx,
      interpolation: img.Interpolation.cubic,
    );
  }

  workingImage = _flattenOnWhite(workingImage);
  sendProgress(0.14, idPhoto ? 'preparing_id_photo' : 'preparing', null, workingImage.width, workingImage.height);

  final applyDpi = idPhoto;
  final minQuality = options['minQuality'] as int? ?? 65;
  final maxQuality = options['maxQuality'] as int? ?? 98;
  final targetBytes = options['targetBytes'] as int?;

  if (!idPhoto &&
      sourceFormat == 'jpeg' &&
      options['preserveOriginalIfAlreadyUnderTarget'] == true &&
      targetBytes != null &&
      sourceBytes.length <= targetBytes) {
    sendProgress(1.0, 'complete', 100, sourceWidth, sourceHeight);
    return ImageProcessingResult(
      bytes: sourceBytes,
      originalSizeBytes: originalSizeBytes,
      outputSizeBytes: sourceBytes.length,
      width: sourceWidth,
      height: sourceHeight,
      quality: 100,
      resizeCount: 0,
      targetReached: true,
      sourceFormat: sourceFormat,
      dpi300Applied: false,
      wasReencoded: false,
    );
  }

  if (idPhoto) {
    if (targetBytes == null) {
      final bytes = _encodeCandidate(workingImage, maxQuality, applyDpi);
      sendProgress(1.0, 'complete', maxQuality, AppConstants.idPhotoWidthPx, AppConstants.idPhotoHeightPx);
      return ImageProcessingResult(
        bytes: bytes,
        originalSizeBytes: originalSizeBytes,
        outputSizeBytes: bytes.length,
        width: AppConstants.idPhotoWidthPx,
        height: AppConstants.idPhotoHeightPx,
        quality: maxQuality,
        resizeCount: 0,
        targetReached: true,
        sourceFormat: sourceFormat,
        dpi300Applied: true,
        wasReencoded: true,
      );
    }

    var attempts = 0;
    final choice = _searchQuality(
      image: workingImage,
      targetBytes: targetBytes,
      minQuality: minQuality,
      maxQuality: maxQuality,
      applyDpi: true,
      onCandidate: (quality, size) {
        attempts++;
        sendProgress(
          (0.20 + attempts * 0.07).clamp(0.20, 0.90).toDouble(),
          'compressing_id_photo',
          quality,
          AppConstants.idPhotoWidthPx,
          AppConstants.idPhotoHeightPx,
        );
      },
    );

    sendProgress(
      1.0,
      'complete',
      choice.quality,
      AppConstants.idPhotoWidthPx,
      AppConstants.idPhotoHeightPx,
    );
    return ImageProcessingResult(
      bytes: choice.bytes,
      originalSizeBytes: originalSizeBytes,
      outputSizeBytes: choice.bytes.length,
      width: AppConstants.idPhotoWidthPx,
      height: AppConstants.idPhotoHeightPx,
      quality: choice.quality,
      resizeCount: 0,
      targetReached: choice.targetReached,
      sourceFormat: sourceFormat,
      dpi300Applied: true,
      wasReencoded: true,
    );
  }

  if (targetBytes == null) {
    throw ArgumentError('A target byte limit is required for standard compression.');
  }

  final triggerQuality = options['resizeTriggerQuality'] as int? ?? 70;
  final resizeScale = (options['resizeScale'] as num?)?.toDouble() ?? 0.90;
  final minShortEdge = options['minShortEdge'] as int? ?? 160;
  var resizeCount = 0;
  var triggerBytes = _encodeCandidate(workingImage, triggerQuality, false);
  var attempts = 1;

  // First test quality 70. Only if it is still over the target do we reduce
  // dimensions. Each resize keeps the original aspect ratio and uses bicubic.
  while (triggerBytes.length > targetBytes &&
      (workingImage.width < workingImage.height
          ? workingImage.width
          : workingImage.height) >
          minShortEdge) {
    final shortEdge = workingImage.width < workingImage.height
        ? workingImage.width
        : workingImage.height;
    final nextShortEdge = (shortEdge * resizeScale).round();
    final scale = nextShortEdge < minShortEdge ? minShortEdge / shortEdge : resizeScale;
    final nextWidth = (workingImage.width * scale).round().clamp(1, workingImage.width).toInt();
    final nextHeight = (workingImage.height * scale).round().clamp(1, workingImage.height).toInt();

    if (nextWidth == workingImage.width && nextHeight == workingImage.height) break;

    workingImage = img.copyResize(
      workingImage,
      width: nextWidth,
      height: nextHeight,
      interpolation: img.Interpolation.cubic,
    );
    resizeCount++;
    triggerBytes = _encodeCandidate(workingImage, triggerQuality, false);
    attempts++;
    sendProgress(
      (0.16 + resizeCount * 0.06).clamp(0.16, 0.58).toDouble(),
      'resizing',
      triggerQuality,
      workingImage.width,
      workingImage.height,
    );
  }

  final qualityUpperBound = triggerBytes.length <= targetBytes ? maxQuality : triggerQuality;
  final choice = _searchQuality(
    image: workingImage,
    targetBytes: targetBytes,
    minQuality: minQuality,
    maxQuality: qualityUpperBound,
    applyDpi: false,
    onCandidate: (quality, size) {
      attempts++;
      sendProgress(
        (0.20 + attempts * 0.055).clamp(0.20, 0.94).toDouble(),
        'compressing',
        quality,
        workingImage.width,
        workingImage.height,
      );
    },
  );

  sendProgress(1.0, 'complete', choice.quality, workingImage.width, workingImage.height);
  return ImageProcessingResult(
    bytes: choice.bytes,
    originalSizeBytes: originalSizeBytes,
    outputSizeBytes: choice.bytes.length,
    width: workingImage.width,
    height: workingImage.height,
    quality: choice.quality,
    resizeCount: resizeCount,
    targetReached: choice.targetReached,
    sourceFormat: sourceFormat,
    dpi300Applied: false,
    wasReencoded: true,
  );
}

img.Image _flattenOnWhite(img.Image source) {
  final background = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  img.fill(background, color: img.ColorRgb8(255, 255, 255));
  background.iccProfile = source.iccProfile;
  img.compositeImage(background, source);
  return background;
}

img.Image _cropToAspectRatio(img.Image source, double targetRatio) {
  final sourceRatio = source.width / source.height;
  if ((sourceRatio - targetRatio).abs() < 0.000001) return source;

  if (sourceRatio > targetRatio) {
    final cropWidth = (source.height * targetRatio).round().clamp(1, source.width).toInt();
    final left = (source.width - cropWidth) ~/ 2;
    return img.copyCrop(
      source,
      x: left,
      y: 0,
      width: cropWidth,
      height: source.height,
    );
  }

  final cropHeight = (source.width / targetRatio).round().clamp(1, source.height).toInt();
  final top = (source.height - cropHeight) ~/ 2;
  return img.copyCrop(
    source,
    x: 0,
    y: top,
    width: source.width,
    height: cropHeight,
  );
}

Uint8List _encodeCandidate(img.Image image, int quality, bool applyDpi) {
  final jpeg = img.encodeJpg(image, quality: quality);
  return applyDpi ? JpegDpiMetadata.apply300Dpi(jpeg) : jpeg;
}

_QualityChoice _searchQuality({
  required img.Image image,
  required int targetBytes,
  required int minQuality,
  required int maxQuality,
  required bool applyDpi,
  required void Function(int quality, int outputSize) onCandidate,
}) {
  var low = minQuality;
  var high = maxQuality;
  Uint8List? bestBytes;
  var bestQuality = minQuality;

  while (low <= high) {
    final quality = (low + high) ~/ 2;
    final candidate = _encodeCandidate(image, quality, applyDpi);
    onCandidate(quality, candidate.length);

    if (candidate.length <= targetBytes) {
      bestBytes = candidate;
      bestQuality = quality;
      low = quality + 1;
    } else {
      high = quality - 1;
    }
  }

  if (bestBytes != null) {
    // JPEG output size is normally monotonic with quality, but encoders can
    // vary slightly. Verify the next two levels so we do not leave easy
    // quality improvements unused.
    final verifyUntil = (bestQuality + 2).clamp(bestQuality, maxQuality).toInt();
    for (var quality = bestQuality + 1; quality <= verifyUntil; quality++) {
      final candidate = _encodeCandidate(image, quality, applyDpi);
      onCandidate(quality, candidate.length);
      if (candidate.length <= targetBytes) {
        bestBytes = candidate;
        bestQuality = quality;
      }
    }
    return _QualityChoice(
      bytes: bestBytes,
      quality: bestQuality,
      targetReached: true,
    );
  }

  final lowestQualityBytes = _encodeCandidate(image, minQuality, applyDpi);
  onCandidate(minQuality, lowestQualityBytes.length);
  return _QualityChoice(
    bytes: lowestQualityBytes,
    quality: minQuality,
    targetReached: lowestQualityBytes.length <= targetBytes,
  );
}

class _QualityChoice {
  const _QualityChoice({
    required this.bytes,
    required this.quality,
    required this.targetReached,
  });

  final Uint8List bytes;
  final int quality;
  final bool targetReached;
}
