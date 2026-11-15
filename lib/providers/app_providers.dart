import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart';
import '../data/booking_cloud.dart';
import '../models/address.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../models/wallet.dart';

/// Overridden in main() with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden');
});

final bookingCloudProvider = Provider<BookingCloud>((ref) => BookingCloud());

/// Admin-configured service areas; empty (coverage "unverified") when none
/// are set up or they can't be loaded.
final serviceAreasProvider = FutureProvider<List<ServiceArea>>((ref) async {
  try {
    return await ref.watch(bookingCloudProvider).serviceAreas();
  } on Object {
    return const [];
  }
});

/// Admin closures and caps for one date ("yyyy-mm-dd").
final capacityProvider =
    StreamProvider.autoDispose.family<CapacityDay, String>((ref, key) {
  final cloud = ref.watch(bookingCloudProvider);
  return cloud.watchCapacity(DateTime.parse(key));
});

final customerCloudBookingsProvider =
    StreamProvider<List<BookingRecord>>((ref) {
  final cloud = ref.watch(bookingCloudProvider);
  if (!cloud.configured) return Stream.value(const []);
  return cloud.watchSignedInBookings();
});

/// The customer's bookings, newest first: live from the booking system when
/// connected, plus local copies it hasn't returned yet.
final myBookingsProvider = Provider<List<BookingRecord>>((ref) {
  final local = ref.watch(bookingsProvider);
  final remote = ref.watch(customerCloudBookingsProvider).valueOrNull;
  if (remote == null || !ref.watch(bookingCloudProvider).configured) {
    return local;
  }
  final refs = {for (final b in remote) b.ref};
  return [...remote, ...local.where((b) => !refs.contains(b.ref))]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// ── Saved customer details ────────────────────────────────────────────────────
class ProfileNotifier extends StateNotifier<CustomerProfile> {
  final SharedPreferences _prefs;
  static const _key = 'profile_v1';

  ProfileNotifier(this._prefs) : super(_load(_prefs));

  static CustomerProfile _load(SharedPreferences p) {
    final raw = p.getString(_key);
    if (raw == null) return const CustomerProfile();
    try {
      return CustomerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const CustomerProfile();
    }
  }

  Future<void> save(CustomerProfile p) async {
    state = p;
    await _prefs.setString(_key, jsonEncode(p.toJson()));
  }

  Future<void> clear() async {
    state = const CustomerProfile();
    await _prefs.remove(_key);
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, CustomerProfile>(
    (ref) => ProfileNotifier(ref.watch(sharedPrefsProvider)));

/// The customer chose "Skip, just browsing" on the address step. They are
/// not asked again on launch; booking asks for whatever is still missing.
class SetupSkippedNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const _key = 'setup_skipped_v1';

  SetupSkippedNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  Future<void> skip() async {
    state = true;
    await _prefs.setBool(_key, true);
  }
}

/// Coupon the customer tapped "Use" on in CleanCredit. The booking page
/// applies it automatically when it's eligible; cleared once used.
class PickedOfferNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const _key = 'picked_offer_v1';

  PickedOfferNotifier(this._prefs) : super(_prefs.getString(_key));

  Future<void> pick(String? code) async {
    state = code;
    code == null
        ? await _prefs.remove(_key)
        : await _prefs.setString(_key, code);
  }
}

final pickedOfferProvider = StateNotifierProvider<PickedOfferNotifier, String?>(
    (ref) => PickedOfferNotifier(ref.watch(sharedPrefsProvider)));

// ── Saved addresses ───────────────────────────────────────────────────────────
/// The customer's saved places (Home / Work / Other). The selected one is
/// copied into the profile, which is what bookings and the setup check
/// read, so the rest of the app needs no changes.
class AddressBookNotifier extends StateNotifier<AddressBook> {
  final SharedPreferences _prefs;
  final Ref _ref;
  static const _key = 'addresses_v1';

  AddressBookNotifier(this._prefs, this._ref)
      : super(_load(_prefs, _ref.read(profileProvider)));

  static AddressBook _load(SharedPreferences p, CustomerProfile profile) {
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        return AddressBook(
          items: [
            for (final a in (j['items'] as List? ?? const []))
              SavedAddress.fromJson(a as Map<String, dynamic>),
          ],
          selectedId: j['selectedId'] as String?,
        );
      } catch (_) {}
    }
    // First run after the update: the one address saved so far becomes Home.
    if (profile.address.trim().isEmpty) return const AddressBook();
    const id = 'home';
    return AddressBook(selectedId: id, items: [
      SavedAddress(
          id: id,
          label: AddressLabel.home,
          address: profile.address,
          pin: profile.pin),
    ]);
  }

  Future<void> _persist() => _prefs.setString(
      _key,
      jsonEncode({
        'items': [for (final a in state.items) a.toJson()],
        'selectedId': state.selectedId,
      }));

  /// Bookings use the selected address: keep the profile in step.
  Future<void> _syncProfile() async {
    final sel = state.selected;
    final p = _ref.read(profileProvider);
    if (p.address == (sel?.address ?? '') && p.pin == sel?.pin) return;
    await _ref.read(profileProvider.notifier).save(p.copyWith(
          address: sel?.address ?? '',
          pin: sel?.pin,
          clearPin: sel?.pin == null,
        ));
  }

  /// Adds [a], or replaces the saved one with the same id.
  Future<void> save(SavedAddress a, {bool select = true}) async {
    final items = [
      for (final x in state.items)
        if (x.id != a.id) x,
    ];
    final i = state.items.indexWhere((x) => x.id == a.id);
    items.insert(i < 0 ? items.length : i, a);
    state =
        AddressBook(items: items, selectedId: select ? a.id : state.selectedId);
    await _persist();
    await _syncProfile();
  }

  Future<void> select(String id) async {
    state = AddressBook(items: state.items, selectedId: id);
    await _persist();
    await _syncProfile();
  }

  Future<void> remove(String id) async {
    final items = [
      for (final x in state.items)
        if (x.id != id) x,
    ];
    state = AddressBook(
      items: items,
      selectedId:
          state.selectedId == id ? items.firstOrNull?.id : state.selectedId,
    );
    await _persist();
    await _syncProfile();
  }
}

