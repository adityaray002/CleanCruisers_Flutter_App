// The real ShineStaff client (docs/API_CONTRACT.md, v1).
//
// - Every call except section 3 carries `Authorization: Bearer <token>`; the
//   token comes from the login (Firebase ID token, or `dev:<phone>` in a dev
//   build). On AUTH_REQUIRED the token is refreshed once and the call retried.
// - Errors come back as ApiException with the contract code. No network or a
//   server problem is UNAVAILABLE with a message the customer can read.
// - Times: the server sends IST timestamps with +05:30. The app works in IST
//   wall-clock time (like the fake server), so the offset is dropped before
//   parsing: 10:00+05:30 is read as 10:00 on any phone.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api.dart';
import 'models.dart';

/// Gets the login token for the server; [refresh] asks for a fresh one.
typedef TokenSource = Future<String?> Function({bool refresh});

class HttpApi implements CleanCruisersApi {
  final String baseUrl;
  final TokenSource token;
  final http.Client _client;
  final Duration timeout;

  HttpApi(String baseUrl, {required this.token, http.Client? client, this.timeout = const Duration(seconds: 20)})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  // ── Transport ───────────────────────────────────────────────────────────────

  static final _istStamp = RegExp(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?)\+05:30$');

  /// Drops the IST offset from every timestamp in [j] (see the file comment).
  static Object? istLocal(Object? j) {
    if (j is String) {
      final m = _istStamp.firstMatch(j);
      return m == null ? j : m.group(1);
    }
    if (j is List) return [for (final e in j) istLocal(e)];
    if (j is Map) return {for (final e in j.entries) e.key as String: istLocal(e.value)};
    return j;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final q = query == null ? null : {for (final e in query.entries) if (e.value.isNotEmpty) e.key: e.value};
    return Uri.parse('$baseUrl$path').replace(queryParameters: q == null || q.isEmpty ? null : q);
  }

  static const _offline =
      ApiException(ApiCode.unavailable, "Couldn't reach CleanCruisers. Check your internet and try again.");

