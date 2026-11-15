import 'package:flutter/material.dart';

/// Saved places where the customer's car is parked (Zomato / Blinkit style).
/// One is selected; bookings go to the selected one.
enum AddressLabel { home, work, other }

const addressLabelNames = {
  AddressLabel.home: 'Home',
  AddressLabel.work: 'Work',
  AddressLabel.other: 'Other',
};

const addressLabelIcons = {
  AddressLabel.home: Icons.home_rounded,
  AddressLabel.work: Icons.work_rounded,
  AddressLabel.other: Icons.place_rounded,
};

class SavedAddress {
  final String id;
  final AddressLabel label;

  /// The full address line (house, area, landmark, parking note).
  final String address;

  /// Map pin "lat,lng", if the customer pinned one. Needed to confirm we
  /// serve the spot.
  final String? pin;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.pin,
  });

  SavedAddress copyWith(
          {AddressLabel? label,
          String? address,
          String? pin,
          bool clearPin = false}) =>
      SavedAddress(
        id: id,
        label: label ?? this.label,
        address: address ?? this.address,
        pin: clearPin ? null : (pin ?? this.pin),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label.name, 'address': address, 'pin': pin};

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: j['id'] as String,
        label: AddressLabel.values
                .where((l) => l.name == j['label'])
                .firstOrNull ??
            AddressLabel.other,
        address: j['address'] as String? ?? '',
        pin: j['pin'] as String?,
      );
}

class AddressBook {
  final List<SavedAddress> items;
  final String? selectedId;
  const AddressBook({this.items = const [], this.selectedId});

  SavedAddress? get selected =>
      items.where((a) => a.id == selectedId).firstOrNull ?? items.firstOrNull;
}
