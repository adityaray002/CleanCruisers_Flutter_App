// Customer login by phone OTP.
//
// - FirebaseAuthService: real SMS OTP through Firebase Auth (production).
//   Firebase is used only for login; bookings go to ShineStaff through the
//   API (docs/API_CONTRACT.md), which checks the Firebase ID token.
// - FakeAuthService: test builds (--dart-define=FAKE_SERVER=true). Any
//   10-digit mobile number works and the OTP is always 123456, so the whole
//   sign-up can be tried on a phone without Firebase. The login is kept
//   across app restarts.
// - DevAuthService: the real ShineStaff server without Firebase
//   (--dart-define=API_BASE_URL=… --dart-define=DEV_LOGIN=true). Any number,
//   OTP 123456, and the server must run with APP_AUTH_DEV=true, which
//   ShineStaff refuses in production. For testing on a local or staging server.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'api/fake/fake_api.dart';

/// A login problem, worded for the customer.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// An OTP on its way to [phone] (10 digits, no +91).
class OtpSession {
  final String phone;
  final String? verificationId;
  final int? resendToken;
  final ConfirmationResult? web;

  /// Android read the SMS itself; the customer is already signed in.
  final bool autoVerified;
  const OtpSession({
    required this.phone,
    this.verificationId,
    this.resendToken,
    this.web,
    this.autoVerified = false,
  });
}

abstract class AuthService {
  /// OTP login works in this build.
  bool get available;

  /// Test build with the fake server (shows test hints and Test tools).
  bool get isTestBuild;

  bool get signedIn;

  /// Verified number, 10 digits without +91.
  String? get phone;

  /// Name saved at sign-up, or null if sign-up isn't finished.
  String? get name;

  /// Fires on sign-in, sign-out and name changes.
  Stream<void> get changes;

  Future<OtpSession> sendOtp(String phone, {OtpSession? resend});
  Future<void> verifyOtp(OtpSession session, String code);
  Future<void> saveName(String name);
  Future<void> signOut();

  /// The token the server checks on every call (contract §1), or null.
  /// [refresh]: the server refused the last one, get a fresh token.
  Future<String?> idToken({bool refresh = false});
}

class FirebaseAuthService implements AuthService {
  bool get _configured => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? get _user => _configured ? _auth.currentUser : null;

  @override
  bool get available => _configured;
  @override
  bool get isTestBuild => false;
  @override
  bool get signedIn => _user?.phoneNumber?.isNotEmpty ?? false;

  @override
  String? get phone {
    final p = _user?.phoneNumber;
    if (p == null || p.isEmpty) return null;
    return p.startsWith('+91') ? p.substring(3) : p;
  }

