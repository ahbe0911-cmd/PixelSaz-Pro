import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../errors/image_processing_exception.dart';
import 'jpeg_dimension_reader.dart';

class NativeEncodeRequest {
  const NativeEncodeRequest({
    required this.inputPath,
    required this.sourceFormat,
    required this.minQuality,
    required this.maxQuality,
    required this.resizeTriggerQuality,
    required this.minShortEdge,
    required this.idPhoto,
    this.targetBytes,
  });

  final String inputPath;
  final String sourceFormat;
  final int minQuality;
  final int maxQuality;
  final int resizeTriggerQuality;
  final int minShortEdge;
  final bool idPhoto;
  final int? targetBytes;
}

class NativeEncodeResult {
  const NativeEncodeResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
    required this.resizeCount,
    required this.passCount,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;
  final int resizeCount;
  final int passCount;
}

abstract class NativeImageCodec {
  Future<NativeEncodeResult> encode(NativeEncodeRequest request);
}

/// Root-isolate-only platform service. Android decodes once and runs up to three
/// JPEG encodes in a worker thread. Apple uses flutter_image_compress's native
/// ImageIO encoder; neither path invokes package:image for conversion.
class PlatformNativeImageCodec implements NativeImageCodec {
  const PlatformNativeImageCodec();

  static const MethodChannel _channel = MethodChannel('pixelsaz_pro/native_image');

  @override
  Future<NativeEncodeResult> encode(NativeEncodeRequest request) async {
    if (Platform.isAndroid) {
      return _encodeAndroid(request);
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return _encodeApple(request);
    }
    throw const ImageProcessingException(
      code: 'unsupported_platform',
      message: 'موتور فشرده‌سازی نیتیو برای این سیستم‌عامل در دسترس نیست.',
    );
  }

  Future<NativeEncodeResult> _encodeAndroid(NativeEncodeRequest request) async {
    final data = await _channel.invokeMapMethod<String, dynamic>('encode', <String, dynamic>{
      'inputPath': request.inputPath,
      'sourceFormat': request.sourceFormat,
      'targetBytes': request.targetBytes,
      'minQuality': request.minQuality,
      'maxQuality': request.maxQuality,
      'resizeTriggerQuality': request.resizeTriggerQuality,
      'minShortEdge': request.minShortEdge,
      'idPhoto': request.idPhoto,
    });
    final path = data?['path'] as String?;
    if (path == null) {
      throw const ImageProcessingException(
        code: 'no_native_output',
        message: 'موتور نیتیو فایل خروجی تولید نکرد.',
      );
    }
    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      return NativeEncodeResult(
        bytes: bytes,
        width: data?['width'] as int? ?? 0,
        height: data?['height'] as int? ?? 0,
        quality: data?['quality'] as int? ?? request.maxQuality,
        resizeCount: data?['resizeCount'] as int? ?? 0,
        passCount: data?['passCount'] as int? ?? 1,
      );
    } finally {
      try { if (await file.exists()) await file.delete(); } catch (_) { }
    }
  }

  /// Apple fallback. The native plugin performs native encode/resize, but the
  /// 3-pass policy is heuristic: a strict target range cannot be guaranteed.
  Future<NativeEncodeResult> _encodeApple(NativeEncodeRequest request) async {
    final targetBytes = request.targetBytes;
    final inputLength = await File(request.inputPath).length();
    final scaleFactor = targetBytes == null ? 1.0 :
        math.min(1.0, math.sqrt(math.max(0.02, targetBytes / math.max(1, inputLength))));
    final guess = targetBytes == null
        ? request.maxQuality
        : (scaleFactor < 0.4 ? 78 : scaleFactor < 0.7 ? 86 : 93)
            .clamp(request.minQuality, request.maxQuality).toInt();
    final candidates = <(Uint8List, int, int, int)>[];
    var widthLimit = request.idPhoto ? 354 : 10000;
    var heightLimit = request.idPhoto ? 472 : 10000;

    Future<void> attempt(int quality) async {
      final output = await FlutterImageCompress.compressWithFile(
        request.inputPath,
        minWidth: widthLimit,
        minHeight: heightLimit,
        quality: quality,
        autoCorrectionAngle: true,
        keepExif: false,
        format: CompressFormat.jpeg,
      );
      if (output == null || output.isEmpty) throw const ImageProcessingException(
        code: 'native_encode_empty', message: 'تبدیل نیتیو فایل نتیجه‌ای تولید نکرد.',
      );
      final size = JpegDimensionReader.read(output);
      if (size == null) throw const FormatException('Native encoder produced invalid JPEG.');
      candidates.add((output, quality, size.$1, size.$2));
    }

    await attempt(guess);
    if (targetBytes != null && candidates.first.$1.length > targetBytes) {
      if (guess != request.resizeTriggerQuality) {
        await attempt(request.resizeTriggerQuality.clamp(request.minQuality, request.maxQuality).toInt());
      }
      if (candidates.last.$1.length > targetBytes && candidates.length < 3 && !request.idPhoto) {
        final previous = candidates.last;
        final ratio = math.sqrt(targetBytes / previous.$1.length) * 0.90;
        widthLimit = math.max(request.minShortEdge, (previous.$3 * ratio).round());
        heightLimit = math.max(request.minShortEdge, (previous.$4 * ratio).round());
        await attempt(request.resizeTriggerQuality.clamp(request.minQuality, request.maxQuality).toInt());
      }
    } else if (targetBytes != null && candidates.first.$1.length < targetBytes * 0.92 &&
        guess < request.maxQuality) {
      await attempt(request.maxQuality);
    }
    final acceptable = targetBytes == null
        ? candidates
        : candidates.where((c) => c.$1.length <= targetBytes).toList();
    final sorted = (acceptable.isNotEmpty ? acceptable : candidates).toList()
      ..sort((a, b) => targetBytes == null
          ? b.$2.compareTo(a.$2)
          : acceptable.isNotEmpty
              ? b.$1.length.compareTo(a.$1.length)
              : a.$1.length.compareTo(b.$1.length));
    final best = sorted.first;
    if (request.idPhoto && (best.$3 != 354 || best.$4 != 472)) {
      throw ImageProcessingException(
        code: 'id_photo_wrong_dimensions',
        message: 'خروجی نیتیو به ابعاد دقیق ۳۵۴×۴۷۲ نرسید؛ فایل ذخیره نشد.',
      );
    }
    return NativeEncodeResult(
      bytes: best.$1,
      width: best.$3,
      height: best.$4,
      quality: best.$2,
      resizeCount: widthLimit < 10000 && !request.idPhoto ? 1 : 0,
      passCount: candidates.length,
    );
  }
}