final addressBookProvider =
    StateNotifierProvider<AddressBookNotifier, AddressBook>(
        (ref) => AddressBookNotifier(ref.watch(sharedPrefsProvider), ref));

final setupSkippedProvider = StateNotifierProvider<SetupSkippedNotifier, bool>(
    (ref) => SetupSkippedNotifier(ref.watch(sharedPrefsProvider)));

// ── Booking requests sent from this device ────────────────────────────────────
class BookingsNotifier extends StateNotifier<List<BookingRecord>> {
  final SharedPreferences _prefs;
  static const _key = 'bookings_v1';

  BookingsNotifier(this._prefs) : super(_load(_prefs));

  static List<BookingRecord> _load(SharedPreferences p) {
    final raw = p.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          BookingRecord.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() =>
      _prefs.setString(_key, jsonEncode([for (final b in state) b.toJson()]));

  Future<void> add(BookingRecord b) async {
    state = [b, ...state];
    await _persist();
  }

  Future<void> remove(String ref) async {
    state = state.where((b) => b.ref != ref).toList();
    await _persist();
  }

  BookingRecord? byRef(String ref) =>
      state.where((b) => b.ref == ref).firstOrNull;
}

final bookingsProvider =
    StateNotifierProvider<BookingsNotifier, List<BookingRecord>>(
        (ref) => BookingsNotifier(ref.watch(sharedPrefsProvider)));

// ── Home "Book again" card ────────────────────────────────────────────────────
/// Ref of the booking whose "Book again" card the customer hid. A newer
/// booking has a different ref, so its card shows again.
class HiddenRebookNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const _key = 'rebook_hidden_v1';

  HiddenRebookNotifier(this._prefs) : super(_prefs.getString(_key));

  Future<void> hide(String ref) async {
    state = ref;
    await _prefs.setString(_key, ref);
  }

  Future<void> unhide() async {
    state = null;
    await _prefs.remove(_key);
  }
}

