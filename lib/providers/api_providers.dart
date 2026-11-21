// Riverpod access to the server (docs/API_CONTRACT.md) and to customer login.
//
// Build flags:
//   --dart-define=FAKE_SERVER=true        in-app fake ShineStaff + test login
//                                         (OTP 123456); data kept on the phone
//   --dart-define=API_BASE_URL=https://…  the real ShineStaff (step 4)

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api.dart';
import '../data/api/fake/fake_api.dart';
import '../data/api/http_api.dart';
import '../data/api/models.dart';
import '../data/auth_service.dart';
import 'app_providers.dart';

const kFakeServer = bool.fromEnvironment('FAKE_SERVER');
const kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

const _fakeStateKey = 'fake_server_v1';

/// The single fake server of a test build. Its state is saved on the phone
/// after every change, so bookings survive an app restart.
final fakeApiProvider = Provider<FakeApi>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final api = FakeApi();
  final saved = prefs.getString(_fakeStateKey);
  if (saved != null) {
    try {
      api.restore(Map<String, dynamic>.from(jsonDecode(saved) as Map));
    } on Object {
      // A state from an older build: start fresh rather than crash.
    }
  }
  api.onChange = () => prefs.setString(_fakeStateKey, jsonEncode(api.toJson()));
  return api;
});

final apiProvider = Provider<CleanCruisersApi>((ref) {
  if (kFakeServer) return ref.watch(fakeApiProvider);
  return HttpApi(kApiBaseUrl);
});

/// Customer login: the fake OTP in test builds, Firebase otherwise.
final authServiceProvider = Provider<AuthService>((ref) {
  if (kFakeServer) {
    return FakeAuthService(ref.watch(fakeApiProvider), ref.watch(sharedPrefsProvider));
  }
  return FirebaseAuthService();
});

final apiConfigProvider = FutureProvider<ApiConfig>((ref) => ref.watch(apiProvider).config());

final catalogProvider = FutureProvider<Catalog>((ref) => ref.watch(apiProvider).catalog());

final publicOffersProvider =
    FutureProvider<List<PublicOffer>>((ref) => ref.watch(apiProvider).offers());

/// Do we serve this spot? (contract `GET /coverage`), keyed by
/// [coverageKey]. Uses the map pin, or a pincode in the address line.
final coverageProvider =
    FutureProvider.autoDispose.family<Coverage, String>((ref, key) async {
  final i = key.indexOf('|');
  final line = key.substring(0, i), pin = key.substring(i + 1);
  final ll = pin.split(',');
  final lat = ll.length == 2 ? double.tryParse(ll[0]) : null;
  final lng = ll.length == 2 ? double.tryParse(ll[1]) : null;
  final pincode = RegExp(r'\b\d{6}\b').firstMatch(line)?.group(0);
  if (lat == null && pincode == null) return Coverage.unverified;
  final r = await ref
      .watch(apiProvider)
      .coverage(lat: lat, lng: lng, pincode: pincode);
  return r.coverage;
});

String coverageKey(String line, String? pin) => '$line|${pin ?? ''}';

/// The signed-in customer. Invalidate after login, logout or profile edits.
final meProvider = FutureProvider<Me>((ref) => ref.watch(apiProvider).me());
