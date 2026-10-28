import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/pricing.dart';
import '../models/booking.dart';
import '../models/service.dart';

/// Overridden in main() with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden');
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
  void setPin(String? v) => state =
      v == null ? state.copyWith(clearPin: true) : state.copyWith(pin: v);
}

/// One draft per service. Pre-filled with the customer's saved details.
final draftProvider = StateNotifierProvider.autoDispose
    .family<DraftNotifier, BookingDraft, String>((ref, serviceId) {
  final p = ref.read(profileProvider);
  return DraftNotifier(BookingDraft(
    service: serviceById(serviceId)!,
    car: p.car,
    carModel: p.carModel,
    name: p.name,
    phone: p.phone,
    address: p.address,
    pin: p.pin,
  ));
});
