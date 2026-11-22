import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../batch_converter/presentation/controllers/batch_conversion_state.dart';
import '../../../batch_converter/presentation/providers/batch_conversion_providers.dart';

/// Two actions and the recent activity stay visible without scrolling on a
/// normal phone. Exceptionally short screens and large accessibility fonts
/// scroll instead of clipping the controls.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final batch = ref.watch(batchConversionControllerProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final isCompact = constraints.maxHeight < 660;
                final useScrollableFallback = constraints.maxHeight < 535 ||
                    constraints.maxWidth < 315 ||
                    textScale > 1.35;
                final page = _HomeContent(
                  batch: batch,
                  compact: isCompact,
                  dark: dark,
                  onTheme: () {
                    HapticFeedback.lightImpact();
                    ref.read(themeModeProvider.notifier).toggle(currentlyDark: dark);
                  },
                  onConvert: () => context.push('/batch'),
                  onIdPhoto: () => context.push('/id-photo'),
                  onHistory: () => context.push(
                    batch.hasResults ? '/batch/results' : '/batch',
                  ),
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 690),
                    child: useScrollableFallback
                        ? SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SizedBox(height: 630, child: page),
                          )
                        : page,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.batch,
    required this.compact,
    required this.dark,
    required this.onTheme,
    required this.onConvert,
    required this.onIdPhoto,
    required this.onHistory,
  });

  final BatchConversionState batch;
  final bool compact;
  final bool dark;
  final VoidCallback onTheme;
  final VoidCallback onConvert;
  final VoidCallback onIdPhoto;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(18, compact ? 8 : 14, 18, compact ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BrandHeader(dark: dark, onTheme: onTheme),
          SizedBox(height: compact ? 13 : 19),
          const _SectionLabel(title: 'ابزارهای شما', supporting: 'دو ابزار حرفه‌ای'),
          const SizedBox(height: 10),
          Expanded(
            flex: 11,
            child: _ActionCard(
              title: 'تبدیل و فشرده‌سازی گروهی',
              description: 'تبدیل سریع تا ۵۰ عکس به JPG با حجم دلخواه',
              action: 'انتخاب تصاویر',
              icon: Icons.photo_library_rounded,
              primary: true,
              onTap: onConvert,
            ),
          ),
          const SizedBox(height: 11),
          Expanded(
            flex: 9,
            child: _ActionCard(
              title: 'استودیو عکس پرسنلی ۳×۴',
              description: 'کادربندی دقیق، کیفیت چاپ و 300 DPI',
              action: 'ساخت عکس',
              icon: Icons.portrait_rounded,
              primary: false,
              onTap: onIdPhoto,
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          _SectionLabel(
            title: 'آخرین فعالیت‌ها',
            action: batch.hasResults ? 'مشاهده نتایج' : null,
            onAction: batch.hasResults ? onHistory : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: compact ? 77 : 86,
            child: _RecentActivity(batch: batch, dark: dark, onTap: onHistory),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.dark, required this.onTheme});
  final bool dark;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/branding/pixelsaz_icon.jpg',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppConstants.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
                ),
                Text(
                  'ابزار تخصصی تصاویر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: IconButton(
              tooltip: dark ? 'حالت روشن' : 'حالت تاریک',
              onPressed: onTheme,
              constraints: const BoxConstraints.tightFor(width: 46, height: 46),
              icon: Icon(
                dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: theme.colorScheme.onSurface,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.supporting, this.action, this.onAction});
  final String title;
  final String? supporting;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 23,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                action!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.oceanBlue,
                  fontSize: 11,
                ),
              ),
            )
          else if (supporting != null)
            Text(
              supporting!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Artwork never floats over text: the icon has its own flex column.
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.action,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String title;
  final String description;
  final String action;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = widget.primary;
    final foreground = primary ? Colors.white : theme.colorScheme.onSurface;
    final muted = primary ? const Color(0xFFE2EBFF) : theme.colorScheme.onSurfaceVariant;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: primary
          ? const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[Color(0xFF3276FA), Color(0xFF2563EB), Color(0xFF1B48BB)],
            )
          : LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const <Color>[Color(0xFF1E2B4B), Color(0xFF18233F)]
                  : const <Color>[Color(0xFFFFFFFF), Color(0xFFF0F3FE)],
            ),
      border: Border.all(
        color: primary ? const Color(0x4DFFFFFF) : theme.colorScheme.outlineVariant,
        width: 1,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: primary
              ? const Color(0x243766CA)
              : Colors.black.withAlpha(dark ? 15 : 6),
          offset: const Offset(0, 7),
          blurRadius: primary ? 20 : 15,
          spreadRadius: -5,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, bounds) {
        final short = bounds.maxHeight < 151;
        final tiny = bounds.maxHeight < 120;
        final iconSize = (bounds.maxWidth < 355 ? 64.0 : 78.0)
            .clamp(54.0, bounds.maxHeight * 0.58)
            .toDouble();
        return Semantics(
          button: true,
          label: widget.title,
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1,
            duration: const Duration(milliseconds: 125),
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              child: DecoratedBox(
                decoration: decoration,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: short ? 15 : 19, vertical: tiny ? 10 : 13),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: foreground,
                                fontSize: short ? 15.5 : 17.5,
                                height: 1.35,
                              ),
                            ),
                            if (!tiny) ...<Widget>[
                              SizedBox(height: short ? 3 : 7),
                              Text(
                                widget.description,
                                maxLines: short ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                  fontSize: 11.5,
                                  height: 1.55,
                                ),
                              ),
                            ],
                            SizedBox(height: tiny ? 4 : (short ? 5 : 10)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  widget.action,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: primary ? Colors.white : AppColors.oceanBlue,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 15,
                                  color: primary ? const Color(0xFFD9EAFF) : AppColors.oceanBlue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: primary
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[Color(0xFF9CD8FF), Color(0xFF64A3FF), Color(0xFF3B72E1)],
                                )
                              : LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: dark
                                      ? const <Color>[Color(0xFF594C98), Color(0xFF314A80)]
                                      : const <Color>[Color(0xFFE3E3FF), Color(0xFFDBEDFF)],
                                ),
                          border: Border.all(
                            color: primary
                                ? const Color(0x66FFFFFF)
                                : (dark ? const Color(0xFF655F9C) : const Color(0xFFD9E2FA)),
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Color(0x190B2461), offset: Offset(0, 6), blurRadius: 13),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          size: iconSize * 0.48,
                          color: primary
                              ? Colors.white
                              : (dark ? const Color(0xFFE1DCFF) : AppColors.violet),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.batch, required this.dark, required this.onTap});
  final BatchConversionState batch;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = batch.isProcessing
        ? 'در حال پردازش تصاویر'
        : batch.hasResults
            ? '${batch.successfulCount} تصویر آماده شد'
            : 'هنوز پردازشی ثبت نشده';
    final details = batch.isProcessing
        ? 'پیشرفت: ${(batch.overallProgress * 100).round()}٪'
        : batch.hasResults
            ? 'کاهش حجم: ${formatFileSize(batch.totalSavedBytes)}'
            : 'برای شروع، یکی از ابزارها را انتخاب کن';
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: <Widget>[
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF183A4C) : const Color(0xFFE8F8F8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  batch.isProcessing ? Icons.hourglass_top_rounded : Icons.history_rounded,
                  color: AppColors.aqua,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}