  @override
  String? get name {
    final n = _user?.displayName?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  @override
  Stream<void> get changes =>
      _configured ? _auth.userChanges().map((_) {}) : const Stream.empty();

  @override
  Future<OtpSession> sendOtp(String phone, {OtpSession? resend}) async {
    if (!_configured) {
      throw const AuthException('Login isn\'t set up in this build yet.');
    }
    final number = '+91$phone';
    try {
      if (kIsWeb) {
        final result = await _auth.signInWithPhoneNumber(number);
        return OtpSession(phone: phone, web: result);
      }
      final done = Completer<OtpSession>();
      await _auth.verifyPhoneNumber(
        phoneNumber: number,
        forceResendingToken: resend?.resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (!done.isCompleted) {
              done.complete(OtpSession(phone: phone, autoVerified: true));
            }
          } on Object catch (e) {
            if (!done.isCompleted) done.completeError(_error(e));
          }
        },
        verificationFailed: (e) {
          if (!done.isCompleted) done.completeError(_error(e));
        },
        codeSent: (id, token) {
          if (!done.isCompleted) {
            done.complete(OtpSession(
                phone: phone, verificationId: id, resendToken: token));
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return await done.future;
    } on AuthException {
      rethrow;
    } on Object catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<void> verifyOtp(OtpSession session, String code) async {
    try {
      if (session.web != null) {
        await session.web!.confirm(code);
      } else if (session.verificationId != null) {
        await _auth.signInWithCredential(PhoneAuthProvider.credential(
            verificationId: session.verificationId!, smsCode: code));
      }
    } on Object catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<void> saveName(String name) async {
    final user = _user;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await user.reload();
  }

  @override
  Future<void> signOut() async {
    if (_configured) await _auth.signOut();
  }

  @override
  Future<String?> idToken({bool refresh = false}) async => _user?.getIdToken(refresh);

  AuthException _error(Object e) {
    final code = e is FirebaseAuthException ? e.code : '';
    return AuthException(switch (code) {
      'invalid-phone-number' => "That mobile number doesn't look right.",
      'invalid-verification-code' =>
        'That OTP is incorrect. Please check and try again.',
      'session-expired' ||
      'code-expired' =>
        'This OTP has expired. Tap "Resend OTP" for a new one.',
      'too-many-requests' ||
      'quota-exceeded' =>
        'Too many attempts. Please wait a few minutes and try again.',
      'operation-not-allowed' =>
        "Phone login isn't switched on yet. Please chat with us on WhatsApp.",
      'network-request-failed' =>
        'No internet connection. Please check and try again.',
      _ => "We couldn't verify your number. Please try again.",
    });
  }
}

class FakeAuthService implements AuthService {
  static const _key = 'fake_auth_phone';
  final FakeApi api;
  final SharedPreferences prefs;
  final _changes = StreamController<void>.broadcast();

  FakeAuthService(this.api, this.prefs) {
    final saved = prefs.getString(_key);
    if (saved != null && api.signedInPhone != saved) api.signIn(saved);
  }

  @override
  bool get available => true;
  @override
  bool get isTestBuild => true;
  @override
  bool get signedIn => api.signedInPhone != null;
  @override
  String? get phone => api.signedInPhone;
  @override
  String? get name => phone == null ? null : api.nameOf(phone!);
  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<OtpSession> sendOtp(String phone, {OtpSession? resend}) async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      throw const AuthException("That mobile number doesn't look right.");
    }
    return OtpSession(phone: phone, verificationId: 'fake-$phone');
  }

  @override
  Future<void> verifyOtp(OtpSession session, String code) async {
    if (code != FakeApi.fakeOtp) {
      throw const AuthException('That OTP is incorrect. Please check and try again.');
    }
    api.signIn(session.phone);
    await prefs.setString(_key, session.phone);
    _changes.add(null);
  }

  @override
  Future<void> saveName(String name) async {
    await api.updateMe(name: name);
    _changes.add(null);
  }

  @override
  Future<void> signOut() async {
    api.signOut();
    await prefs.remove(_key);
    _changes.add(null);
  }

  @override
  Future<String?> idToken({bool refresh = false}) async => phone == null ? null : 'fake-token-$phone';

  /// Test tools: wipe the fake server and log out.
  Future<void> resetTestData() async {
    api.adminReset();
    await prefs.remove(_key);
    _changes.add(null);
  }
}

/// Dev login against a real ShineStaff server (see the file comment).
class DevAuthService implements AuthService {
  static const otp = '123456';
  static const _phoneKey = 'dev_auth_phone';
  static const _nameKey = 'dev_auth_name';
  final SharedPreferences prefs;

  /// Sends the name to the server (PUT /me); set by the provider.
  final Future<void> Function(String name) pushName;
  final _changes = StreamController<void>.broadcast();

  DevAuthService(this.prefs, {required this.pushName});

  @override
  bool get available => true;
  @override
  bool get isTestBuild => true;
  @override
  bool get signedIn => phone != null;
  @override
  String? get phone => prefs.getString(_phoneKey);
  @override
  String? get name => prefs.getString(_nameKey);
  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<OtpSession> sendOtp(String phone, {OtpSession? resend}) async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      throw const AuthException("That mobile number doesn't look right.");
    }
    return OtpSession(phone: phone, verificationId: 'dev-$phone');
  }

  @override
  Future<void> verifyOtp(OtpSession session, String code) async {
    if (code != otp) {
      throw const AuthException('That OTP is incorrect. Please check and try again.');
    }
    await prefs.setString(_phoneKey, session.phone);
    await prefs.remove(_nameKey);
    _changes.add(null);
  }

  @override
  Future<void> saveName(String name) async {
    await pushName(name.trim());
    await prefs.setString(_nameKey, name.trim());
    _changes.add(null);
  }

  @override
  Future<void> signOut() async {
    await prefs.remove(_phoneKey);
    await prefs.remove(_nameKey);
    _changes.add(null);
  }

  @override
  Future<String?> idToken({bool refresh = false}) async => phone == null ? null : 'dev:$phone';
}
