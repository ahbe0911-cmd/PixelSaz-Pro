import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/batch_image_item.dart';
import '../controllers/batch_conversion_state.dart';
import '../providers/batch_conversion_providers.dart';

/// Fixed action bar, one-line target presets, and lazily built list. The image
/// selection is the primary content rather than an oversized marketing banner.
class BatchConverterPage extends ConsumerStatefulWidget {
  const BatchConverterPage({super.key});

  @override
  ConsumerState<BatchConverterPage> createState() => _BatchConverterPageState();
}

class _BatchConverterPageState extends ConsumerState<BatchConverterPage> {
  static const _presets = <int>[200 * 1024, 300 * 1024, 495 * 1024, 1024 * 1024];

  Future<void> _run() async {
    HapticFeedback.lightImpact();
    await ref.read(batchConversionControllerProvider.notifier).processBatch();
    if (!mounted) return;
    final updated = ref.read(batchConversionControllerProvider);
    if (updated.hasResults) context.push('/batch/results');
  }

  Future<void> _setCustomTarget(int current) async {
    final kb = TextEditingController(text: (current / 1024).round().toString());
    final formKey = GlobalKey<FormState>();
    try {
      final size = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حجم دلخواه خروجی'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: kb,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'کیلوبایت',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
              validator: (value) {
                final n = int.tryParse(value ?? '');
                if (n == null || n < 20 || n > 102400) {
                  return 'بین ۲۰ تا ۱۰۲۴۰۰ کیلوبایت انتخاب کنید.';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, int.parse(kb.text) * 1024);
                }
              },
              child: const Text('تأیید'),
            ),
          ],
        ),
      );
      if (mounted && size != null) {
        ref.read(batchConversionControllerProvider.notifier).setTargetBytes(size);
      }
    } finally {
      kb.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchConversionControllerProvider);
    final controller = ref.read(batchConversionControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final selectedPreset = _presets.contains(state.targetBytes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تبدیل گروهی'),
        actions: <Widget>[
          if (state.items.isNotEmpty && !state.isProcessing)
            IconButton(
              tooltip: 'پاک کردن فهرست',
              onPressed: () {
                HapticFeedback.selectionClick();
                controller.clearSelection();
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      key: const ValueKey<String>('target-presets'),
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 5),
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final isCustom = index == 4;
                        final target = isCustom ? state.targetBytes : _presets[index];
                        final selected = isCustom ? !selectedPreset : target == state.targetBytes;
                        final title = isCustom
                            ? (selected ? 'دلخواه: ${toPersianDigits((target / 1024).round().toString())}' : 'دلخواه')
                            : target == 1024 * 1024
                                ? '۱ مگابایت'
                                : '${toPersianDigits((target / 1024).round().toString())} کیلوبایت';
                        return _TargetChip(
                          title: title,
                          selected: selected,
                          onTap: state.isProcessing
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  if (isCustom) {
                                    _setCustomTarget(state.targetBytes);
                                  } else {
                                    controller.setTargetBytes(target);
                                  }
                                },
                        );
                      },
                    ),
                  ),
                  if (state.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 2, 16, 7),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.info_outline_rounded, size: 17, color: colors.onErrorContainer),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (state.isProcessing)
                    _InlineProgress(state: state),
                  Expanded(
                    child: state.items.isEmpty
                        ? _EmptyImagePicker(
                            isPicking: state.isPicking,
                            onPick: () {
                              HapticFeedback.lightImpact();
                              controller.pickImages();
                            },
                          )
                        : _ImageQueue(
                            state: state,
                            onAdd: state.isProcessing || state.isPicking
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    controller.pickImages();
                                  },
                            onRemove: controller.removeImage,
                          ),
                  ),
                ],
              ),
            ),
          ),
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
              width: double.infinity,
              height: 54,
              child: state.isProcessing
                  ? OutlinedButton.icon(
                      onPressed: state.isCancelling ? null : controller.cancelBatch,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(state.isCancelling ? 'در حال توقف...' : 'توقف صف پس از کارهای فعال'),
                    )
                  : FilledButton.icon(
                      onPressed: state.canStart ? _run : null,
                      icon: const Icon(Icons.bolt_rounded),
                      label: Text(state.totalCount == 0
                          ? 'ابتدا عکس انتخاب کنید'
                          : 'شروع تبدیل ${toPersianDigits(state.totalCount.toString())} تصویر'),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.title, required this.selected, required this.onTap});
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? AppColors.oceanBlue : colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.oceanBlue : colors.outlineVariant),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : colors.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyImagePicker extends StatelessWidget {
  const _EmptyImagePicker({required this.isPicking, required this.onPick});
  final bool isPicking;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          key: const ValueKey<String>('open-gallery'),
          onTap: isPicking ? null : onPick,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant, width: 1.3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: isPicking
                      ? const Padding(padding: EdgeInsets.all(25), child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_photo_alternate_rounded, color: AppColors.oceanBlue, size: 39),
                ),
                const SizedBox(height: 18),
                Text(
                  isPicking ? 'در حال باز کردن گالری' : 'انتخاب عکس از گالری',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  'حداکثر ۵۰ تصویر · JPG، PNG، WebP، HEIC، BMP',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageQueue extends StatelessWidget {
  const _ImageQueue({required this.state, required this.onAdd, required this.onRemove});
  final BatchConversionState state;
  final VoidCallback? onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 7, 10, 4),
          child: SizedBox(
            height: 43,
            child: Row(
              children: <Widget>[
                Text('فایل‌های انتخاب‌شده', style: theme.textTheme.titleSmall),
                const SizedBox(width: 7),
                Text(
                  '${toPersianDigits(state.totalCount.toString())} / ${toPersianDigits(AppConstants.maximumBatchSelection.toString())}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey<String>('add-more'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.oceanBlue),
                  tooltip: 'افزودن بیشتر',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const ValueKey<String>('selected-image-list'),
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 12),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _SelectedImageTile(
                key: ValueKey<String>(item.id),
                item: item,
                canRemove: !state.isProcessing && !state.isPicking,
                onRemove: () => onRemove(item.id),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
          ),
        ),
      ],
    );
  }
}

class _SelectedImageTile extends StatelessWidget {
  const _SelectedImageTile({super.key, required this.item, required this.canRemove, required this.onRemove});
  final BatchImageItem item;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = switch (item.status) {
      BatchImageStatus.selected => 'آماده تبدیل',
      BatchImageStatus.processing => item.stage,
      BatchImageStatus.completed => 'تبدیل شد',
      BatchImageStatus.failed => 'خطا در این تصویر',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 77),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 57,
              height: 57,
              child: Image.file(
                File(item.path),
                cacheWidth: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  item.originalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatFileSize(item.sourceSizeBytes)}  ·  ${status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.hasFailed ? colors.error : colors.onSurfaceVariant,
                  ),
                ),
                if (item.status == BatchImageStatus.processing)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: LinearProgressIndicator(value: item.progress, minHeight: 3),
                  ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              tooltip: 'حذف تصویر',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 19),
              color: colors.onSurfaceVariant,
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _InlineProgress extends StatelessWidget {
  const _InlineProgress({required this.state});
  final BatchConversionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('در حال تبدیل', style: theme.textTheme.labelMedium),
              const Spacer(),
              Text(
                '${toPersianDigits(state.completedCount.toString())} / ${toPersianDigits(state.totalCount.toString())} · ${toPersianDigits((state.overallProgress * 100).round().toString())}٪',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: state.overallProgress,
            minHeight: 5,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}