// Riverpod access to the server (docs/API_CONTRACT.md).
//
// Build flags:
//   --dart-define=FAKE_SERVER=true        in-app fake ShineStaff (test builds)
//   --dart-define=API_BASE_URL=https://…  the real ShineStaff (step 4)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api.dart';
import '../data/api/fake/fake_api.dart';
import '../data/api/http_api.dart';
import '../data/api/models.dart';

const kFakeServer = bool.fromEnvironment('FAKE_SERVER');
const kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// The single fake server instance of a test build (also used by the Test
/// tools screen to act as the admin).
final fakeApiProvider = Provider<FakeApi>((ref) => FakeApi());

final apiProvider = Provider<CleanCruisersApi>((ref) {
  if (kFakeServer || kApiBaseUrl.isEmpty) return ref.watch(fakeApiProvider);
  return HttpApi(kApiBaseUrl);
});

final apiConfigProvider = FutureProvider<ApiConfig>((ref) => ref.watch(apiProvider).config());

final catalogProvider = FutureProvider<Catalog>((ref) => ref.watch(apiProvider).catalog());

final publicOffersProvider =
    FutureProvider<List<PublicOffer>>((ref) => ref.watch(apiProvider).offers());

/// The signed-in customer. Invalidate after login, logout or profile edits.
final meProvider = FutureProvider<Me>((ref) => ref.watch(apiProvider).me());
