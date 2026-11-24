import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Runtime Firebase configuration supplied with --dart-define values.
/// This keeps project keys out of source control and makes an unconfigured
/// build fail closed with a clear in-app message.
class CleanCruisersFirebaseOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _macosAppId = String.fromEnvironment('FIREBASE_MACOS_APP_ID');

  static FirebaseOptions? get current {
    if (_apiKey.isEmpty || _projectId.isEmpty || _messagingSenderId.isEmpty) {
      return null;
    }
    final appId = kIsWeb
        ? _webAppId
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => _androidAppId,
            TargetPlatform.iOS => _iosAppId,
            TargetPlatform.macOS => _macosAppId,
            _ => '',
          };
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
    );
  }
}
