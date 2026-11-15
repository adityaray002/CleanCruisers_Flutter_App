// Nullable on purpose: set a value to null to hide it in the UI.
// ignore_for_file: unnecessary_nullable_for_final_variable_declarations

// ── Business facts shown to customers ─────────────────────────────────────────
// Everything the app claims about CleanCruisers lives here so it can be checked
// in one place. Only put information here that is true today. Anything set to
// null / empty is simply hidden in the UI.

// Customer-facing booking hours follow the current operating plan.
const kOpenHour = 8; // workers leave around 8 AM
const kCloseHour = 18; // every customer's car work must finish by 6 PM
const kHoursLabel = '8 AM – 6 PM';
const kDaysLabel = 'All 7 days';

const kCityLabel = 'Delhi NCR';

// Payment model. The app does not take payments; customers pay the team
// after the service is done.
const kPayAfterService = true;

// How long the team usually takes to confirm a slot request (owner,
// 15 Nov 2026). Shown on the booking page and after a request is sent.
const kConfirmUsually = '1–2 hours';

// ── Social proof ──────────────────────────────────────────────────────────────
// TODO(business): confirm these are current before each release. Set to null
// to hide a figure rather than showing an unverified number.
// Rating and customer count are hidden until they are verified. When you
// re-enable the rating, also set kRatingSource so customers can check it.
const String? kRatingValue = null; // average rating, e.g. '4.9'
const String? kRatingSource = null; // e.g. 'Google' — shown as "4.9 on Google"
const String? kCustomersServed = null; // e.g. '1000+'
const String? kEstablished = '2020';

// Our own work (same car, before and after our cleaning); confirmed by the
// owner on 13 Nov 2026. Set to null to hide the "See the difference" card
// on Home.
const String? kBeforeAfterPhoto = 'assets/images/wheel_before_after.jpg';

// TODO(business): set to true only once the team really uses water-saving
// methods and eco-friendly products. Shows the green banner on Home.
const kEcoFriendly = false;

class Review {
  final String name, area, text;
  final int stars;
  const Review(this.name, this.area, this.text, this.stars);
}

// TODO(business): replace with real, attributable customer reviews
// (e.g. copied from Google Business Profile). Leave the list empty to hide
// the reviews section.
const kReviews = <Review>[];

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
