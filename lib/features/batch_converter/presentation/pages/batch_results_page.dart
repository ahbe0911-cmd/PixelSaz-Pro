import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/export_file_name_policy.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../export/presentation/providers/image_export_provider.dart';
import '../../domain/entities/batch_image_item.dart';
import '../providers/batch_conversion_providers.dart';

enum _ExportOperation { none, saving, sharing }

class BatchResultsPage extends ConsumerStatefulWidget {
  const BatchResultsPage({super.key});

  @override
  ConsumerState<BatchResultsPage> createState() => _BatchResultsPageState();
}

class _BatchResultsPageState extends ConsumerState<BatchResultsPage> {
  late final TextEditingController _batchPrefixController;
  _ExportOperation _operation = _ExportOperation.none;

  bool get _isExporting => _operation != _ExportOperation.none;

  @override
  void initState() {
    super.initState();
    _batchPrefixController = TextEditingController();
  }

  @override
  void dispose() {
    _batchPrefixController.dispose();
    super.dispose();
  }

  void _applyBatchRename(List<BatchImageItem> items) {
    if (items.isEmpty) return;
    try {
      final prefix = ExportFileNamePolicy.sanitizeBaseName(
        _batchPrefixController.text,
      );
      ref.read(batchConversionControllerProvider.notifier)
          .applyBatchRename(prefix);
      _batchPrefixController.text = prefix;
      _showMessage('نام ${items.length} تصویر به‌صورت گروهی تنظیم شد.');
    } on FormatException catch (error) {
      _showMessage(error.message.toString(), isError: true);
    }
  }

