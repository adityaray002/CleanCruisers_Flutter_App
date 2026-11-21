// The app's only door to the server (docs/API_CONTRACT.md, v1).
//
// Two implementations:
// - FakeApi (lib/data/api/fake/): an in-app stand-in for ShineStaff, used in
//   test builds (--dart-define=FAKE_SERVER=true) and in tests.
// - HttpApi (lib/data/api/http_api.dart): the real ShineStaff server.
//
// Every method throws ApiException with a contract error code on failure.

import 'models.dart';

abstract class CleanCruisersApi {
  // ── Public (section 3) ──────────────────────────────────────────────────────
  Future<ApiConfig> config();
  Future<Catalog> catalog();
  Future<List<PublicOffer>> offers();
  Future<({Coverage coverage, String? areaName})> coverage(
      {double? lat, double? lng, String? pincode});

  // ── Profile (section 4) ─────────────────────────────────────────────────────
  Future<Me> me();
  Future<Me> updateMe({String? name, ApiCar? car, String? referralCode});
  Future<List<ApiAddress>> addresses();
  Future<ApiAddress> addAddress(ApiAddress address);
  Future<ApiAddress> updateAddress(ApiAddress address);
  Future<void> deleteAddress(String id);

  // ── Booking (section 5) ─────────────────────────────────────────────────────
  Future<Availability> availability({
    required String serviceId,
    required ApiCar car,
    Map<String, int> extras = const {},
    required DateTime date,
    double? lat,
    double? lng,
    String? planId,
  });
  Future<Quote> quote(BookingRequest request);
  Future<Booking> createBooking(BookingRequest request);
  Future<List<Booking>> bookings({required bool upcoming});
  Future<Booking> booking(String ref);

  // ── After booking (section 6) ───────────────────────────────────────────────
  Future<Booking> cancel(String ref, {String? reason});
  Future<Booking> changeTime(String ref, SlotPick slot);
  Future<Booking> acceptOffer(String ref);
  Future<Booking> declineOffer(String ref);
  Future<Booking> keepAsPlanned(String ref);
  Future<Booking> acceptChange(String ref, String changeId);
  Future<Booking> rejectChange(String ref, String changeId);
  Future<InvoiceRef> invoice(String ref);

  // ── Wallet, plans, referral (sections 7–9) ─────────────────────────────────
  Future<Wallet> wallet();
  Future<List<Plan>> plans();
  Future<({Plan plan, Booking booking})> buyPlan({
    required String clientRef,
    required String planId,
    required ApiCar car,
    required String addressId,
    required SlotPick firstVisit,
  });
  Future<Referral> referral();
}
