import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/image_processing/data/datasources/jpeg_dpi_metadata.dart';
import '../../../../core/image_processing/domain/entities/image_compression_options.dart';
import '../../../../core/image_processing/domain/entities/image_processing_progress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../batch_converter/domain/entities/batch_image_item.dart';
import '../../../batch_converter/presentation/providers/batch_conversion_dependencies.dart';
import '../providers/id_photo_providers.dart';
import 'id_photo_camera_page.dart';
import 'id_photo_crop_page.dart';
import 'id_photo_result_page.dart';
import 'id_photo_rotation_page.dart';

class IdPhotoStudioPage extends ConsumerStatefulWidget {
  const IdPhotoStudioPage({super.key});

  @override
  ConsumerState<IdPhotoStudioPage> createState() => _IdPhotoStudioPageState();
}

class _IdPhotoStudioPageState extends ConsumerState<IdPhotoStudioPage> {
  static const Uuid _uuid = Uuid();
  final ImagePicker _picker = ImagePicker();
  int? _targetBytes = 495 * 1024;
  bool _busy = false;
  double _progress = 0;
  String _stage = 'در حال آماده‌سازی';

  Future<void> _captureFromCamera() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const IdPhotoCameraPage()),
    );
    if (path != null && mounted) await _runWorkflow(path);
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (picked != null && mounted) await _runWorkflow(picked.path);
    } catch (error) {
      if (mounted) _showMessage('انتخاب تصویر ناموفق بود: $error', isError: true);
    }
  }

  Future<void> _runWorkflow(String originalPath) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _stage = 'آماده‌سازی تصویر';
    });
    final temporaryPaths = <String>{};
    try {
      final preparedPath = await ref.read(idPhotoImagePreparationServiceProvider).prepareForCrop(originalPath);
      if (preparedPath != originalPath) temporaryPaths.add(preparedPath);
      if (!mounted) return;

      final rotatedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(builder: (_) => IdPhotoRotationPage(sourcePath: preparedPath)),
      );
      if (rotatedPath == null || !mounted) return;
      if (rotatedPath != preparedPath && rotatedPath != originalPath) temporaryPaths.add(rotatedPath);

      final croppedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(builder: (_) => IdPhotoCropPage(sourcePath: rotatedPath)),
      );
      if (croppedPath == null || !mounted) return;
      if (croppedPath != originalPath && croppedPath != preparedPath && croppedPath != rotatedPath) {
        temporaryPaths.add(croppedPath);
      }
      setState(() {
        _progress = 0.03;
        _stage = 'ساخت خروجی ۳×۴';
      });

      final result = await ref.read(imageProcessingServiceProvider).createIdPhotoJpeg(
        inputPath: croppedPath,
        options: IdPhotoOptions(targetBytes: _targetBytes),
        onProgress: (ImageProcessingProgress progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress.fraction;
            _stage = _stageLabel(progress.stage);
          });
        },
      );
      final jfifDpi = JpegDpiMetadata.readJfifDpi(result.bytes);
      if (result.width != AppConstants.idPhotoWidthPx ||
          result.height != AppConstants.idPhotoHeightPx ||
          !result.dpi300Applied ||
          jfifDpi != (AppConstants.idPhotoDpi, AppConstants.idPhotoDpi)) {
        throw StateError('اعتبارسنجی ابعاد یا متادیتای ۳۰۰ DPI خروجی ناموفق بود.');
      }

      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}${Platform.pathSeparator}pixelsaz_pro'
        '${Platform.pathSeparator}id_photo_exports',
      );
      await directory.create(recursive: true);
      final outputFile = File('${directory.path}${Platform.pathSeparator}${_uuid.v4()}.jpg');
      await outputFile.writeAsBytes(result.bytes, flush: true);
      final originalFile = File(originalPath);
      final originalSize = await originalFile.exists() ? await originalFile.length() : result.originalSizeBytes;
      final item = BatchImageItem(
        id: _uuid.v4(),
        path: originalPath,
        originalName: 'عکس_پرسنلی.jpg',
        sourceSizeBytes: originalSize,
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
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => IdPhotoResultPage(item: item, processingResult: result)),
      );
    } catch (error) {
      if (mounted) _showMessage(_readableError(error), isError: true);
    } finally {
      for (final path in temporaryPaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Cleanup must not invalidate a successfully generated output.
        }
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
          _stage = 'در حال آماده‌سازی';
        });
      }
    }
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'reading_source':
      case 'decoding':
        return 'در حال خواندن تصویر';
      case 'converting_heic':
        return 'در حال تبدیل فرمت تصویر';
      case 'preparing_id_photo':
      case 'native_preparing':
        return 'تنظیم ابعاد عکس پرسنلی';
      case 'compressing_id_photo':
      case 'compressing':
        return 'بهینه‌سازی کیفیت و حجم';
      case 'complete':
        return 'آماده‌سازی کامل شد';
      default:
        return 'در حال پردازش تصویر';
    }
  }

  String _readableError(Object error) => error
      .toString()
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Exception: ', '')
      .replaceFirst('ImageProcessingException: ', '')
      .trim();

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ));
  }

  void _setTarget(int? value) {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _targetBytes = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('استودیو عکس پرسنلی')),
      body: Stack(
        children: <Widget>[
          SafeArea(
            top: false,
            bottom: false,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: LayoutBuilder(
                builder: (context, size) {
                  final short = size.maxHeight < 470;
                  final textLarge = MediaQuery.textScalerOf(context).scale(14) > 19;
                  final content = _StudioSettings(
                    targetBytes: _targetBytes,
                    onSetTarget: _setTarget,
                    enabled: !_busy,
                    compact: short || textLarge,
                  );
                  if (size.maxHeight < 390 || textLarge) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: size.maxHeight),
                        child: content,
                      ),
                    );
                  }
                  return content;
                },
              ),
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withAlpha(120),
                child: Center(
                  child: Container(
                    width: 290,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(_stage, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                        const SizedBox(height: 8),
                        Text('${(_progress * 100).round()}٪', style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 688),
            child: SizedBox(
              height: 54,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 6,
                      child: FilledButton.icon(
                        key: const ValueKey<String>('id-camera'),
                        onPressed: _busy ? null : _captureFromCamera,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('گرفتن عکس با دوربین', maxLines: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('id-gallery'),
                        onPressed: _busy ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 19),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('انتخاب از گالری', maxLines: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioSettings extends StatelessWidget {
  const _StudioSettings({
    required this.targetBytes,
    required this.onSetTarget,
    required this.enabled,
    required this.compact,
  });

  final int? targetBytes;
  final ValueChanged<int?> onSetTarget;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 9, 16, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                key: const ValueKey<String>('id-spec-pill'),
                height: 43,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  border: Border.all(color: AppColors.oceanBlue.withAlpha(35)),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.verified_outlined, color: AppColors.oceanBlue, size: 17),
                      const SizedBox(width: 7),
                      Text(
                        '۳×۴ سانتی‌متر   •   ۳۵۴×۴۷۲ پیکسل   •   300 DPI',
                        maxLines: 1,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Text(
                'حجم و کیفیت خروجی',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              _QualityTile(
                key: const ValueKey<String>('quality-print'),
                icon: Icons.print_outlined,
                title: 'کیفیت حداکثری چاپ',
                subtitle: 'بدون محدودیت حجم',
                selected: targetBytes == null,
                enabled: enabled,
                onTap: () => onSetTarget(null),
              ),
              const SizedBox(height: 8),
              _QualityTile(
                key: const ValueKey<String>('quality-200'),
                icon: Icons.speed_rounded,
                title: 'زیر ۲۰۰ کیلوبایت',
                subtitle: 'مناسب سامانه‌های کم‌حجم',
                selected: targetBytes == 200 * 1024,
                enabled: enabled,
                onTap: () => onSetTarget(200 * 1024),
              ),
              const SizedBox(height: 8),
              _QualityTile(
                key: const ValueKey<String>('quality-495'),
                icon: Icons.high_quality_outlined,
                title: 'زیر ۴۹۵ کیلوبایت',
                subtitle: 'پیشنهادی برای استفاده عمومی',
                selected: targetBytes == 495 * 1024,
                enabled: enabled,
                onTap: () => onSetTarget(495 * 1024),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 12),
                const Expanded(child: _FramingGuide()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 67,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: selected ? AppColors.oceanBlue : colors.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: selected ? AppColors.oceanBlue : colors.onSurfaceVariant, size: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: selected ? AppColors.oceanBlue : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FramingGuide extends StatelessWidget {
  const _FramingGuide();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: colors.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colors.surfaceContainerLow,
                ),
              )),
              Icon(Icons.person_outline_rounded, color: AppColors.violet.withAlpha(100), size: 63),
              Positioned.fill(child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.violet.withAlpha(65), width: 1.2),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}