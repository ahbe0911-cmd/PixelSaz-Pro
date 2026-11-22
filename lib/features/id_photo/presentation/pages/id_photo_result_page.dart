import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/image_processing/domain/entities/image_processing_result.dart';
import '../../../../core/utils/export_file_name_policy.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../batch_converter/domain/entities/batch_image_item.dart';
import '../../../export/presentation/providers/image_export_provider.dart';

class IdPhotoResultPage extends ConsumerStatefulWidget {
  const IdPhotoResultPage({
    super.key,
    required this.item,
    required this.processingResult,
  });

  final BatchImageItem item;
  final ImageProcessingResult processingResult;

  @override
  ConsumerState<IdPhotoResultPage> createState() => _IdPhotoResultPageState();
}

class _IdPhotoResultPageState extends ConsumerState<IdPhotoResultPage> {
  late final TextEditingController _nameController;
  bool _saving = false;
  bool _sharing = false;
  bool _saved = false;

  bool get _busy => _saving || _sharing;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.effectiveExportBaseName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  BatchImageItem _itemWithValidatedName() {
    final safeName = ExportFileNamePolicy.sanitizeBaseName(_nameController.text);
    return widget.item.copyWith(exportBaseName: safeName);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _saving = true);
    try {
      final item = _itemWithValidatedName();
      final outcome = await ref.read(imageExportServiceProvider).saveImagesToGallery(<BatchImageItem>[item]);
      if (!mounted) return;
      final failures = outcome.items.where((entry) => !entry.success).toList(growable: false);
      final firstFailure = failures.isNotEmpty ? failures.first : null;
      if (outcome.successCount == 1) {
        setState(() => _saved = true);
        _showMessage('عکس با نام ${outcome.items.first.fileName} در آلبوم PixelSaz Pro ذخیره شد.');
      } else {
        _showMessage(firstFailure?.errorMessage ?? 'ذخیره عکس انجام نشد.', isError: true);
      }
    } catch (error) {
      if (mounted) _showMessage(_readableError(error), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _sharing = true);
    try {
      final item = _itemWithValidatedName();
      final result = await ref.read(imageExportServiceProvider).shareImages(<BatchImageItem>[item]);
      if (!mounted) return;
      switch (result.status) {
        case ShareResultStatus.success:
          _showMessage('فایل با نام انتخاب‌شده برای اشتراک‌گذاری ارسال شد.');
          break;
        case ShareResultStatus.dismissed:
          _showMessage('پنجره اشتراک‌گذاری بسته شد.');
          break;
        case ShareResultStatus.unavailable:
          _showMessage('پنجره اشتراک‌گذاری باز شد؛ وضعیت مقصد قابل تشخیص نیست.');
          break;
      }
    } catch (error) {
      if (mounted) _showMessage(_readableError(error), isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _readableError(Object error) => error
      .toString()
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Exception: ', '')
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
    final result = widget.processingResult;
    final outputPath = widget.item.outputPath!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('خروجی عکس پرسنلی')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 218,
                      width: 164,
                      child: Image.file(File(outputPath), cacheWidth: 328, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.verified_rounded, color: Colors.green, size: 19),
                      SizedBox(width: 6),
                      Text('خروجی استاندارد آماده است', style: TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(child: _SpecTile(label: 'ابعاد', value: '${result.width} × ${result.height}')),
                const SizedBox(width: 10),
                Expanded(child: _SpecTile(label: 'وضوح چاپ', value: '300 DPI')),
                const SizedBox(width: 10),
                Expanded(child: _SpecTile(label: 'فرمت', value: 'JPG')),
              ],
            ),
            const SizedBox(height: 12),
            _SizeComparison(
              beforeBytes: widget.item.sourceSizeBytes,
              afterBytes: result.outputSizeBytes,
            ),
            const SizedBox(height: 12),
            if (!result.targetReached)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'به محدودیت حجم انتخاب‌شده نرسیدیم؛ برای حفظ ابعاد دقیق چاپ، کمترین کیفیت مجاز استفاده شده است.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(height: 1.7),
                ),
              ),
            const SizedBox(height: 20),
            Text('نام فایل خروجی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_saved) setState(() => _saved = false);
              },
              decoration: InputDecoration(
                hintText: 'مثلاً عکس_پرسنلی',
                suffixText: '.jpg',
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'پسوند JPG به‌صورت خودکار اضافه می‌شود.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 688),
            child: SizedBox(
              height: 52,
              child: Row(
                textDirection: TextDirection.rtl,
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 17, height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_saved ? Icons.check_circle_rounded : Icons.save_alt_rounded),
                      label: Text(_saving ? 'در حال ذخیره...' : _saved ? 'ذخیره شد' : 'ذخیره در گالری'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: _sharing
                          ? const SizedBox(width: 17, height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.share_rounded),
                      label: const Text('اشتراک‌گذاری'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SizeComparison extends StatelessWidget {
  const _SizeComparison({required this.beforeBytes, required this.afterBytes});

  final int beforeBytes;
  final int afterBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('حجم اولیه', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(formatFileSize(beforeBytes), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_rounded, color: Colors.green),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('حجم خروجی', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(formatFileSize(afterBytes), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
