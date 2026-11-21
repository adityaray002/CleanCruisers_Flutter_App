// Customer login by phone OTP.
//
// - FirebaseAuthService: real SMS OTP through Firebase (production).
// - FakeAuthService: test builds (--dart-define=FAKE_SERVER=true). Any
//   10-digit mobile number works and the OTP is always 123456, so the whole
//   sign-up can be tried on a phone without Firebase. The login is kept
//   across app restarts.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'api/fake/fake_api.dart';
import 'booking_cloud.dart';

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
}

class FirebaseAuthService implements AuthService {
  final BookingCloud cloud;
  FirebaseAuthService(this.cloud);

  @override
  bool get available => cloud.configured;
  @override
  bool get isTestBuild => false;
  @override
  bool get signedIn => cloud.customerSignedIn;
  @override
  String? get phone => cloud.verifiedPhone;
  @override
  String? get name => cloud.customerName;
  @override
  Stream<void> get changes => cloud.userChanges().map((_) {});
  @override
  Future<OtpSession> sendOtp(String phone, {OtpSession? resend}) =>
      cloud.sendOtp(phone, resend: resend);
  @override
  Future<void> verifyOtp(OtpSession session, String code) => cloud.verifyOtp(session, code);
  @override
  Future<void> saveName(String name) => cloud.saveCustomerName(name);
  @override
  Future<void> signOut() => cloud.signOutCustomer();
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
      throw const BookingCloudException("That mobile number doesn't look right.");
    }
    return OtpSession(phone: phone, verificationId: 'fake-$phone');
  }

  @override
  Future<void> verifyOtp(OtpSession session, String code) async {
    if (code != FakeApi.fakeOtp) {
      throw const BookingCloudException('That OTP is incorrect. Please check and try again.');
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

  /// Test tools: wipe the fake server and log out.
  Future<void> resetTestData() async {
    api.adminReset();
    await prefs.remove(_key);
    _changes.add(null);
  }
}
