import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/address_convert.dart';
import '../models/address.dart';
import '../models/booking.dart';
import 'api_providers.dart';

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

  /// Adds [a], or replaces the saved one with the same id. The server gets
  /// a copy (contract §4) so the address follows the account to a new phone.
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
    await _push(a);
  }

  /// Saves [a] on the server and remembers its server id. Offline or logged
  /// out: the phone's copy stays and it is pushed on the next save.
  Future<void> _push(SavedAddress a) async {
    if (!_ref.read(authServiceProvider).signedIn) return;
    final body = apiAddressFromLine(a.address, a.pin,
        label: a.label.name,
        isDefault: state.selectedId == a.id,
        id: a.serverId);
    if (body == null) return;
    try {
      final api = _ref.read(apiProvider);
      final saved = a.serverId == null
          ? await api.addAddress(body)
          : await api.updateAddress(body);
      if (saved.id != a.serverId) {
        state = AddressBook(items: [
          for (final x in state.items)
            x.id == a.id ? x.copyWith(serverId: saved.id) : x,
        ], selectedId: state.selectedId);
        await _persist();
      }
    } on Object {
      // Kept on the phone; tried again next time.
    }
  }

  /// A new phone: bring the account's saved addresses from the server.
  /// Does nothing if this phone already has addresses.
  Future<void> restoreFromServer() async {
    if (state.items.isNotEmpty || !_ref.read(authServiceProvider).signedIn) return;
    try {
      final list = await _ref.read(apiProvider).addresses();
      if (list.isEmpty) return;
      final items = [
        for (final a in list)
          SavedAddress(
            id: 'srv-${a.id}',
            label: AddressLabel.values
                    .where((l) => l.name == a.label)
                    .firstOrNull ??
                AddressLabel.other,
            address: lineOfApiAddress(a),
            pin: pinOfApiAddress(a),
            serverId: a.id,
          ),
      ];
      final def = list.indexWhere((a) => a.isDefault);
      state = AddressBook(
          items: items, selectedId: items[def < 0 ? 0 : def].id);
      await _persist();
      await _syncProfile();
    } on Object {
      // No server copy reachable: the customer adds one as usual.
    }
  }

  Future<void> select(String id) async {
    state = AddressBook(items: state.items, selectedId: id);
    await _persist();
    await _syncProfile();
  }

  Future<void> remove(String id) async {
    final gone = state.items.where((x) => x.id == id).firstOrNull;
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
    final serverId = gone?.serverId;
    if (serverId != null && _ref.read(authServiceProvider).signedIn) {
      try {
        await _ref.read(apiProvider).deleteAddress(serverId);
      } on Object {
        // An address a plan still uses stays on the server; nothing to show.
      }
    }
  }
}

final addressBookProvider =
    StateNotifierProvider<AddressBookNotifier, AddressBook>(
        (ref) => AddressBookNotifier(ref.watch(sharedPrefsProvider), ref));

final setupSkippedProvider = StateNotifierProvider<SetupSkippedNotifier, bool>(
    (ref) => SetupSkippedNotifier(ref.watch(sharedPrefsProvider)));

