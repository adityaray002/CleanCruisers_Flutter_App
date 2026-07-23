import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_state.dart';
import '../core/pricing.dart';

class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier() : super(const BookingState());

  void reset() => state = const BookingState();

  void selectServiceType(ServiceType type) {
    state = BookingState(serviceType: type, step: 1, forward: true);
  }

  void selectCarType(CarType car) {
    state = state.copyWith(
      carType: car,
      step: state.step + 1,
      forward: true,
      // Clear downstream state when car changes
      washPackage: null,
      selectedAddonIds: const [],
      washAddons: const [],
    );
  }

  void selectWashPackage(WashPackage pkg) {
    state = state.copyWith(washPackage: pkg, step: state.step + 1, forward: true);
  }

  void toggleAddon(String addonId) {
    final ids = List<String>.from(state.selectedAddonIds);
    if (ids.contains(addonId)) {
      ids.remove(addonId);
    } else {
      ids.add(addonId);
    }
    state = state.copyWith(selectedAddonIds: ids);
  }

  void setWashAddonQty(String id, int qty) {
    final addons = List<WashAddonItem>.from(state.washAddons);
    final idx = addons.indexWhere((a) => a.id == id);
    if (qty <= 0) {
      if (idx >= 0) addons.removeAt(idx);
    } else {
      if (idx >= 0) {
        addons[idx] = addons[idx].copyWith(qty: qty);
      } else {
        addons.add(WashAddonItem(id: id, qty: qty));
      }
    }
    state = state.copyWith(washAddons: addons);
  }

  void nextStep() => state = state.copyWith(step: state.step + 1, forward: true);

  void prevStep() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, forward: false);
    }
  }

  void updateDetails({
    String? name, String? phone, String? carModel, String? location,
  }) {
    state = state.copyWith(
      name: name ?? state.name,
      phone: phone ?? state.phone,
      carModel: carModel ?? state.carModel,
      location: location ?? state.location,
    );
  }

  void updateSchedule({DateTime? date, String? timeSlot}) {
    state = state.copyWith(
      preferredDate: date ?? state.preferredDate,
      preferredTimeSlot: timeSlot ?? state.preferredTimeSlot,
    );
  }

  void setSubmitting(bool v) => state = state.copyWith(isSubmitting: v);
}

final bookingProvider =
    StateNotifierProvider<BookingNotifier, BookingState>((ref) => BookingNotifier());
