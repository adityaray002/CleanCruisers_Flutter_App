# CleanCruisers Flutter App — Setup Guide

## 1. Install Flutter SDK

1. Download from: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your system PATH
4. Run `flutter doctor` to verify

## 2. Get Project Dependencies

```bash
cd C:\Users\adity\cleancruisers_app
flutter pub get
```

## 3. Run the App

### Android (USB debug or emulator)
```bash
flutter run
```

### iOS (Mac + Xcode required)
```bash
flutter run
```

## 5. Build for Release

### Android (Play Store)
```bash
flutter build appbundle --release
```
Upload the `.aab` file at `build/app/outputs/bundle/release/app-release.aab`

### iOS (App Store — Mac required)
```bash
flutter build ios --release
```
Then open `ios/Runner.xcworkspace` in Xcode and archive.

## 6. Android Package Name

Current: `com.cleancruisers.app`

To change: update in `android/app/build.gradle`:
```gradle
applicationId "com.cleancruisers.app"
```
And in `ios/Runner/Info.plist`:
```xml
<key>CFBundleIdentifier</key>
<string>com.cleancruisers.app</string>
```

## 7. App Signing (Required for Store Publishing)

### Android
Run: `keytool -genkey -v -keystore cleancruisers.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cleancruisers`

Add to `android/app/build.gradle` in `signingConfigs`.

### iOS
Set up in Xcode → Signing & Capabilities with your Apple Developer account.

## Project Structure

```
lib/
├── main.dart                   — App entry point
├── core/
│   ├── theme.dart              — Design system: colours, spacing, radius, shadows, type, ThemeData
│   ├── constants.dart          — Phone, WhatsApp, email, social links
│   ├── pricing.dart            — Raw price tables (mirrors the website)
│   ├── format.dart             — ₹ and date formatting
│   └── router.dart             — GoRouter routes
├── data/
│   ├── business_info.dart      — Hours, areas, ratings, reviews, gallery (verify before release!)
│   └── blog_data.dart          — Car care articles
├── models/
│   ├── service.dart            — Service catalogue (names, photos, prices, inclusions, extras)
│   └── booking.dart            — Time slots, booking draft, saved bookings, customer profile
├── providers/
│   └── app_providers.dart      — Riverpod: saved profile, saved bookings, booking draft
├── screens/
│   ├── splash_screen.dart
│   ├── main_shell.dart         — Bottom nav: Home · Services · Bookings · Profile
│   ├── home_screen.dart
│   ├── services_screen.dart
│   ├── service_detail_screen.dart
│   ├── booking/                — 4-step flow: Car → Date & time → Address → Review
│   ├── booking_sent_screen.dart
│   ├── bookings_screen.dart / booking_detail_screen.dart
│   ├── profile_screen.dart     — Saved details, support, about, tips
│   └── blog_list_screen.dart / blog_detail_screen.dart
└── widgets/
    ├── ui.dart                 — Buttons, cards, pills, empty states, bottom action bar
    ├── service_widgets.dart    — Service image, card and row
    ├── how_it_works.dart
    └── contact_actions.dart    — WhatsApp / call / link helpers with error handling
```

## Updating business content

- **Prices** — `lib/core/pricing.dart`
- **Services** (names, descriptions, photos, what's included) — `lib/models/service.dart`
- **Hours, areas, rating, customer count, reviews, gallery** — `lib/data/business_info.dart`.
  Set a figure to `null` (or empty the reviews list) to hide it instead of showing something unverified.

## How booking works

There is no backend. A booking builds a WhatsApp message (with a `CC-XXXXX` reference) to the
business number; the customer taps Send, and the team confirms on WhatsApp. The booking and the
customer's details are saved on the device (SharedPreferences) so they appear under **Bookings** and
pre-fill the next booking.

Fonts: Plus Jakarta Sans is bundled in `assets/google_fonts/` (SIL OFL, see `OFL.txt`), so no font is
downloaded at runtime.
