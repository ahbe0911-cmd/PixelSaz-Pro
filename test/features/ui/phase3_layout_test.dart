import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/core/theme/app_theme.dart';
import 'package:pixelsaz_pro/features/batch_converter/presentation/pages/batch_converter_page.dart';
import 'package:pixelsaz_pro/features/id_photo/presentation/pages/id_photo_studio_page.dart';

void main() {
  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('batch converter keeps target sizes and conversion action visible', (tester) async {
    setViewport(tester, const Size(360, 760));
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(theme: AppTheme.light, home: const BatchConverterPage())),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('target-presets')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('open-gallery')), findsOneWidget);
    expect(find.text('ابتدا عکس انتخاب کنید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ID studio offers three presets and two permanent actions', (tester) async {
    setViewport(tester, const Size(360, 760));
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(theme: AppTheme.light, home: const IdPhotoStudioPage())),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('id-spec-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('quality-print')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('quality-200')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('quality-495')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('id-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('id-gallery')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ID studio allows scrolling on tiny screens instead of clipping', (tester) async {
    setViewport(tester, const Size(320, 440));
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(theme: AppTheme.dark, home: const IdPhotoStudioPage())),
    );
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('id-camera')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}