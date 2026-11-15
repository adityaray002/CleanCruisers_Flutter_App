import 'package:cleancruisers_app/data/booking_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a booking error is not a taken slot unless it says so', () {
    const e = BookingCloudException('Please try again in a moment.');
    expect(e.slotTaken, isFalse);
    expect(e.toString(), 'Please try again in a moment.');
  });

  test('a taken slot is marked, so the booking page can offer other times', () {
    const e = BookingCloudException(
        'Sorry, that slot just got booked. Please pick another time.',
        slotTaken: true);
    expect(e.slotTaken, isTrue);
  });
}
