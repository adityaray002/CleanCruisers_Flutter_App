import 'package:cleancruisers_app/core/router.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late GoRouter router;
  late bool appClosed;

  // Home has looping animations, so pumpAndSettle would never return.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appClosed = false;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') appClosed = true;
      return null;
    });
    final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    router = container.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    router.go('/home');
    await settle(tester);
  }

  String location() => router.routerDelegate.currentConfiguration.uri.path;

  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  testWidgets('back on a tab returns to Home instead of closing the app',
      (tester) async {
    await pumpApp(tester);
    for (final tab in ['/services', '/bookings', '/profile']) {
      router.go(tab);
      await settle(tester);
      await pressBack(tester);
      expect(location(), '/home', reason: 'back from $tab');
      expect(appClosed, isFalse, reason: 'back from $tab');
    }
  });

  testWidgets('back on Home closes the app', (tester) async {
    await pumpApp(tester);
    await pressBack(tester);
    expect(appClosed, isTrue);
  });

  testWidgets('back on a pushed screen returns to the tab it came from',
      (tester) async {
    await pumpApp(tester);
    router.go('/services');
    await settle(tester);
    router.push('/service/wash-full');
    await settle(tester);
    await pressBack(tester);
    expect(location(), '/services');
    expect(appClosed, isFalse);
  });
}