  Future<Map<String, dynamic>> _call(String method, String path,
      {Object? body, Map<String, String>? query, bool auth = true}) async {
    if (baseUrl.isEmpty) {
      // A build made without --dart-define=API_BASE_URL.
      throw const ApiException(ApiCode.unavailable, 'This version of the app is not set up yet. Please update it.');
    }
    Future<http.Response> send({bool refresh = false}) async {
      final headers = <String, String>{'Accept': 'application/json'};
      if (body != null) headers['Content-Type'] = 'application/json';
      if (auth) {
        final t = await token(refresh: refresh);
        if (t == null || t.isEmpty) {
          throw const ApiException(ApiCode.authRequired, 'Please log in again.');
        }
        headers['Authorization'] = 'Bearer $t';
      }
      final req = http.Request(method, _uri(path, query))..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      try {
        return await http.Response.fromStream(await _client.send(req).timeout(timeout));
      } on TimeoutException {
        throw _offline;
      } on http.ClientException {
        throw _offline;
      } on ApiException {
        rethrow;
      } on Exception {
        throw _offline; // SocketException on mobile, XMLHttpRequest errors on web
      }
    }

    var res = await send();
    if (res.statusCode == 401 && auth) res = await send(refresh: true);

    Object? decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final j = istLocal(decoded);
      return j is Map<String, dynamic> ? j : <String, dynamic>{};
    }
    if (decoded is Map && decoded['error'] is Map) {
      throw ApiException.fromJson(Map<String, dynamic>.from(istLocal(decoded)! as Map));
    }
    if (res.statusCode == 429) {
      throw const ApiException(ApiCode.tooManyRequests, 'Too many tries. Please wait a moment and try again.');
    }
    throw const ApiException(ApiCode.unavailable, 'Something went wrong. Please try again.');
  }

  Map<String, dynamic> _m(Object? v) => Map<String, dynamic>.from(v as Map);

  // ── Public (section 3) ──────────────────────────────────────────────────────

  @override
  Future<ApiConfig> config() async => ApiConfig.fromJson(await _call('GET', '/config', auth: false));

  @override
  Future<Catalog> catalog() async => Catalog.fromJson(await _call('GET', '/catalog', auth: false));

  @override
  Future<List<PublicOffer>> offers() async {
    final j = await _call('GET', '/offers', auth: false);
    return [for (final o in j['offers'] as List? ?? const []) PublicOffer.fromJson(_m(o))];
  }

  @override
  Future<({Coverage coverage, String? areaName})> coverage({double? lat, double? lng, String? pincode}) async {
    final j = await _call('GET', '/coverage', auth: false, query: {
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (pincode != null) 'pincode': pincode,
    });
    return (coverage: coverageFrom(j['coverage'] as String?), areaName: j['areaName'] as String?);
  }

  // ── Profile (section 4) ─────────────────────────────────────────────────────

  @override
  Future<Me> me() async => Me.fromJson(await _call('GET', '/me'));

  @override
  Future<Me> updateMe({String? name, ApiCar? car, String? referralCode}) async =>
      Me.fromJson(await _call('PUT', '/me', body: {
        if (name != null) 'name': name,
        if (car != null) 'car': car.toJson(),
        if (referralCode != null) 'referralCode': referralCode,
      }));

  @override
  Future<List<ApiAddress>> addresses() async {
    final j = await _call('GET', '/addresses');
    return [for (final a in j['addresses'] as List? ?? const []) ApiAddress.fromJson(_m(a))];
  }

  @override
  Future<ApiAddress> addAddress(ApiAddress address) async =>
      ApiAddress.fromJson(await _call('POST', '/addresses', body: address.toJson()));

  @override
  Future<ApiAddress> updateAddress(ApiAddress address) async =>
      ApiAddress.fromJson(await _call('PUT', '/addresses/${Uri.encodeComponent(address.id!)}', body: address.toJson()));

  @override
  Future<void> deleteAddress(String id) async {
    await _call('DELETE', '/addresses/${Uri.encodeComponent(id)}');
  }

  // ── Booking (section 5) ─────────────────────────────────────────────────────

  @override
  Future<Availability> availability({
    required String serviceId,
    required ApiCar car,
    Map<String, int> extras = const {},
    required DateTime date,
    double? lat,
    double? lng,
    String? planId,
  }) async =>
      Availability.fromJson(await _call('GET', '/availability', query: {
        'serviceId': serviceId,
        'car': car.type.name,
        'extras': [for (final e in extras.entries) '${e.key}:${e.value}'].join(','),
        'date': dateKey(date),
        if (lat != null) 'lat': '$lat',
        if (lng != null) 'lng': '$lng',
        if (planId != null) 'planId': planId,
      }));

  @override
  Future<Quote> quote(BookingRequest request) async =>
      Quote.fromJson(_m((await _call('POST', '/quote', body: request.toJson()))['quote']));

  @override
  Future<Booking> createBooking(BookingRequest request) async => _booking(await _call('POST', '/bookings', body: request.toJson()));

  @override
  Future<List<Booking>> bookings({required bool upcoming}) async {
    final j = await _call('GET', '/bookings', query: {'scope': upcoming ? 'upcoming' : 'past'});
    return [for (final b in j['bookings'] as List? ?? const []) Booking.fromJson(_m(b))];
  }

  @override
  Future<Booking> booking(String ref) async => _booking(await _call('GET', '/bookings/${Uri.encodeComponent(ref)}'));

  Booking _booking(Map<String, dynamic> j) => Booking.fromJson(_m(j['booking']));

  Future<Booking> _action(String ref, String what, [Object? body]) async =>
      _booking(await _call('POST', '/bookings/${Uri.encodeComponent(ref)}/$what', body: body ?? const <String, dynamic>{}));

  // ── After booking (section 6) ───────────────────────────────────────────────

  @override
  Future<Booking> cancel(String ref, {String? reason}) => _action(ref, 'cancel', {'reason': reason});

  @override
  Future<Booking> changeTime(String ref, SlotPick slot) => _action(ref, 'change-time', {'slot': slot.toJson()});

  @override
  Future<Booking> acceptOffer(String ref) => _action(ref, 'offer/accept');

  @override
  Future<Booking> declineOffer(String ref) => _action(ref, 'offer/decline');

  @override
  Future<Booking> keepAsPlanned(String ref) => _action(ref, 'keep-as-planned');

  @override
  Future<Booking> acceptChange(String ref, String changeId) =>
      _action(ref, 'changes/${Uri.encodeComponent(changeId)}/accept');

  @override
  Future<Booking> rejectChange(String ref, String changeId) =>
      _action(ref, 'changes/${Uri.encodeComponent(changeId)}/reject');

  @override
  Future<InvoiceRef> invoice(String ref) async =>
      InvoiceRef.fromJson(await _call('GET', '/bookings/${Uri.encodeComponent(ref)}/invoice'));

  // ── Wallet, plans, referral (sections 7–9) ─────────────────────────────────

  @override
  Future<Wallet> wallet() async => Wallet.fromJson(await _call('GET', '/wallet'));

  @override
  Future<List<Plan>> plans() async {
    final j = await _call('GET', '/plans');
    return [for (final p in j['plans'] as List? ?? const []) Plan.fromJson(_m(p))];
  }

  @override
  Future<({Plan plan, Booking booking})> buyPlan({
    required String clientRef,
    required String planId,
    required ApiCar car,
    required String addressId,
    required SlotPick firstVisit,
  }) async {
    final j = await _call('POST', '/plans', body: {
      'clientRef': clientRef,
      'planId': planId,
      'car': car.toJson(),
      'addressId': addressId,
      'firstVisit': firstVisit.toJson(),
    });
    return (plan: Plan.fromJson(_m(j['plan'])), booking: Booking.fromJson(_m(j['booking'])));
  }

  @override
  Future<Referral> referral() async => Referral.fromJson(await _call('GET', '/referral'));
}
