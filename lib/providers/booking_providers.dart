// The booking request flow, backed by the server (docs/API_CONTRACT.md §5).
//
// The draft only holds the customer's choices. Slots, the bill, coupons,
// credit and the "slot taken" answer all come from the server.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pricing.dart';
import '../data/api/models.dart';
import '../data/api/address_convert.dart';
import '../models/booking.dart' show CustomerProfile, newBookingRef;
import 'api_providers.dart';
import 'app_providers.dart';

/// What the customer has chosen so far.
class RequestDraft {
  /// Idempotency key: a retry reuses it, so a double tap or a lost answer
  /// never creates a second booking.
  final String clientRef;
  final String serviceId;
  final CarType? car;
  final String carModel;
  final Map<String, int> extras; // extra id → qty
  final DateTime? date;
  final int? start; // minutes after midnight
  final String? couponCode;
  final bool useCredit;

  /// A visit of the customer's monthly plan (the service part is paid).
  final String? planId;

  const RequestDraft({
    required this.clientRef,
    required this.serviceId,
    this.car,
    this.carModel = '',
    this.extras = const {},
    this.date,
    this.start,
    this.couponCode,
    this.useCredit = true,
    this.planId,
  });

  RequestDraft copyWith({
    CarType? car,
    String? carModel,
    Map<String, int>? extras,
    DateTime? date,
    int? start,
    bool clearStart = false,
    String? couponCode,
    bool clearCoupon = false,
    bool? useCredit,
    String? planId,
  }) =>
      RequestDraft(
        clientRef: clientRef,
        serviceId: serviceId,
        car: car ?? this.car,
        carModel: carModel ?? this.carModel,
        extras: extras ?? this.extras,
        date: date ?? this.date,
        start: clearStart ? null : (start ?? this.start),
        couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
        useCredit: useCredit ?? this.useCredit,
        planId: planId ?? this.planId,
      );

  bool get timePicked => date != null && start != null;
  ApiCar? get apiCar => car == null ? null : ApiCar(car!, carModel);

  /// `seat:2,ac:1`, sorted, for provider keys.
  String get extrasKey =>
      (extras.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => '${e.key}:${e.value}')
          .join(',');

  /// The request for `/quote` and `/bookings`, or null while something is
  /// missing.
  BookingRequest? request(ApiAddress? address) {
    final c = apiCar;
    if (c == null || !timePicked || address == null) return null;
    return BookingRequest(
      serviceId: serviceId,
      car: c,
      extras: extras,
      slot: SlotPick(date!, start!),
      address: address,
      couponCode: planId == null ? couponCode : null,
      useCredit: planId == null && useCredit,
      planId: planId,
    );
  }
}

class RequestDraftNotifier extends StateNotifier<RequestDraft> {
  RequestDraftNotifier(super.initial);

  void setCar(CarType car, String model) =>
      state = state.copyWith(car: car, carModel: model, clearStart: car != state.car);

  void setExtra(String id, int qty) {
    final m = Map<String, int>.from(state.extras);
    if (qty <= 0) {
      m.remove(id);
    } else {
      m[id] = qty;
    }
    // A longer job may not fit the start time picked before.
    state = state.copyWith(extras: m, clearStart: true);
  }

  void clearExtras() => state = state.copyWith(extras: const {}, clearStart: true);

  void setDate(DateTime d) => state = state.copyWith(date: d, clearStart: true);
  void setTime(DateTime d, int start) => state = state.copyWith(date: d, start: start);
  void setCoupon(String? code) => state =
      code == null ? state.copyWith(clearCoupon: true) : state.copyWith(couponCode: code);
  void setUseCredit(bool use) => state = state.copyWith(useCredit: use);
  void setPlan(String planId) => state = state.copyWith(planId: planId);
}

