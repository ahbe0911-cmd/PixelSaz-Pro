import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/batch_image_item.dart';
import '../providers/batch_conversion_providers.dart';

class BatchConverterPage extends ConsumerStatefulWidget {
  const BatchConverterPage({super.key});

  @override
  ConsumerState<BatchConverterPage> createState() => _BatchConverterPageState();
}

class _BatchConverterPageState extends ConsumerState<BatchConverterPage> {
  static const List<int> _presetTargets = <int>[
    200 * 1024,
    300 * 1024,
    495 * 1024,
    1024 * 1024,
  ];

  Future<void> _startProcessing() async {
    final controller = ref.read(batchConversionControllerProvider.notifier);
    await controller.processBatch();
    if (!mounted) return;
    final state = ref.read(batchConversionControllerProvider);
    if (state.hasResults) {
      context.push('/batch/results');
    }
  }

  Future<void> _chooseCustomTarget(int currentBytes) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _CustomTargetDialog(currentBytes: currentBytes),
    );
    if (result != null && mounted) {
      ref.read(batchConversionControllerProvider.notifier).setTargetBytes(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchConversionControllerProvider);
    final controller = ref.read(batchConversionControllerProvider.notifier);
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColors.darkMuted
        : AppColors.lightMuted;
    final isPreset = _presetTargets.contains(state.targetBytes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تبدیل گروهی تصاویر'),
        actions: <Widget>[
          if (state.items.isNotEmpty && !state.isProcessing)
            IconButton(
              tooltip: 'پاک کردن فهرست',
              onPressed: controller.clearSelection,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: <Widget>[
                _IntroPanel(
                  count: state.totalCount,
                  isProcessing: state.isProcessing,
                ),
                const SizedBox(height: 18),
                _SectionHeading(
                  title: 'حجم هدف خروجی',
                  subtitle: 'حداکثر حجم هر فایل JPEG را تعیین کن.',
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 8,
                  runSpacing: 9,
                  textDirection: TextDirection.rtl,
                  children: <Widget>[
                    for (final target in _presetTargets)
                      ChoiceChip(
                        label: Text(_targetLabel(target)),
                        selected: state.targetBytes == target,
                        onSelected: state.isProcessing
                            ? null
                            : (_) => controller.setTargetBytes(target),
                        showCheckmark: true,
                      ),
                    ChoiceChip(
                      label: Text(
                        isPreset ? 'دلخواه' : 'دلخواه · ${formatFileSize(state.targetBytes)}',
                      ),
                      selected: !isPreset,
                      avatar: const Icon(Icons.tune_rounded, size: 17),
                      onSelected: state.isProcessing
                          ? null
                          : (_) => _chooseCustomTarget(state.targetBytes),
                    ),
                  ],
                ),
                const SizedBox(height: 19),
                _SectionHeading(
                  title: 'انتخاب تصاویر',
                  subtitle: 'فرمت‌های JPG، PNG، WebP، BMP و HEIC قابل بررسی هستند.',
                ),
                const SizedBox(height: 11),
                _PickerPanel(
                  count: state.totalCount,
                  isPicking: state.isPicking,
                  enabled: !state.isProcessing,
                  onTap: controller.pickImages,
                ),
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _MessagePanel(message: state.errorMessage!),
                ],
                if (state.isProcessing) ...<Widget>[
                  const SizedBox(height: 20),
                  _ProgressPanel(
                    progress: state.overallProgress,
                    completed: state.completedCount,
                    total: state.totalCount,
                    isCancelling: state.isCancelling,
                  ),
                ],
                if (state.items.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'فهرست فایل‌ها',
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Text(
                        '${toPersianDigits(state.totalCount.toString())} / ${toPersianDigits(AppConstants.maximumBatchSelection.toString())}',
                        style: theme.textTheme.labelMedium?.copyWith(color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...state.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _QueueImageTile(
                        item: item,
                        enabled: !state.isProcessing,
                        onRemove: () => controller.removeImage(item.id),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'پردازش تصاویر به‌صورت صف کنترل‌شده انجام می‌شود تا مصرف حافظه گوشی مدیریت شود.',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        height: 1.8,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: SizedBox(
            height: 56,
            child: state.isProcessing
                ? OutlinedButton.icon(
                    onPressed: state.isCancelling ? null : controller.cancelBatch,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(state.isCancelling ? 'در حال توقف صف…' : 'توقف پس از تصویر جاری'),
                  )
                : ElevatedButton.icon(
                    onPressed: state.canStart ? _startProcessing : null,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      state.totalCount == 0
                          ? 'ابتدا تصاویر را انتخاب کن'
                          : 'شروع پردازش ${toPersianDigits(state.totalCount.toString())} تصویر',
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String _targetLabel(int bytes) {
    if (bytes == 1024 * 1024) return '۱ مگابایت';
    return '${toPersianDigits((bytes / 1024).round().toString())} کیلوبایت';
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.count, required this.isProcessing});

  final int count;
  final bool isProcessing;

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
            color: AppColors.oceanBlue.withAlpha(42),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(45)),
            ),
            child: const Icon(Icons.collections_rounded, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'چند تصویر، یک خروجی استاندارد',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isProcessing
                      ? 'پردازش در حال انجام است.'
                      : 'انتخاب گروهی تا ۵۰ تصویر با کنترل هوشمند حجم.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 11.5,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(22),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              '${toPersianDigits(count.toString())}/۵۰',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkMuted
        : AppColors.lightMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _PickerPanel extends StatelessWidget {
  const _PickerPanel({
    required this.count,
    required this.isPicking,
    required this.enabled,
    required this.onTap,
  });

  final int count;
  final bool isPicking;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: enabled && !isPicking ? onTap : null,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1.2,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.oceanBlue.withAlpha(15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: isPicking
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.add_photo_alternate_rounded, color: AppColors.oceanBlue),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isPicking ? 'در حال باز کردن گالری…' : 'انتخاب از گالری',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0 ? 'برای انتخاب یک یا چند تصویر لمس کن.' : 'برای افزودن تصاویر بیشتر لمس کن.',
                      textDirection: TextDirection.rtl,
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.progress,
    required this.completed,
    required this.total,
    required this.isCancelling,
  });

  final double progress;
  final int completed;
  final int total;
  final bool isCancelling;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(17),
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
              const Icon(Icons.sync_rounded, color: AppColors.oceanBlue),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isCancelling ? 'در حال پایان دادن به صف…' : 'پردازش تصاویر',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${toPersianDigits((progress * 100).round().toString())}٪',
                style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.oceanBlue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${toPersianDigits(completed.toString())} از ${toPersianDigits(total.toString())} تصویر بررسی شد.',
            textDirection: TextDirection.rtl,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _QueueImageTile extends StatelessWidget {
  const _QueueImageTile({
    required this.item,
    required this.enabled,
    required this.onRemove,
  });

  final BatchImageItem item;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final statusColor = switch (item.status) {
      BatchImageStatus.selected => muted,
      BatchImageStatus.processing => AppColors.oceanBlue,
      BatchImageStatus.completed => const Color(0xFF16A36A),
      BatchImageStatus.failed => theme.colorScheme.error,
    };
    final statusText = switch (item.status) {
      BatchImageStatus.selected => 'آماده پردازش',
      BatchImageStatus.processing => item.stage,
      BatchImageStatus.completed => 'تکمیل شد',
      BatchImageStatus.failed => 'خطا در پردازش',
    };

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Image.file(
                File(item.path),
                fit: BoxFit.cover,
                cacheWidth: 200,
                cacheHeight: 120,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported_outlined),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Row(
                  textDirection: TextDirection.rtl,
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusText,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                      ),
                    ),
                  ],
                ),
                if (item.status == BatchImageStatus.processing) ...<Widget>[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ] else if (item.outputSizeBytes != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    '${formatFileSize(item.sourceSizeBytes)}  ←  ${formatFileSize(item.outputSizeBytes!)}',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    formatFileSize(item.sourceSizeBytes),
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
          if (enabled)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'حذف از فهرست',
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, color: muted, size: 20),
            )
          else if (item.status == BatchImageStatus.completed)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A36A)),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomTargetDialog extends StatefulWidget {
  const _CustomTargetDialog({required this.currentBytes});

  final int currentBytes;

  @override
  State<_CustomTargetDialog> createState() => _CustomTargetDialogState();
}

class _CustomTargetDialogState extends State<_CustomTargetDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.currentBytes / 1024).round().toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(normalizeDigits(_controller.text.trim()));
    if (value == null || value < 10 || value > 20480) {
      setState(() => _error = 'مقدار باید بین ۱۰ تا ۲۰۴۸۰ کیلوبایت باشد.');
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(value * 1024);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('حجم دلخواه'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('حداکثر حجم خروجی را برحسب کیلوبایت وارد کن.'),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
            ],
            decoration: InputDecoration(
              labelText: 'حجم برحسب KB',
              errorText: _error,
              suffixText: 'KB',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('ثبت حجم'),
        ),
      ],
    );
  }
}