final hiddenRebookProvider =
    StateNotifierProvider<HiddenRebookNotifier, String?>(
        (ref) => HiddenRebookNotifier(ref.watch(sharedPrefsProvider)));

// ── Booking flow draft ────────────────────────────────────────────────────────
class DraftNotifier extends StateNotifier<BookingDraft> {
  DraftNotifier(super.initial);

  void toggleCleanCredit(bool use) =>
      state = state.copyWith(useCleanCredit: use);
  void applyCoupon(String code, int discount) =>
      state = state.copyWith(couponCode: code, couponDiscount: discount);
  void clearCoupon() => state = state.copyWith(clearCoupon: true);
  void removeCoupon() => clearCoupon();
  void setCar(CarType c) => state = state.copyWith(car: c);
  void setCarModel(String m) => state = state.copyWith(carModel: m);

  void setExtra(String id, int qty) {
    final m = Map<String, int>.from(state.extras);
    if (qty <= 0) {
      m.remove(id);
    } else {
      m[id] = qty;
    }
    state = state.copyWith(extras: m);
  }

  void setDate(DateTime d) {
    final keepSlot = state.slot?.isAvailable(d) ?? false;
    state = state.copyWith(date: d, clearSlot: !keepSlot);
  }

  void setSlot(String id) => state = state.copyWith(slotId: id);
  void setName(String v) => state = state.copyWith(name: v);
  void setPhone(String v) => state = state.copyWith(phone: v);
  void setAddress(String v) => state = state.copyWith(address: v);
  void setRecipientName(String v) => state = state.copyWith(recipientName: v);
  void setRecipientPhone(String v) => state = state.copyWith(recipientPhone: v);
  void setNotifyRecipient(bool v) => state = state.copyWith(notifyRecipient: v);

  /// Switching to "someone else" drops a GPS pin: it marks where the booker
  /// is standing, not where the other person's car is.
  /// Someone else's car is somewhere else: the booker's saved address, saved
  /// pin and GPS position don't apply, so start a fresh address for them.
  void setBookingFor(BookingFor v, List<ServiceArea> areas) {
    if (v == state.bookingFor) return;
    if (v == BookingFor.someoneElse) {
      state = state.copyWith(
        bookingFor: v,
        usingSaved: false,
        address: composeAddress(state.addressParts),
        clearPin: state.usingSaved || state.pinSource == PinSource.gps,
        coverage: Coverage.unverified,
      );
    } else {
      state = state.copyWith(bookingFor: v);
      if (state.savedAddress.isNotEmpty) useSavedAddress(areas);
    }
  }

  void useSavedAddress(List<ServiceArea> areas) {
    final pin = state.savedPin;
    state = state.copyWith(
      usingSaved: true,
      address: withParking(state.savedAddress, state.addressParts['parking']),
      pin: pin,
      pinSource: pin == null ? null : PinSource.pasted,
      clearPin: pin == null,
      coverage: checkCoverage(parsePin(pin), areas),
    );
  }

  void useNewAddress() => state = state.copyWith(
        usingSaved: false,
        address: composeAddress(state.addressParts),
        clearPin: true,
        coverage: Coverage.unverified,
      );

  void setAddressPart(String key, String? value) {
    final parts = {...state.addressParts, key: value ?? ''};
    state = state.copyWith(
      addressParts: parts,
      address: state.usingSaved
          ? withParking(state.savedAddress, parts['parking'])
          : composeAddress(parts),
    );
  }

  void setPin(String? v,
      {PinSource? source, List<ServiceArea> areas = const []}) {
    state = v == null
        ? state.copyWith(clearPin: true, coverage: Coverage.unverified)
        : state.copyWith(
            pin: v,
            pinSource: source,
            coverage: checkCoverage(parsePin(v), areas));
  }

  void updateCoverage(List<ServiceArea> areas) => state =
      state.copyWith(coverage: checkCoverage(parsePin(state.pin), areas));

  /// The customer changed their saved car or address (from checkout or
  /// anywhere else): use it for this booking too.
  void applyProfile(CustomerProfile p, List<ServiceArea> areas) {
    state = state.copyWith(
      car: p.car,
      carModel: p.carModel,
      address: p.address,
      usingSaved: true,
      pin: p.pin,
      pinSource: p.pin == null ? null : PinSource.pasted,
      clearPin: p.pin == null,
      coverage: checkCoverage(parsePin(p.pin), areas),
    );
  }
}