  Future<void> _saveItems(List<BatchImageItem> items) async {
    if (_isExporting || items.isEmpty) return;
    setState(() => _operation = _ExportOperation.saving);
    try {
      final outcome = await ref
          .read(imageExportServiceProvider)
          .saveImagesToGallery(items);
      if (!mounted) return;
      if (outcome.failureCount == 0) {
        _showMessage(
          '${outcome.successCount} فایل در آلبوم «PixelSaz Pro» ذخیره شد.',
        );
      } else {
        final firstFailure = outcome.items.firstWhere(
          (item) => !item.success,
        );
        _showMessage(
          '${outcome.successCount} فایل ذخیره شد؛ '
          '${outcome.failureCount} فایل ناموفق بود. ${firstFailure.errorMessage ?? ''}',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) _showMessage(_readableError(error), isError: true);
    } finally {
      if (mounted) setState(() => _operation = _ExportOperation.none);
    }
  }

  Future<void> _shareItems(List<BatchImageItem> items) async {
    if (_isExporting || items.isEmpty) return;
    setState(() => _operation = _ExportOperation.sharing);
    try {
      final result = await ref
          .read(imageExportServiceProvider)
          .shareImages(items);
      if (!mounted) return;
      switch (result.status) {
        case ShareResultStatus.success:
          _showMessage('فایل‌ها با نام‌های انتخاب‌شده به پنجره اشتراک‌گذاری ارسال شدند.');
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
      if (mounted) setState(() => _operation = _ExportOperation.none);
    }
  }

  String _readableError(Object error) =>
      error.toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Exception: ', '')
          .trim();

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchConversionControllerProvider);
    final theme = Theme.of(context);
    final successfulItems = state.items
        .where((item) => item.status == BatchImageStatus.completed)
        .toList(growable: false);
    final failedItems = state.items
        .where((item) => item.status == BatchImageStatus.failed)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نتیجه و خروجی'),
        actions: <Widget>[
          IconButton(
            tooltip: 'پردازش تصاویر جدید',
            onPressed: _isExporting
                ? null
                : () {
                    ref.read(batchConversionControllerProvider.notifier)
                        .clearSelection();
                    context.go('/batch');
                  },
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: state.hasResults
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    children: <Widget>[
                      _SummaryCard(
                        completed: state.successfulCount,
                        failed: state.failedCount,
                        total: state.totalCount,
                        savedBytes: state.totalSavedBytes,
                      ),
                      const SizedBox(height: 16),
                      _BatchRenameCard(
                        controller: _batchPrefixController,
                        enabled: !_isExporting && successfulItems.isNotEmpty,
                        onApply: () => _applyBatchRename(successfulItems),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: <Widget>[
                          Text(
                            'فایل‌های آماده خروجی',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            toPersianDigits(successfulItems.length.toString()),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      ...successfulItems.map(
                        (item) => Padding(
                          key: ValueKey<String>('result_${item.id}'),
                          padding: const EdgeInsets.only(bottom: 11),
                          child: _ResultImageCard(
                            item: item,
                            enabled: !_isExporting,
                            onRename: (value) => ref
                                .read(batchConversionControllerProvider.notifier)
                                .setExportBaseName(item.id, value),
                            onSave: () => _saveItems(<BatchImageItem>[item]),
                            onShare: () => _shareItems(<BatchImageItem>[item]),
                          ),
                        ),
                      ),
                      if (failedItems.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          'فایل‌های ناموفق',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...failedItems.map(
                          (item) => Padding(
                            key: ValueKey<String>('failed_${item.id}'),
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _FailedImageCard(item: item),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ExportActionsCard(
                        enabled: !_isExporting && successfulItems.isNotEmpty,
                        isSaving: _operation == _ExportOperation.saving,
                        isSharing: _operation == _ExportOperation.sharing,
                        onSaveAll: () => _saveItems(successfulItems),
                        onShareAll: () => _shareItems(successfulItems),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.oceanBlue.withAlpha(12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.oceanBlue.withAlpha(35),
                          ),
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.verified_user_outlined,
                              color: AppColors.oceanBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'نام فایل پیش از ذخیره و اشتراک‌گذاری اعمال می‌شود. '
                                'پسوند JPG خودکار اضافه خواهد شد و فایل اصلی پردازش‌شده تغییر نمی‌کند.',
                                textDirection: TextDirection.rtl,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () {
                                ref.read(batchConversionControllerProvider.notifier)
                                    .clearSelection();
                                context.go('/batch');
                              },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('پردازش تصاویر دیگر'),
                      ),
                    ],
                  )
                : _EmptyResults(onBack: () => context.go('/batch')),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.completed,
    required this.failed,
    required this.total,
    required this.savedBytes,
  });

  final int completed;
  final int failed;
  final int total;
  final int savedBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF286CF5), Color(0xFF1747B8)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.oceanBlue.withAlpha(40),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'پردازش صف به پایان رسید',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Expanded(child: _SummaryMetric(value: completed, label: 'موفق', icon: Icons.done_all_rounded)),
              Expanded(child: _SummaryMetric(value: failed, label: 'ناموفق', icon: Icons.error_outline_rounded)),
              Expanded(child: _SummaryMetric(value: total, label: 'کل تصاویر', icon: Icons.photo_library_outlined)),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: <Widget>[
                const Icon(Icons.south_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'مجموع کاهش حجم',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  formatFileSize(savedBytes),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label, required this.icon});

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: Colors.white.withAlpha(220), size: 19),
        const SizedBox(height: 5),
        Text(
          toPersianDigits(value.toString()),
          style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 10.5),
        ),
      ],
    );
  }
}

