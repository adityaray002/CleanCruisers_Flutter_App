// Dev tool: renders screens to PNG with real fonts for visual review.
// Run: flutter test test/screenshots/screens_dev.dart  (writes PNGs to $SHOTS_DIR)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cleancruisers_app/core/theme.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final shotsDir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';

/// Phone width and system font size to render at, e.g.
/// `--dart-define=WIDTH=360 --dart-define=TEXT_SCALE=1.15` for a small phone
/// with large text.
final shotWidth =
    double.parse(const String.fromEnvironment('WIDTH', defaultValue: '390'));
final shotTextScale = double.parse(
    const String.fromEnvironment('TEXT_SCALE', defaultValue: '1.0'));

Future<void> loadFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await loader.load();
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final f = File('assets/google_fonts/Manrope-$w.ttf');
    final l = FontLoader('Manrope_$w')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await l.load();
  }
}

Future<void> shoot(WidgetTester tester, String name, Widget screen,
    {Map<String, Object> prefs = const {},
    List<Override> overrides = const [],
    double height = 800,
    Future<void> Function(WidgetTester)? interact}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  tester.view.physicalSize = Size(shotWidth * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(p), ...overrides],
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(shotTextScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  ));
  await tester.runAsync(() async {
    await Future.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump(const Duration(seconds: 2));
  if (interact != null) await interact(tester);
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(shotsDir).createSync(recursive: true);
    File('$shotsDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
