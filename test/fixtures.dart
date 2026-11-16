// Shared test data: a signed-in customer with a car, an address and one
// booking in different states. Used by layout tests and the screenshot tool.
import 'dart:convert';
import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:cleancruisers_app/core/pricing.dart';

const profile = {
  'profile_v1':
      '{"name":"Rahul Sharma","phone":"9876543210","address":"B-12, Pocket 3, Janakpuri, near metro","car":"hatchback","carModel":"White Swift"}'
};

final sampleBooking = {
  ...BookingRecord.fromDraft(BookingDraft(
    service: serviceById('wash-full')!,
    bookingRef: 'CC-7K4Q2X9M',
    car: CarType.hatchback,
    carModel: 'White Swift',
    extras: const {'seat': 2},
    date: addDays(DateTime.now(), 1),
    slotId: '0930',
    name: 'Rahul Sharma',
    phone: '9876543210',
    address: 'B-12, Pocket 3, Janakpuri, near metro',
  )).toJson(),
};

Map<String, Object> bookingPrefs({bool confirmed = true}) => {
      ...profile,
      'bookings_v1': jsonEncode([
        {
          ...sampleBooking,
          if (confirmed) ...{
            'status': 'confirmed',
            'workerId': 'w1',
            'plannedArrivalMinute': 595,
            'history': [
              ...(sampleBooking['history'] as List),
              StatusEvent(BookingStatus.confirmed, DateTime.now(),
                      'Expert booked. Arriving around 9:55 AM.')
                  .toJson(),
            ],
          },
        }
      ]),
    };

/// A returning customer with one finished wash and nothing in progress
/// (Home shows "Book again").
Map<String, Object> repeatPrefs() => {
      ...profile,
      'bookings_v1': jsonEncode([
        {
          ...sampleBooking,
          'date': addDays(DateTime.now(), -11).toIso8601String(),
          'status': 'completed',
        }
      ]),
    };

/// Rain hold: the team offers another slot and leaves a note.
Map<String, Object> holdPrefs() => {
      ...profile,
      'bookings_v1': jsonEncode([
        {
          ...sampleBooking,
          'status': 'rescheduleNeeded',
          'offeredDate': addDays(DateTime.now(), 2).toIso8601String(),
          'offeredSlotId': '0930',
        }
      ]),
    };

