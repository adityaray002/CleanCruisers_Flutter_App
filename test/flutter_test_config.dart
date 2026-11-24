import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Runs before every test file: loads the Manrope family (all five weights,
/// as in pubspec.yaml) so tests lay text out with the real font. Widget
/// tests don't load pubspec fonts by themselves.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final manrope = FontLoader('Manrope');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final f = File('assets/google_fonts/Manrope-$w.ttf');
    manrope.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await manrope.load();
  await testMain();
}
