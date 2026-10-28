// Nullable on purpose: set a value to null to hide it in the UI.
// ignore_for_file: unnecessary_nullable_for_final_variable_declarations

// ── Business facts shown to customers ─────────────────────────────────────────
// Everything the app claims about CleanCruisers lives here so it can be checked
// in one place. Only put information here that is true today. Anything set to
// null / empty is simply hidden in the UI.

// Service hours. Booking time slots are generated from these.
const kOpenHour = 7; // 7 AM
const kCloseHour = 20; // 8 PM
const kHoursLabel = '7 AM – 8 PM';
const kDaysLabel = 'All 7 days';

const kCityLabel = 'Delhi NCR';

// How quickly the team replies to a WhatsApp booking request.
const kConfirmWithin = '30 minutes';

// Payment model. The app does not take payments; customers pay the team
// after the service is done.
const kPayAfterService = true;

// ── Social proof ──────────────────────────────────────────────────────────────
// TODO(business): confirm these are current before each release. Set to null
// to hide a figure rather than showing an unverified number.
const String? kRatingValue = '4.9'; // average rating
const String? kRatingSource = null; // e.g. 'Google' — shown as "4.9 on Google"
const String? kCustomersServed = '1000+';
const String? kEstablished = '2020';

class Review {
  final String name, area, text;
  final int stars;
  const Review(this.name, this.area, this.text, this.stars);
}

// TODO(business): replace with real, attributable customer reviews
// (e.g. copied from Google Business Profile). Leave the list empty to hide
// the reviews section.
const kReviews = <Review>[
  Review(
      'Priya S.',
      'South Delhi',
      'Amazing! They came on time, car looks showroom clean. Will book again!',
      5),
  Review('Rahul M.', 'Dwarka',
      'Very professional team. Best doorstep car wash in Delhi!', 5),
  Review('Anjali K.', 'Janakpuri',
      'Booked on WhatsApp, team arrived in 30 mins. Perfectly done.', 5),
  Review('Sanjay T.', 'Uttam Nagar',
      'Monthly package saves so much time. Three washes at doorstep!', 5),
];

const kServiceAreas = [
  'Dwarka',
  'Janakpuri',
  'Uttam Nagar',
  'Vikaspuri',
  'Paschim Vihar',
  'West Delhi',
  'South Delhi',
  'East Delhi',
  'New Delhi',
  'Rohini',
  'Pitampura',
];