/// One draft per service. Pre-filled with the customer's saved details.
final draftProvider = StateNotifierProvider.autoDispose
    .family<DraftNotifier, BookingDraft, String>((ref, serviceId) {
  final p = ref.read(profileProvider);
  final cloud = ref.read(bookingCloudProvider);
  return DraftNotifier(BookingDraft(
    service: serviceById(serviceId)!,
    bookingRef: newBookingRef(),
    car: p.car,
    carModel: p.carModel,
    // The booker is the logged-in customer, with their OTP-verified number.
    name: cloud.customerName ?? p.name,
    phone: cloud.verifiedPhone ?? p.phone,
    address: p.address,
    savedAddress: withParking(p.address, null),
    savedPin: p.pin,
    usingSaved: p.address.isNotEmpty,
    addressParts: {
      if (parkingOf(p.address) case final parking?) 'parking': parking,
    },
    // A saved pin came from this booker's own booking for their car.
    pin: p.pin,
    pinSource: p.pin == null ? null : PinSource.pasted,
  ));
});

// ── CleanCredit Wallet ────────────────────────────────────────────────────────
class WalletNotifier extends StateNotifier<WalletState> {
  final SharedPreferences _prefs;
  static const _key = 'clean_credit_wallet_v1';

  WalletNotifier(this._prefs) : super(_load(_prefs));

  /// Id of the automatic ₹200 sign-up credit older versions of the app
  /// added. Credit is now only given by the team (e.g. after a missed or
  /// rained-out wash), so that entry is removed on load.
  static const _retiredWelcomeId = 'tx-welcome';

  static WalletState _load(SharedPreferences p) {
    final raw = p.getString(_key);
    if (raw == null) return const WalletState();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      var balance = json['balance'] as int? ?? 0;
      final txs = <WalletTransaction>[];
      for (final item in (json['transactions'] as List? ?? const [])) {
        final t = WalletTransaction.fromJson(item as Map<String, dynamic>);
        if (t.id == _retiredWelcomeId) {
          balance -= t.amount;
        } else {
          txs.add(t);
        }
      }
      return WalletState(balance: balance.clamp(0, 999999), transactions: txs);
    } catch (_) {
      return const WalletState();
    }
  }

  Future<void> _persist() async {
    final json = {
      'balance': state.balance,
      'transactions': [for (final t in state.transactions) t.toJson()],
    };
    await _prefs.setString(_key, jsonEncode(json));
  }

  Future<void> applyCredit(int amount, String bookingRef) async {
    if (amount <= 0) return;
    final newBalance = (state.balance - amount).clamp(0, 999999);
    final tx = WalletTransaction(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Applied on Booking #$bookingRef',
      description: 'CleanCredit redeemed at checkout',
      amount: -amount,
      date: DateTime.now(),
      referenceId: bookingRef,
    );
    state = state.copyWith(
      balance: newBalance,
      transactions: [tx, ...state.transactions],
    );
    await _persist();
  }

  Future<void> addCredit(int amount, String title, String description) async {
    if (amount <= 0) return;
    final newBalance = state.balance + amount;
    final tx = WalletTransaction(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      amount: amount,
      date: DateTime.now(),
    );
    state = state.copyWith(
      balance: newBalance,
      transactions: [tx, ...state.transactions],
    );
    await _persist();
  }

  Future<void> refundCredit(int amount, String bookingRef) async {
    if (amount <= 0) return;
    final newBalance = state.balance + amount;
    final tx = WalletTransaction(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Refund for Booking #$bookingRef',
      description: 'CleanCredit refunded upon cancellation',
      amount: amount,
      date: DateTime.now(),
      referenceId: bookingRef,
    );
    state = state.copyWith(
      balance: newBalance,
      transactions: [tx, ...state.transactions],
    );
    await _persist();
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
    (ref) => WalletNotifier(ref.watch(sharedPrefsProvider)));