class _BatchRenameCard extends StatelessWidget {
  const _BatchRenameCard({
    required this.controller,
    required this.enabled,
    required this.onApply,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Icon(Icons.drive_file_rename_outline_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'نام‌گذاری گروهی هوشمند',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'یک نام پایه وارد کنید؛ شماره‌گذاری خودکار انجام می‌شود.',
            textDirection: TextDirection.rtl,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    hintText: 'مثلاً مدارک_علی',
                    prefixIcon: Icon(Icons.edit_outlined),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              FilledButton(
                onPressed: enabled ? onApply : null,
                child: const Text('اعمال'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'نمونه خروجی: مدارک_علی_1.jpg، مدارک_علی_2.jpg و ...',
            textDirection: TextDirection.rtl,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultImageCard extends StatefulWidget {
  const _ResultImageCard({
    required this.item,
    required this.enabled,
    required this.onRename,
    required this.onSave,
    required this.onShare,
  });

  final BatchImageItem item;
  final bool enabled;
  final ValueChanged<String> onRename;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  State<_ResultImageCard> createState() => _ResultImageCardState();
}

class _ResultImageCardState extends State<_ResultImageCard> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.item.effectiveExportBaseName,
    );
  }

  @override
  void didUpdateWidget(covariant _ResultImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextName = widget.item.effectiveExportBaseName;
    if (nextName != oldWidget.item.effectiveExportBaseName &&
        _nameController.text != nextName) {
      _nameController.value = TextEditingValue(
        text: nextName,
        selection: TextSelection.collapsed(offset: nextName.length),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outputPath = widget.item.outputPath;
    final item = widget.item;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: outputPath == null
                      ? const Icon(Icons.image_not_supported_outlined)
                      : Image.file(
                          File(outputPath),
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.originalName,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${formatFileSize(item.sourceSizeBytes)}  ←  ${formatFileSize(item.outputSizeBytes ?? 0)}',
                      textDirection: TextDirection.rtl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      textDirection: TextDirection.rtl,
                      children: <Widget>[
                        _SmallTag(label: '${item.outputWidth ?? 0}×${item.outputHeight ?? 0}'),
                        _SmallTag(label: 'کیفیت ${item.quality ?? 0}'),
                        if (item.targetReached == false)
                          const _SmallTag(label: 'بیشتر از هدف', warning: true),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2, left: 2),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A36A),
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _nameController,
                  enabled: widget.enabled,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: (value) {
                    final withoutExtension =
                        ExportFileNamePolicy.removeKnownImageExtension(value);
                    widget.onRename(withoutExtension);
                    if (withoutExtension != value) {
                      _nameController.value = TextEditingValue(
                        text: withoutExtension,
                        selection: TextSelection.collapsed(
                          offset: withoutExtension.length,
                        ),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'نام فایل خروجی',
                    hintText: 'نام فایل بدون پسوند',
                    isDense: true,
                    suffixText: '.jpg',
                    suffixStyle: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                    prefixIcon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'ذخیره در گالری',
                onPressed: widget.enabled ? widget.onSave : null,
                icon: const Icon(Icons.save_alt_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'اشتراک‌گذاری',
                onPressed: widget.enabled ? widget.onShare : null,
                icon: const Icon(Icons.share_rounded),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'پسوند JPG به‌صورت خودکار افزوده می‌شود.',
              textDirection: TextDirection.rtl,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportActionsCard extends StatelessWidget {
  const _ExportActionsCard({
    required this.enabled,
    required this.isSaving,
    required this.isSharing,
    required this.onSaveAll,
    required this.onShareAll,
  });

  final bool enabled;
  final bool isSaving;
  final bool isSharing;
  final VoidCallback onSaveAll;
  final VoidCallback onShareAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'خروجی نهایی',
            textDirection: TextDirection.rtl,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          FilledButton.icon(
            onPressed: enabled ? onSaveAll : null,
            icon: isSaving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined),
            label: Text(isSaving ? 'در حال ذخیره...' : 'ذخیره همه در گالری'),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: enabled ? onShareAll : null,
            icon: isSharing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(
              isSharing ? 'در حال آماده‌سازی اشتراک...' : 'اشتراک‌گذاری همه تصاویر',
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFD97706) : AppColors.oceanBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FailedImageCard extends StatelessWidget {
  const _FailedImageCard({required this.item});

  final BatchImageItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.originalName,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  item.errorMessage ?? 'خطای نامشخص در پردازش تصویر.',
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.photo_library_outlined, size: 58, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'هنوز نتیجه‌ای برای نمایش وجود ندارد.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('بازگشت به انتخاب تصاویر'),
          ),
        ],
      ),
    );
  }
}
