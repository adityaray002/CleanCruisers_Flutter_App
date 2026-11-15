import 'dart:math';
import '../core/pricing.dart';

/// Coupons offered to customers.
///
/// **To add, change or stop an offer, edit [kOffers] below.** Each offer
/// shows on the CleanCredit tab ("Offers for you") and in "Add coupon" on
/// the booking page; the rules here decide who can use it.
///
/// Every coupon is also capped at 40% of the bill (see
/// `BookingDraft.maxCouponDiscount`).
class Offer {
  /// What the customer types, e.g. `WEEKDAY40`. Upper case, no spaces.
  final String code;

  /// Short line under the headline, e.g. 'Off any wash'.
  final String title;

  /// Flat rupees off. Use this or [percentOff].
  final int flatOff;

  /// Percent off the bill. Use this or [flatOff].
  final int percentOff;

  /// Most a percent offer can take off, if any.
  final int? maxOff;

  /// Smallest bill (service + add-ons) the coupon works on.
  final int minTotal;

  /// Only these car types, or null for every car.
  final Set<CarType>? onlyFor;

  /// Only if the customer has never booked before.
  final bool firstBookingOnly;

  const Offer({
    required this.code,
    required this.title,
    this.flatOff = 0,
    this.percentOff = 0,
    this.maxOff,
    this.minTotal = 0,
    this.onlyFor,
    this.firstBookingOnly = false,
  });

  /// Big text on the ticket: "₹40 OFF" or "10% OFF".
  String get headline => percentOff > 0 ? '$percentOff% OFF' : '₹$flatOff OFF';

  /// The rules in a few words each, e.g. ['Min. bill ₹449', 'SUV only'].
  List<String> get conditions => [
        if (minTotal > 0) 'Min. bill ₹$minTotal',
        if (onlyFor != null)
          '${onlyFor!.map((c) => carTypeNames[c]).join(' / ')} only',
        if (firstBookingOnly) 'First booking only',
      ];

  /// Why this customer can't use it right now, or null if they can.
  String? whyNot(
      {required int total, required CarType? car, required bool firstBooking}) {
    if (firstBookingOnly && !firstBooking) return 'Only for a first booking';
    if (onlyFor != null && (car == null || !onlyFor!.contains(car))) {
      return 'Only for ${onlyFor!.map((c) => carTypeNames[c]).join(' / ')}';
    }
    if (total < minTotal) return 'Add ₹${minTotal - total} more to use it';
    return null;
  }

  /// Rupees off a bill of [total] (before the 40% cap).
  int discountFor(int total) {
    final raw = percentOff > 0 ? total * percentOff ~/ 100 : flatOff;
    return min(min(raw, maxOff ?? raw), total);
  }
}

/// The offers live right now. Remove a line to stop an offer.
const kOffers = <Offer>[
  Offer(code: 'WEEKDAY40', title: 'Off any wash', flatOff: 40, minTotal: 449),
  Offer(
      code: 'FIRST100',
      title: 'Off first booking',
      flatOff: 100,
      firstBookingOnly: true),
  Offer(
      code: 'SUVSPECIAL',
      title: 'Off for SUVs',
      percentOff: 10,
      onlyFor: {CarType.suv}),
];

Offer? offerByCode(String code) {
  final c = code.trim().toUpperCase();
  for (final o in kOffers) {
    if (o.code == c) return o;
  }
  return null;
}
