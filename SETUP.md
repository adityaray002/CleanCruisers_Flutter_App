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

## 4. Add App Logo

Copy your logo file to:
```
assets/images/logo.png
```

The app currently uses a green car-wash icon in place of the logo. Replace it by
adding the image and updating the AppBar widget in `home_screen.dart`.

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
├── main.dart              — App entry point
├── core/
│   ├── constants.dart     — Colors, phone, email, social links
│   ├── pricing.dart       — All service pricing data
│   ├── theme.dart         — Dark theme definition
│   └── router.dart        — GoRouter navigation
├── data/
│   └── blog_data.dart     — 8 blog posts with full content
├── models/
│   ├── blog_post.dart     — Blog post data model
│   └── booking_state.dart — Booking wizard state model
├── providers/
│   └── booking_provider.dart — Riverpod state management
├── screens/
│   ├── home_screen.dart       — Main home with all sections
│   ├── booking_screen.dart    — Multi-step booking wizard
│   ├── blog_list_screen.dart  — Blog listing
│   ├── blog_detail_screen.dart — Blog reader
│   ├── contact_screen.dart    — Contact + about
│   └── main_shell.dart        — Bottom navigation shell
└── widgets/
    ├── green_button.dart   — Primary button components
    ├── section_header.dart — Section tag + title widget
    └── inclusion_chip.dart — Price tag + inclusion list item
```

## Features

- **Home Screen**: Hero, 3 service cards, how-it-works, pricing grid, 6 trust features, 4 testimonials, FAQ accordion, CTA
- **Booking Wizard**: Multi-step flow for all 3 service types with WhatsApp confirmation
- **Blog**: 8 posts with full markdown content, clickable links
- **Contact**: Call, WhatsApp, email buttons, address, social links, service areas
- **Dark theme**: Black + green (#4ADE80) brand colors throughout
