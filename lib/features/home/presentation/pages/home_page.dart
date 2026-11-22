import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../batch_converter/presentation/providers/batch_conversion_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchState = ref.watch(batchConversionControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      <Widget>[
                        Row(
                          textDirection: TextDirection.rtl,
                          children: <Widget>[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    Color(0xFF5B8DFF),
                                    AppColors.oceanBlue,
                                    AppColors.violet,
                                  ],
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.oceanBlue.withAlpha(65),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 29,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    AppConstants.appName,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  Text(
                                    'استودیوی هوشمند آماده‌سازی تصویر',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => ref.read(themeModeProvider.notifier).toggle(currentlyDark: isDark),
                                child: SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: Icon(
                                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                    color: foreground,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'تصویرت را حرفه‌ای آماده کن',
                          textDirection: TextDirection.rtl,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'تبدیل، فشرده‌سازی و آماده‌سازی عکس در چند مرحله ساده.',
                          textDirection: TextDirection.rtl,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: muted,
                                height: 1.8,
                              ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          textDirection: TextDirection.rtl,
                          children: <Widget>[
                            Text(
                              'ابزارهای اصلی',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              '۲ ابزار تخصصی',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: muted,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 560) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(
                                    flex: 6,
                                    child: BentoToolCard(
                                      height: 228,
                                      title: 'تبدیل و فشرده‌سازی',
                                      description: 'تا ۵۰ تصویر را هم‌زمان به JPG تبدیل کن و حجم آن‌ها را هوشمندانه کاهش بده.',
                                      icon: Icons.photo_library_rounded,
                                      tag: 'ابزار فعال',
                                      colors: const <Color>[
                                        Color(0xFF286CF5),
                                        Color(0xFF1747B8),
                                      ],
                                      onTap: () => context.push('/batch'),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 5,
                                    child: BentoToolCard(
                                      height: 228,
                                      title: 'عکس پرسنلی ۳×۴',
                                      description: 'کادربندی دقیق، راهنمای چهره و خروجی استاندارد چاپ.',
                                      icon: Icons.badge_rounded,
                                      tag: 'شروع استودیو',
                                      colors: const <Color>[
                                        Color(0xFF8B5CEB),
                                        Color(0xFF5D36B7),
                                      ],
                                      onTap: () => context.push('/id-photo'),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: <Widget>[
                                BentoToolCard(
                                  height: 204,
                                  title: 'تبدیل و فشرده‌سازی هوشمند',
                                  description: 'تا ۵۰ تصویر را هم‌زمان به JPG تبدیل کن و حجم آن‌ها را بدون افت غیرضروری کیفیت کاهش بده.',
                                  icon: Icons.photo_library_rounded,
                                  tag: 'شروع پردازش',
                                  colors: const <Color>[
                                    Color(0xFF286CF5),
                                    Color(0xFF1747B8),
                                  ],
                                  onTap: () => context.push('/batch'),
                                ),
                                const SizedBox(height: 14),
                                BentoToolCard(
                                  height: 164,
                                  title: 'عکس پرسنلی ۳×۴',
                                  description: 'کادربندی دقیق و خروجی استاندارد ۳۰۰ DPI',
                                  icon: Icons.badge_rounded,
                                  tag: 'ساخت عکس ۳×۴',
                                  colors: const <Color>[
                                    Color(0xFF8B5CEB),
                                    Color(0xFF5D36B7),
                                  ],
                                  onTap: () => context.push('/id-photo'),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          textDirection: TextDirection.rtl,
                          children: <Widget>[
                            Text(
                              'آخرین پردازش',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const Spacer(),
                            if (batchState.hasResults)
                              TextButton.icon(
                                onPressed: () => context.push('/batch/results'),
                                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                                label: const Text('مشاهده نتایج'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _RecentBatchCard(
                          total: batchState.totalCount,
                          completed: batchState.successfulCount,
                          failed: batchState.failedCount,
                          savedBytes: batchState.totalSavedBytes,
                          hasResults: batchState.hasResults,
                          onTap: batchState.hasResults
                              ? () => context.push('/batch/results')
                              : () => context.push('/batch'),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: Text(
                            'ساخته‌شده برای خروجی‌های دقیق و حرفه‌ای',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: muted,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BentoToolCard extends StatefulWidget {
  const BentoToolCard({
    required this.height,
    required this.title,
    required this.description,
    required this.icon,
    required this.tag,
    required this.colors,
    this.enabled = true,
    this.onTap,
  });

  final double height;
  final String title;
  final String description;
  final IconData icon;
  final String tag;
  final List<Color> colors;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<BentoToolCard> createState() => _BentoToolCardState();
}

class _BentoToolCardState extends State<BentoToolCard> {
  bool _pressed = false;

  void _handleTap() {
    if (!widget.enabled || widget.onTap == null) return;
    HapticFeedback.selectionClick();
    widget.onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled && widget.onTap != null;
    return AnimatedScale(
      scale: _pressed && enabled ? 0.985 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: enabled ? _handleTap : null,
        child: Container(
          height: widget.height,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.colors.first.withAlpha(enabled ? 62 : 28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: -28,
                top: -34,
                child: Container(
                  width: 142,
                  height: 142,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(16),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    textDirection: TextDirection.rtl,
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(19),
                          color: Colors.white.withAlpha(25),
                          border: Border.all(color: Colors.white.withAlpha(42)),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withAlpha(28),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 30),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(24),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withAlpha(35)),
                        ),
                        child: Text(
                          widget.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 11.5,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (!enabled)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(12),
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentBatchCard extends StatelessWidget {
  const _RecentBatchCard({
    required this.total,
    required this.completed,
    required this.failed,
    required this.savedBytes,
    required this.hasResults,
    required this.onTap,
  });

  final int total;
  final int completed;
  final int failed;
  final int savedBytes;
  final bool hasResults;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColors.darkMuted
        : AppColors.lightMuted;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.aqua.withAlpha(22),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.history_rounded, color: AppColors.aqua),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hasResults ? '$completed از $total تصویر آماده شد' : 'هنوز پردازشی ثبت نشده',
                      textDirection: TextDirection.rtl,
                      style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasResults
                          ? '${failed > 0 ? '$failed خطا · ' : ''}کاهش حجم: ${formatFileSize(savedBytes)}'
                          : 'برای شروع، ابزار تبدیل گروهی را باز کن.',
                      textDirection: TextDirection.rtl,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