/// One draft per service, pre-filled with the customer's car.
final requestDraftProvider = StateNotifierProvider.autoDispose
    .family<RequestDraftNotifier, RequestDraft, String>((ref, serviceId) {
  final p = ref.read(profileProvider);
  return RequestDraftNotifier(RequestDraft(
    clientRef: newBookingRef(),
    serviceId: serviceId,
    car: p.car,
    carModel: p.carModel,
  ));
});

/// Where the car is (the selected saved address), as the server wants it.
ApiAddress? apiAddressOf(CustomerProfile p) =>
    apiAddressFromLine(p.address, p.pin);

typedef AvailabilityKey = (String serviceId, CarType car, String extras, String date);

/// Start times for one day (contract `GET /availability`).
final availabilityProvider =
    FutureProvider.autoDispose.family<Availability, AvailabilityKey>((ref, k) {
  final (serviceId, car, extras, date) = k;
  return ref.watch(apiProvider).availability(
        serviceId: serviceId,
        car: ApiCar(car),
        extras: {
          for (final e in extras.split(',').where((s) => s.isNotEmpty))
            e.split(':')[0]: int.parse(e.split(':')[1]),
        },
        date: parseDateKey(date),
      );
});

/// The server's bill for a request (contract `POST /quote`). Keyed by the
/// request's JSON so any change asks again.
final quoteProvider = FutureProvider.autoDispose.family<Quote, String>((ref, json) {
  final r = BookingRequest.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
  return ref.watch(apiProvider).quote(r);
});

String quoteKey(BookingRequest r) => jsonEncode(r.toJson());

/// How often an open bookings screen asks the server again (contract §5).
const kBookingsRefresh = Duration(seconds: 30);

/// One booking from the server (contract `GET /bookings/{ref}`). Screens
/// that show it wrap themselves in [AutoRefresh].
final apiBookingProvider =
    FutureProvider.autoDispose.family<Booking, String>((ref, bookingRef) =>
        ref.watch(apiProvider).booking(bookingRef));

class MyBookings {
  final List<Booking> upcoming, past;
  const MyBookings(this.upcoming, this.past);
  static const none = MyBookings([], []);
  bool get isEmpty => upcoming.isEmpty && past.isEmpty;
}

/// The customer's monthly plans (contract §8).
final myPlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  if (!ref.watch(authServiceProvider).signedIn) return const [];
  return ref.watch(apiProvider).plans();
});

/// The signed-in customer's bookings (contract `GET /bookings`). Logged
/// out, or a build without a server: none. The shell refreshes it every
/// [kBookingsRefresh] (see [AutoRefresh]).
final myApiBookingsProvider = FutureProvider.autoDispose<MyBookings>((ref) async {
  if (!ref.watch(authServiceProvider).signedIn) return MyBookings.none;
  final api = ref.watch(apiProvider);
  try {
    return MyBookings(
        await api.bookings(upcoming: true), await api.bookings(upcoming: false));
  } on ApiException catch (e) {
    if (e.code == ApiCode.authRequired) return MyBookings.none;
    rethrow;
  }
});

/// Asks the server again every [kBookingsRefresh] while [child] is on
/// screen (the timer stops with the screen). [onTick] says what to reload.
class AutoRefresh extends ConsumerStatefulWidget {
  final void Function(WidgetRef ref) onTick;
  final Widget child;
  const AutoRefresh({super.key, required this.onTick, required this.child});

  @override
  ConsumerState<AutoRefresh> createState() => _AutoRefreshState();
}

class _AutoRefreshState extends ConsumerState<AutoRefresh> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(kBookingsRefresh, (_) {
      if (mounted) widget.onTick(ref);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// After any change to [bookingRef]: show the new state everywhere.
void refreshBooking(WidgetRef ref, String bookingRef) {
  ref.invalidate(apiBookingProvider(bookingRef));
  ref.invalidate(myApiBookingsProvider);
  ref.invalidate(myPlansProvider);
  ref.invalidate(meProvider);
}
