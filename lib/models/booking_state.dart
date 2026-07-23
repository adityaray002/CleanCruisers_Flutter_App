import '../core/pricing.dart';

class WashAddonItem {
  final String id;
  final int qty;
  const WashAddonItem({required this.id, required this.qty});
  WashAddonItem copyWith({int? qty}) => WashAddonItem(id: id, qty: qty ?? this.qty);
}

class BookingState {
  final int step;
  final bool forward; // true = going forward, false = going back (for animation direction)
  final ServiceType serviceType;
  final CarType? carType;
  final WashPackage? washPackage;
  final List<String> selectedAddonIds;
  final List<WashAddonItem> washAddons;
  final String name;
  final String phone;
  final String carModel;
  final String location;
  final DateTime? preferredDate;
  final String preferredTimeSlot;
  final bool isSubmitting;

  const BookingState({
    this.step = 0,
    this.forward = true,
    this.serviceType = ServiceType.oneTime,
    this.carType,
    this.washPackage,
    this.selectedAddonIds = const [],
    this.washAddons = const [],
    this.name = '',
    this.phone = '',
    this.carModel = '',
    this.location = '',
    this.preferredDate,
    this.preferredTimeSlot = '',
    this.isSubmitting = false,
  });

  BookingState copyWith({
    int? step,
    bool? forward,
    ServiceType? serviceType,
    CarType? carType,
    WashPackage? washPackage,
    List<String>? selectedAddonIds,
    List<WashAddonItem>? washAddons,
    String? name,
    String? phone,
    String? carModel,
    String? location,
    DateTime? preferredDate,
    String? preferredTimeSlot,
    bool? isSubmitting,
  }) {
    return BookingState(
      step: step ?? this.step,
      forward: forward ?? this.forward,
      serviceType: serviceType ?? this.serviceType,
      carType: carType ?? this.carType,
      washPackage: washPackage ?? this.washPackage,
      selectedAddonIds: selectedAddonIds ?? this.selectedAddonIds,
      washAddons: washAddons ?? this.washAddons,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      carModel: carModel ?? this.carModel,
      location: location ?? this.location,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  int get totalSteps {
    switch (serviceType) {
      case ServiceType.oneTime:       return 5;
      case ServiceType.premiumAddons: return 4;
      case ServiceType.completeCare:  return 4;
    }
  }

  int computeTotal() {
    if (carType == null) return 0;
    switch (serviceType) {
      case ServiceType.oneTime:
        int base = washPackage != null
            ? (washPackagePrices[washPackage]?[carType] ?? 0) : 0;
        int extra = 0;
        for (final item in washAddons) {
          extra += (washAddonPrices[item.id] ?? 0) * item.qty;
        }
        return base + extra;
      case ServiceType.premiumAddons:
        int total = 0;
        for (final id in selectedAddonIds) {
          total += premiumAddonPrices[id]?[carType!] ?? 0;
        }
        return total;
      case ServiceType.completeCare:
        return completeCarePrice[carType] ?? 0;
    }
  }

  String get formattedDate {
    if (preferredDate == null) return '';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final d = preferredDate!;
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String buildWhatsAppMessage() {
    final svcName = serviceTypeLabel;
    final car     = carTypeNames[carType] ?? '';
    final total   = computeTotal();
    final buffer  = StringBuffer();

    buffer.writeln('🚗 *CleanCruisers Booking Request*');
    buffer.writeln('');
    buffer.writeln('*Name:* $name');
    buffer.writeln('*Phone:* +91 $phone');
    if (carModel.isNotEmpty) buffer.writeln('*Car Model:* $carModel');
    if (location.isNotEmpty) {
      final coordRegex = RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$');
      if (coordRegex.hasMatch(location.trim())) {
        final parts = location.trim().split(',');
        buffer.writeln('*Location:* https://maps.google.com/?q=${parts[0].trim()},${parts[1].trim()}');
      } else {
        buffer.writeln('*Location:* $location');
      }
    }
    buffer.writeln('');
    buffer.writeln('*Service:* $svcName');
    buffer.writeln('*Car Type:* $car');

    switch (serviceType) {
      case ServiceType.oneTime:
        if (washPackage != null) {
          buffer.writeln('*Package:* ${washPackageNames[washPackage]}');
        }
        if (washAddons.isNotEmpty) {
          buffer.writeln('*Add-ons:*');
          for (final item in washAddons) {
            buffer.writeln('  - ${washAddonNames[item.id] ?? item.id} × ${item.qty}');
          }
        }
      case ServiceType.premiumAddons:
        if (selectedAddonIds.isNotEmpty) {
          buffer.writeln('*Selected Services:*');
          for (final id in selectedAddonIds) {
            final addon = premiumAddons.firstWhere((a) => a.id == id,
                orElse: () => const AddonService(id: '', name: '', description: '', inclusions: []));
            buffer.writeln('  - ${addon.name}');
          }
        }
      case ServiceType.completeCare:
        buffer.writeln('*Plan:* Complete Care Monthly Package (3 Washes)');
    }

    if (preferredDate != null) {
      buffer.writeln('');
      buffer.writeln('*Preferred Date:* $formattedDate');
    }
    if (preferredTimeSlot.isNotEmpty) {
      buffer.writeln('*Preferred Time:* $preferredTimeSlot');
    }

    if (total > 0) {
      buffer.writeln('');
      buffer.writeln('*Estimated Total:* ₹$total');
    }
    buffer.writeln('');
    buffer.writeln('Please confirm my booking. Thank you! 🙏');
    return Uri.encodeComponent(buffer.toString());
  }

  String get serviceTypeLabel {
    switch (serviceType) {
      case ServiceType.oneTime:       return 'Car Wash & Care (One-Time)';
      case ServiceType.premiumAddons: return 'Complete Car Care (Detailing)';
      case ServiceType.completeCare:  return 'Monthly Car Wash Package';
    }
  }
}
