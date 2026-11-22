import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/export_file_name_policy.dart';
import '../../../batch_converter/domain/entities/batch_image_item.dart';

/// A generated ZIP and the number of JPEG images inside it.
class ZipExportResult {
  const ZipExportResult({
    required this.path,
    required this.fileName,
    required this.imageCount,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final int imageCount;
  final int sizeBytes;
}

/// Describes the opened UI. Launching a share activity is not delivery.
class ZipShareOutcome {
  const ZipShareOutcome({
    required this.zip,
    required this.openedBale,
    this.shareResult,
  });

  final ZipExportResult zip;
  final bool openedBale;
  final ShareResult? shareResult;
}

class ZipExportService {
  ZipExportService({MethodChannel? baleChannel})
      : _baleChannel = baleChannel ??
            const MethodChannel('pixelsaz_pro/zip_share');

  static const Uuid _uuid = Uuid();
  static const String _cacheRoot = 'pixelsaz_pro';
  static const Duration _cacheRetention = Duration(days: 2);

  final MethodChannel _baleChannel;

  /// Creates one ZIP from successfully converted images using their chosen
  /// export names. JPEGs are stored without lossy re-encoding or extra deflate.
  Future<ZipExportResult> createZip(List<BatchImageItem> items) async {
    if (items.isEmpty) {
      throw const ZipExportException('هیچ تصویر آماده‌ای برای ساخت ZIP وجود ندارد.');
    }

    final fileNames = ExportFileNamePolicy.buildUniqueJpegFileNames(
      items.map((item) => item.effectiveExportBaseName),
    );

    final inputs = <ZipInputFile>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (!item.isCompleted || item.outputPath == null) {
        throw ZipExportException(
          'فایل «' + item.originalName + '» هنوز برای اشتراک‌گذاری آماده نیست.',
        );
      }
      final file = File(item.outputPath!);
      if (!await file.exists() || await file.length() == 0) {
        throw ZipExportException(
          'فایل خروجی «' + item.originalName + '» موجود نیست.',
        );
      }
      inputs.add(ZipInputFile(file.path, fileNames[index]));
    }

    final temporary = await getTemporaryDirectory();
    final appCache = Directory(
      temporary.path + Platform.pathSeparator + _cacheRoot,
    );
    await appCache.create(recursive: true);
    await _cleanupExpiredZips(appCache);

    final working = Directory(
      appCache.path + Platform.pathSeparator + 'zip_' + _uuid.v4(),
    );
    await working.create(recursive: true);
    final zipName = 'PixelSaz-Pro_' + inputs.length.toString() + '-photos.zip';
    final zipFile = File(
      working.path + Platform.pathSeparator + zipName,
    );

    try {
      await Isolate.run<void>(
        () => writeZipFiles(zipFile.path, inputs),
      );
      final size = await zipFile.length();
      if (size == 0) {
        throw const ZipExportException('فایل ZIP ایجادشده خالی است.');
      }
      return ZipExportResult(
        path: zipFile.path,
        fileName: zipName,
        imageCount: inputs.length,
        sizeBytes: size,
      );
    } catch (_) {
      if (await working.exists()) {
        await working.delete(recursive: true);
      }
      rethrow;
    }
  }

  /// Direct launch in Bale on Android, graceful system share fallback.
  Future<ZipShareOutcome> shareZip(List<BatchImageItem> items) async {
    final archive = await createZip(items);

    if (Platform.isAndroid) {
      try {
        final opened = await _baleChannel.invokeMethod<bool>(
          'shareToBale',
          <String, Object>{'zipPath': archive.path},
        );
        if (opened == true) {
          return ZipShareOutcome(zip: archive, openedBale: true);
        }
      } on MissingPluginException {
        // Native bridge absent on test/non-Android hosts.
      } on PlatformException {
        // Bale unavailable, no ZIP receiver, or platform security restriction.
      }
    }

    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'فایل ZIP تصاویر پیکسل‌ساز پرو',
        files: <XFile>[XFile(archive.path, mimeType: 'application/zip')],
        fileNameOverrides: <String>[archive.fileName],
      ),
    );
    return ZipShareOutcome(
      zip: archive,
      openedBale: false,
      shareResult: result,
    );
  }

  Future<void> _cleanupExpiredZips(Directory appCache) async {
    final expiry = DateTime.now().subtract(_cacheRetention);
    await for (final entry in appCache.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final parts = entry.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (parts.isEmpty || !parts.last.startsWith('zip_')) continue;
      try {
        if ((await entry.stat()).modified.isBefore(expiry)) {
          await entry.delete(recursive: true);
        }
      } on FileSystemException {
        // Cache may already have been reclaimed by the operating system.
      }
    }
  }
}

class ZipInputFile {
  const ZipInputFile(this.path, this.fileName);
  final String path;
  final String fileName;
}

/// Pure disk streaming; can run on a worker isolate and in unit tests.
Future<void> writeZipFiles(String outputPath, List<ZipInputFile> inputs) async {
  if (inputs.isEmpty) {
    throw const ZipExportException('فهرست فایل‌های ZIP خالی است.');
  }

  final writer = ZipFileEncoder();
  var opened = false;
  try {
    writer.create(outputPath, level: ZipFileEncoder.store);
    opened = true;
    for (final entry in inputs) {
      if (entry.fileName.contains('/') ||
          entry.fileName.contains('\\') ||
          entry.fileName == '..' ||
          entry.fileName.isEmpty) {
        throw const ZipExportException('نام فایل برای ZIP معتبر نیست.');
      }
      final file = File(entry.path);
      if (!await file.exists()) {
        throw ZipExportException('فایل پیدا نشد: ' + entry.fileName);
      }
      await writer.addFile(file, entry.fileName, ZipFileEncoder.store);
    }
  } finally {
    if (opened) {
      await writer.close();
    }
  }
}

class ZipExportException implements Exception {
  const ZipExportException(this.message);
  final String message;

  @override
  String toString() => message;
}
