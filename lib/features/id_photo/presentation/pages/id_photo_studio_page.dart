import 'dart:io';

import 'package:flutter/material.dart';
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
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const IdPhotoCameraPage()),
    );
    if (path != null && mounted) await _runWorkflow(path);
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
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
      final preparedPath = await ref
          .read(idPhotoImagePreparationServiceProvider)
          .prepareForCrop(originalPath);
      if (preparedPath != originalPath) temporaryPaths.add(preparedPath);
      if (!mounted) return;

      final rotatedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => IdPhotoRotationPage(sourcePath: preparedPath),
        ),
      );
      if (rotatedPath == null || !mounted) return;
      if (rotatedPath != preparedPath && rotatedPath != originalPath) {
        temporaryPaths.add(rotatedPath);
      }

      final croppedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => IdPhotoCropPage(sourcePath: rotatedPath),
        ),
      );
      if (croppedPath == null || !mounted) return;
      if (croppedPath != originalPath && croppedPath != preparedPath && croppedPath != rotatedPath) {
        temporaryPaths.add(croppedPath);
      }

      setState(() {
        _progress = 0.03;
        _stage = 'ساخت خروجی ۳×۴';
      });

      final processingService = ref.read(imageProcessingServiceProvider);
      final result = await processingService.createIdPhotoJpeg(
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

      final supportDirectory = await getApplicationSupportDirectory();
      final outputDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}pixelsaz_pro'
        '${Platform.pathSeparator}id_photo_exports',
      );
      await outputDirectory.create(recursive: true);
      final outputFile = File(
        '${outputDirectory.path}${Platform.pathSeparator}${_uuid.v4()}.jpg',
      );
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
        MaterialPageRoute<void>(
          builder: (_) => IdPhotoResultPage(item: item, processingResult: result),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_readableError(error), isError: true);
    } finally {
      for (final path in temporaryPaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Temporary cleanup must not hide a successful export.
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
        return 'تنظیم ابعاد عکس پرسنلی';
      case 'compressing_id_photo':
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
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('استودیوی عکس پرسنلی')),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('PHOTO STUDIO  ·  3:4',
                              style: TextStyle(color: AppColors.violet,
                                fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .8)),
                            const SizedBox(height: 7),
                            Text('عکس پرسنلی، با دقت چاپ',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Text('عکس عمودی را بدون چرخش ناخواسته کادربندی کن؛ اندازه و کیفیت خروجی را خودت انتخاب کن.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant, height: 1.7)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 72, height: 91,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          gradient: const LinearGradient(
                            colors: <Color>[Color(0xFFE5E8FF), Color(0xFFC9E7FA)],
                          ),
                        ),
                        child: const Icon(Icons.portrait_rounded,
                          size: 43, color: AppColors.violet),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('مشخصات خروجی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(child: _SpecCard(icon: Icons.aspect_ratio_rounded, title: '۳۵۴ × ۴۷۲', subtitle: 'پیکسل')),
                    const SizedBox(width: 10),
                    Expanded(child: _SpecCard(icon: Icons.print_rounded, title: '300 DPI', subtitle: 'تراکم چاپ')),
                    const SizedBox(width: 10),
                    Expanded(child: _SpecCard(icon: Icons.photo_size_select_actual_outlined, title: '۳ × ۴', subtitle: 'سانتی‌متر اسمی')),
                  ],
                ),
                const SizedBox(height: 22),
                Text('حجم خروجی را انتخاب کنید', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _TargetOption(
                  title: 'کیفیت حداکثری چاپ',
                  subtitle: 'بدون محدودیت حجم؛ مناسب چاپ با کیفیت بالا',
                  selected: _targetBytes == null,
                  onTap: _busy ? null : () => setState(() => _targetBytes = null),
                ),
                const SizedBox(height: 8),
                _TargetOption(
                  title: 'حداکثر ۲۰۰ کیبی‌بایت',
                  subtitle: 'مناسب سامانه‌هایی با محدودیت حجم پایین',
                  selected: _targetBytes == 200 * 1024,
                  onTap: _busy ? null : () => setState(() => _targetBytes = 200 * 1024),
                ),
                const SizedBox(height: 8),
                _TargetOption(
                  title: 'حداکثر ۴۹۵ کیبی‌بایت',
                  subtitle: 'حالت پیشنهادی برای استفاده عمومی',
                  selected: _targetBytes == 495 * 1024,
                  onTap: _busy ? null : () => setState(() => _targetBytes = 495 * 1024),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _captureFromCamera,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('گرفتن عکس با دوربین'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('انتخاب عکس از گالری'),
                ),
                const SizedBox(height: 14),
                Text(
                  'نکته: خروجی ۳۵۴×۴۷۲ با متادیتای JFIF و EXIF روی ۳۰۰ DPI تنظیم می‌شود. پذیرش عکس توسط سامانه‌ها به الزامات همان سامانه نیز بستگی دارد.',
                  textAlign: TextAlign.justify,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withAlpha(115),
                child: Center(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 18),
                        Text(_stage, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.violet, size: 21),
          const SizedBox(height: 7),
          Text(title, textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TargetOption extends StatelessWidget {
  const _TargetOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer.withAlpha(150) : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(title, textDirection: TextDirection.rtl,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle, textDirection: TextDirection.rtl,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
