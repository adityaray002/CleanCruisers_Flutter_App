import 'dart:convert';
import 'package:cleancruisers_app/core/scheduling.dart';
import 'package:cleancruisers_app/models/address.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:cleancruisers_app/widgets/customer_sheets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> make(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final c =
      ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(p)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('the one address saved before the update becomes "Home"', () async {
    final c = await make({
      'profile_v1': jsonEncode(
          {'name': 'A', 'phone': '9876543210', 'address': 'B-12, Janakpuri'})
    });
    final book = c.read(addressBookProvider);
    expect(book.items.single.label, AddressLabel.home);
    expect(book.selected?.address, 'B-12, Janakpuri');
  });

  test('selecting an address is what bookings use', () async {
    final c = await make({});
    final n = c.read(addressBookProvider.notifier);
    await n.save(const SavedAddress(
        id: 'h', label: AddressLabel.home, address: 'B-12, Janakpuri'));
    await n.save(const SavedAddress(
        id: 'w',
        label: AddressLabel.work,
        address: 'Tower 3, Dwarka',
        pin: '28.59,77.04'));
    expect(c.read(profileProvider).address, 'Tower 3, Dwarka',
        reason: 'a newly added address is selected');
    expect(c.read(profileProvider).pin, '28.59,77.04');

    await n.select('h');
    expect(c.read(profileProvider).address, 'B-12, Janakpuri');
    expect(c.read(profileProvider).pin, isNull);

    await n.remove('h');
    expect(c.read(addressBookProvider).selected?.id, 'w',
        reason: 'deleting the selected one falls back to the next');
    expect(c.read(profileProvider).address, 'Tower 3, Dwarka');
  });

  test('availability: map pin first, then a served area name', () {
    const typed = SavedAddress(
        id: '1', label: AddressLabel.home, address: 'B-12, Janakpuri');
    const unknown = SavedAddress(
        id: '2', label: AddressLabel.other, address: 'Flat 4, Somewhere');
    expect(addressCoverage(typed, const []), Coverage.covered);
    expect(addressCoverage(unknown, const []), Coverage.unverified);
  });
}
