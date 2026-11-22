import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/export_file_name_policy.dart';
import '../../../batch_converter/domain/entities/batch_image_item.dart';
import '../../domain/entities/export_item_outcome.dart';

/// Handles the final file-system handoff for gallery saving and sharing.
///
/// A generated image is never renamed in place. The service copies it to a
/// staging/cache directory using the user's chosen filename, then hands that
/// named copy to the platform API. This preserves the app's original result
/// and the filename presented to receiving applications.
class ImageExportService {
  static const String galleryAlbumName = AppConstants.galleryAlbumName;
  static const String _appCacheFolderName = 'pixelsaz_pro';
  static const Uuid _uuid = Uuid();

  Future<ExportBatchOutcome> saveImagesToGallery(
    List<BatchImageItem> items,
  ) async {
    final prepared = await _prepareItems(items);
    final hasGalleryPermission = await Gal.hasPermission(toAlbum: true);
    if (!hasGalleryPermission) {
      final granted = await Gal.requestPermission(toAlbum: true);
      if (!granted) {
        throw const ImageExportException(
          'مجوز ذخیره در گالری داده نشد. از تنظیمات دستگاه دسترسی تصاویر را فعال کنید.',
        );
      }
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final stagingDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      '$_appCacheFolderName${Platform.pathSeparator}'
      'gallery_${_uuid.v4()}',
    );
    await stagingDirectory.create(recursive: true);

    final outcomes = <ExportItemOutcome>[];
    try {
      for (final entry in prepared) {
        final item = entry.item;
        final fileName = entry.fileName;
        try {
          final source = File(item.outputPath!);
          final stagedFile = File(
            '${stagingDirectory.path}${Platform.pathSeparator}$fileName',
          );
          await source.copy(stagedFile.path);
          await Gal.putImage(stagedFile.path, album: galleryAlbumName);
          outcomes.add(
            ExportItemOutcome(
              itemId: item.id,
              fileName: fileName,
              success: true,
            ),
          );
        } catch (error) {
          outcomes.add(
            ExportItemOutcome(
              itemId: item.id,
              fileName: fileName,
              success: false,
              errorMessage: _readableError(error),
            ),
          );
        }
      }
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }

    return ExportBatchOutcome(List<ExportItemOutcome>.unmodifiable(outcomes));
  }

  Future<ShareResult> shareImages(List<BatchImageItem> items) async {
    final prepared = await _prepareItems(items);
    final temporaryDirectory = await getTemporaryDirectory();
    await _cleanupExpiredShareCaches(temporaryDirectory);
    final shareDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      '$_appCacheFolderName${Platform.pathSeparator}'
      'share_${_uuid.v4()}',
    );
    await shareDirectory.create(recursive: true);

    final shareFiles = <XFile>[];
    final fileNames = <String>[];
    try {
      for (final entry in prepared) {
        final source = File(entry.item.outputPath!);
        final destination = File(
          '${shareDirectory.path}${Platform.pathSeparator}${entry.fileName}',
        );
        await source.copy(destination.path);
        shareFiles.add(XFile(destination.path, mimeType: 'image/jpeg'));
        fileNames.add(entry.fileName);
      }

      // Keep the cache copies after the share sheet closes. Some receiving apps
      // resolve content URIs asynchronously; the OS may clear this cache later.
      return await SharePlus.instance.share(
        ShareParams(
          title: 'اشتراک‌گذاری تصاویر با PixelSaz Pro',
          files: shareFiles,
          fileNameOverrides: fileNames,
        ),
      );
    } catch (_) {
      // Do not leave incomplete cache folders if preparation or handoff fails.
      if (await shareDirectory.exists()) {
        await shareDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> _cleanupExpiredShareCaches(Directory temporaryDirectory) async {
    final appCacheDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}$_appCacheFolderName',
    );
    if (!await appCacheDirectory.exists()) return;

    final expiration = DateTime.now().subtract(const Duration(days: 2));
    await for (final entity in appCacheDirectory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final directoryName = entity.path.split(Platform.pathSeparator).last;
      if (!directoryName.startsWith('share_')) continue;
      try {
        final modified = (await entity.stat()).modified;
        if (modified.isBefore(expiration)) {
          await entity.delete(recursive: true);
        }
      } on FileSystemException {
        // A stale cache entry may already have been removed by the OS.
      }
    }
  }

  Future<List<_PreparedExportItem>> _prepareItems(
    List<BatchImageItem> items,
  ) async {
    if (items.isEmpty) {
      throw const ImageExportException('هیچ تصویری برای خروجی انتخاب نشده است.');
    }

    final fileNames = ExportFileNamePolicy.buildUniqueJpegFileNames(
      items.map((item) => item.effectiveExportBaseName),
    );
    final prepared = <_PreparedExportItem>[];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final outputPath = item.outputPath;
      if (outputPath == null || outputPath.isEmpty) {
        throw ImageExportException(
          'مسیر خروجی تصویر «${item.originalName}» موجود نیست.',
        );
      }
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw ImageExportException(
          'فایل خروجی «${item.originalName}» پیدا نشد. دوباره پردازش کنید.',
        );
      }
      prepared.add(_PreparedExportItem(item, fileNames[index]));
    }
    return prepared;
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'ذخیره فایل ناموفق بود.' : message;
  }
}

class _PreparedExportItem {
  const _PreparedExportItem(this.item, this.fileName);

  final BatchImageItem item;
  final String fileName;
}

class ImageExportException implements Exception {
  const ImageExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
