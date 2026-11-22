import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/core/theme/app_colors.dart';
import 'package:pixelsaz_pro/core/theme/app_theme.dart';
import 'package:pixelsaz_pro/features/home/presentation/pages/home_page.dart';

void main() {
  test('both themes use offline Vazirmatn and the correct palette', () {
    expect(AppTheme.fontFamily, 'Vazirmatn');
    expect(AppTheme.dark.textTheme.bodyLarge?.fontFamily, 'Vazirmatn');
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Vazirmatn');
    expect(AppTheme.dark.textTheme.titleLarge?.fontFamily, 'Vazirmatn');
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(AppTheme.light.colorScheme.primary, AppColors.oceanBlue);
  });

  testWidgets('main tools and recent activity fit without scrolling on phone', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    expect(find.text('ابزارهای شما'), findsOneWidget);
    expect(find.text('آخرین فعالیت‌ها'), findsOneWidget);
    expect(find.text('استودیو عکس پرسنلی ۳×۴'), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('very short screens scroll instead of clipping controls', (tester) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const HomePage()),
      ),
    );
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}