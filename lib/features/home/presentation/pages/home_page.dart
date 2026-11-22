import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../batch_converter/presentation/providers/batch_conversion_providers.dart';

const _ink = Color(0xFF17243B);
const _navy = Color(0xFF101D3C);
const _electric = Color(0xFF3976FF);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final batch = ref.watch(batchConversionControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.asset(
                        'assets/branding/pixelsaz_icon.jpg',
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(AppConstants.appName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.4,
                              )),
                          Text('استودیوی تخصصی تصویر',
                              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                        ],
                      ),
                    ),
                    Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: IconButton(
                        tooltip: dark ? 'حالت روشن' : 'حالت تاریک',
                        onPressed: () => ref.read(themeModeProvider.notifier).toggle(currentlyDark: dark),
                        icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            size: 21, color: textColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 33),
                Text('دقت بالا. بدون پیچیدگی.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      height: 1.45, fontWeight: FontWeight.w900,
                      color: textColor,
                    )),
                const SizedBox(height: 5),
                Text('برای هر تصویری، دقیقاً همان خروجی که نیاز داری.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                const SizedBox(height: 24),
                Text('ابزارهای حرفه‌ای',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _HeroTool(onTap: () => context.push('/batch')),
                const SizedBox(height: 12),
                _IdPhotoTool(onTap: () => context.push('/id-photo'), dark: dark),
                const SizedBox(height: 19),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const <Widget>[
                    _FeaturePill(icon: Icons.layers_outlined, label: 'تا ۵۰ تصویر'),
                    _FeaturePill(icon: Icons.speed_rounded, label: '۴۹۵ کیلوبایت'),
                    _FeaturePill(icon: Icons.high_quality_outlined, label: '۳۰۰ DPI'),
                  ],
                ),
                const SizedBox(height: 29),
                Row(
                  children: <Widget>[
                    Expanded(child: Text('آخرین فعالیت',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    if (batch.hasResults)
                      TextButton(
                        onPressed: () => context.push('/batch/results'),
                        child: const Text('مشاهده همه'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Material(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(145)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push(batch.hasResults ? '/batch/results' : '/batch'),
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: dark ? const Color(0xFF203758) : const Color(0xFFE9F1FF),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(Icons.history_rounded, color: _electric),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(batch.hasResults
                                    ? '${batch.successfulCount} تصویر آماده شد'
                                    : 'هنوز پردازشی ثبت نشده',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(batch.hasResults
                                    ? 'کاهش حجم: ${formatFileSize(batch.totalSavedBytes)}'
                                    : 'از تبدیل گروهی یا عکس پرسنلی شروع کن',
                                    style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_left_rounded, color: muted),
                        ],
                      ),
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

class _HeroTool extends StatelessWidget {
  const _HeroTool({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TactileCard(
      onTap: onTap,
      child: Container(
        height: 224,
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[_navy, Color(0xFF183562), Color(0xFF2455B7)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: -29, top: 26,
              child: Transform.rotate(
                angle: -.22,
                child: Container(
                  width: 130, height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF60DEEB), Color(0xFF5474FF)],
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x663AE0FF), blurRadius: 30),
                    ],
                  ),
                  child: const Icon(Icons.photo_library_rounded, size: 65, color: Colors.white),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withAlpha(45)),
                  ),
                  child: const Text('IMAGE LAB  ·  01',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.2,
                      fontWeight: FontWeight.w700, color: Color(0xFFDAEAFF))),
                ),
                const Spacer(),
                const Text('تبدیل و فشرده‌سازی',
                  style: TextStyle(fontSize: 21, color: Colors.white,
                    height: 1.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const SizedBox(
                  width: 225,
                  child: Text('تبدیل گروهی با کیفیت هوشمند و حجم دلخواه',
                    maxLines: 2,
                    style: TextStyle(color: Color(0xFFD6E6FF), fontSize: 12, height: 1.7)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('شروع تبدیل',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_back_rounded, size: 17, color: Color(0xFF9AEFFF)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IdPhotoTool extends StatelessWidget {
  const _IdPhotoTool({required this.onTap, required this.dark});
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TactileCard(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(150)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(19, 17, 6, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ID PHOTO  ·  02', style: TextStyle(
                      fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w800,
                      color: dark ? const Color(0xFF93ABFF) : const Color(0xFF516AE8),
                    )),
                    const Spacer(),
                    Text('عکس پرسنلی ۳×۴',
                      maxLines: 1, style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 3),
                    Text('برش دقیق، تنظیم زاویه و 300 DPI',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    const Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      Text('ساخت عکس', style: TextStyle(
                        fontWeight: FontWeight.w800, color: _electric, fontSize: 12)),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_back_rounded, color: _electric, size: 16),
                    ]),
                  ],
                ),
              ),
            ),
            Container(
              width: 95,
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: dark
                      ? const <Color>[Color(0xFF293F77), Color(0xFF1F2C54)]
                      : const <Color>[Color(0xFFEAE9FF), Color(0xFFD7ECFF)],
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                ),
              ),
              child: const Icon(Icons.portrait_rounded, size: 53, color: Color(0xFF5A6DEA)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(140)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(icon, size: 15, color: _electric),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    );
  }
}

class _TactileCard extends StatefulWidget {
  const _TactileCard({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<_TactileCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? .983 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: widget.child,
      ),
    );
  }
}
