# CleanCruisers app: design system rules

Rules for turning Figma designs into code in this repo. Read this before implementing any design from Figma (via the Figma MCP server or a screenshot).

**The one rule:** Figma output is a reference, not code to paste. This is a **Flutter** app. Figma MCP returns React/Tailwind-style output; translate it into Flutter widgets built from the tokens and components below. Never add hex colours, raw font sizes or one-off paddings when a token or widget already covers them.

---

## 1. Stack

| Concern | What's used |
|---|---|
| UI framework | Flutter (Material 3, `useMaterial3: true`), Dart SDK `>=3.3.0 <4.0.0` |
| State | `flutter_riverpod` 2.x (`Provider`, `StateNotifierProvider`, `StreamProvider`) in `lib/providers/app_providers.dart` |
| Navigation | `go_router` 14 in `lib/core/router.dart`. Tabs live in a `ShellRoute` (`MainShell`); everything else is a pushed route |
| Fonts | `google_fonts`, **Manrope**, bundled in `assets/google_fonts/` (runtime fetching is off) |
| Backend | Firebase Auth (phone OTP for customers, email for staff) + Cloud Firestore (`lib/data/booking_cloud.dart`) |
| Build | Flutter tooling only (no web bundler or CSS pipeline). `flutter build web --release` / Android / iOS |
| Styling | Plain Flutter widgets + `ThemeData`. No CSS, no styled-components, no Tailwind |

There is **no Storybook**. To look at a widget, render it with the screenshot tool (section 8).

---

## 2. Design tokens: `lib/core/theme.dart`

All tokens are static Dart constants. There is no token pipeline (no Style Dictionary, no JSON); edit `theme.dart` directly. When a Figma variable has no matching token, add it to the right class here; don't inline the value.

### Colours: `AppColors`

| Token | Hex | Use |
|---|---|---|
| `brand` | `#1DE874` | Logo green. **Accents on dark backgrounds only** (fails contrast on white) |
| `primary` | `#15803D` | Buttons, links, selected states, icons on light |
| `primaryDk` | `#166534` | Text on `primarySoft` |
| `primarySoft` | `#E8F7EE` | Tinted backgrounds, selected cards, info notices |
| `ink` | `#0B0F10` | Brand black: hero headers, dark cards, splash |
| `bg` | `#F5F6F8` | Scaffold background |
| `surface` | white | Cards, sheets, inputs |
| `surfaceAlt` | `#F0F2F5` | Disabled/secondary fills, segmented-control track |
| `border` | `#E3E6EA` | Card and input borders, dividers |
| `text` / `textMuted` / `textSubtle` | `#111827` / `#4B5563` / `#6B7280` | Primary / body / captions |
| `error`, `errorSoft` | `#DC2626`, `#FEF2F2` | Errors |
| `warning`, `warningSoft` | `#B45309`, `#FFF7E6` | Warnings, "needs attention" |
| `star` | `#F59E0B` | Ratings |

### Spacing: `AppSpace`
`xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · section 32 · page 20` (`page` is the horizontal screen gutter). 8-point rhythm with 4-point half steps; snap Figma values to these.

### Radius: `AppRadius`
`sm 10 · thumb 12 (small photos in list rows) · md 14 (default card/input/button) · lg 20 (sheets, dialogs, big cards) · sheet 28 · pill 999`.

### Shadow: `AppShadow`
`card` (soft two-layer, cards) and `raised` (upward, bottom bars).

### Typography: `AppText` (Manrope)

| Style | Size / weight | Use |
|---|---|---|
| `display` | 30 / 800, line 36 | Hero headings |
| `h1` | 24 / 700 | Screen headings |
| `h2` | 22 / 700 | Section headings |
| `h3` | 18 / 700 | Card titles, step headings |
| `title` | 16 / 600 | Titles of compact cards and tiles |
| `body`, `bodyStrong` | 14 / 400, 600 | Body text, emphasised values |
| `small`, `smallStrong` | 13 / 400, 600 | Secondary text |
| `caption` | 12 / 600 | Small labels |
| `overline` | 12 / 600, tracking 1.0 | ALL-CAPS labels |
| `price` | 24 / 800 | Prices |
| `priceSm` | 18 / 800 | Prices inside dense rows and tiles |
| `button` | 16 / 700 white | Set by the button themes |
| `nav` | 12 / 500 | Bottom navigation labels (set by the theme) |

Use `AppText.x.copyWith(color: …)` to recolour. Don't build new `TextStyle`s from scratch, and don't override `fontSize`: pick the scale step instead (the only exceptions are long-form blog text and `PriceText(size:)`). Avoid stacking bold: one bold element per card is usually enough. Manrope's 700 reads lighter than most fonts, so don't bump weights to compensate.

```dart
Text('Your car', style: AppText.h2),
Text('Takes about 2 hrs', style: AppText.small.copyWith(color: AppColors.primaryDk)),
```

### Theme
`AppTheme.light` wires the tokens into Material: buttons (54 px tall, `md` radius), inputs (filled white, `border` outline, `primary` focus), app bar (flat, `bg`), navigation bar, snackbars (floating, dark), bottom sheets and dialogs (`lg` radius). Prefer themed Material widgets (`ElevatedButton`, `TextField`, `AlertDialog`) over restyling them per screen. Status-bar styles: `AppTheme.overlayDark`; use a light variant over dark heroes.

---

## 3. Component library

Shared widgets live in `lib/widgets/`. Screen-private widgets are `_Private` classes at the bottom of their screen file. **Reuse before creating.** Promote a private widget to `lib/widgets/` once a second screen needs it.

### `lib/widgets/ui.dart`: primitives

| Widget | Signature | Figma equivalent |
|---|---|---|
| `PrimaryButton` | `(label:, onPressed:, icon?, loading, expand=true, dense)` | Filled green CTA (haptic + spinner built in) |
| `SecondaryButton` | `(label:, onPressed:, icon?, expand, dense)` | Outlined button |
| `AppCard` | `(child:, padding=16, onTap?, selected, color?, radius=md)` | Any white card; `selected` = green border + tint |
| `SectionHeader` | `(title, subtitle?, actionLabel?, onAction?)` | Section title + "See all" |
| `Pill` | `(label, icon?, tone: PillTone.neutral/brand/solid/dark/warning)` | Tag / badge / status chip. The only pill shape: `solid` (filled green) for highlights, `neutral` for facts. Long labels wrap; in a `Row`, wrap it in `Expanded`/`Flexible` |
| `CheckItem` | `(text, included=true)` | ✓ / ✕ list row |
| `InfoRow` | `(icon:, label:, value:, trailing?, onTap?)` | Icon + label + value list row |
| `IconBadge` | `(icon, size=40, dark=false)` | Icon in a tinted rounded square |
| `PriceText` | `(amount, from=false, suffix='', size)` | ₹ price with "Starts at" |
| `NoticeBox` | `(icon:, text:, warning=false)` | Inline info / warning banner |
| `BottomActionBar` | `(child:, top?)` | Sticky bottom bar (price + CTA); `top` = pinned summary above the button |
| `EmptyState` | `(icon:, title:, message:, action?)` | Empty / error placeholder |
| `showMessage(context, text, action?)` | function | Snackbar / toast |

### Feature widgets

| File | Widgets |
|---|---|
| `lib/widgets/service_widgets.dart` | `ServiceImage` (photo or branded tile), `ServiceCard` (home carousel card), `ServiceRow` (list row, exact price if `car:` given), `BrandMark`, `CornerBrandMark` |
| `lib/widgets/booking_progress.dart` | `BookingProgress(status:, showLabels)` stepper; `progressIndex()`, `progressHeadline()` |
| `lib/widgets/how_it_works.dart` | `HowItWorksSteps` |
| `lib/widgets/motion.dart` | `Reveal` (fade/slide in on scroll), `KenBurns` (slow photo zoom), `PressScale` (tap shrink), `ConfettiBurst` |
| `lib/widgets/contact_actions.dart` | `openWhatsApp()` (general support only, never booking data), `openLink()`. No phone-call buttons anywhere in the app |
| `lib/widgets/customer_sheets.dart` | `AddressForm`, `showAddressSheet()` ("Where's your car?": current location, saved addresses as radio cards, blocks not-covered ones, links to `/addresses`), `showAddressForm(existing?)`, `showCarSheet()`, `addressCoverage()`, `CoverageChip` |
| `lib/widgets/offer_card.dart` | `OfferCard` (coupon ticket). Offers themselves live in `lib/data/offers.dart` |
| `lib/widgets/book_button.dart` | `BookButton(service, primary)` ("Book now"; filled when `primary`, otherwise outlined) |
| `lib/widgets/brand_header.dart` | `BrandWithAddress` (logo + wordmark + where the car is), `ParkedAtLine(withOverline)` ("Home · address ⌄", opens the address sheet), `CarPill` (car size, opens the car sheet), `RoundSurface` (bordered pill/circle for header controls) |
| `lib/widgets/trust_widgets.dart` | `WhyUsStrip(tinted)` (facts from `business_info.dart` only; `tinted` = mint background), `HelpCard(title, line, message)` (WhatsApp support) |
| `lib/screens/auth/login_screen.dart` | `CarTypePicker` (radio list: size, example models, optional price), reused by sign-up and the car sheet |
| `lib/screens/bookings_screen.dart` | `statusChip(BookingRecord)` → `(label, PillTone)`, the one place booking status words come from |
| `lib/screens/addresses_screen.dart` | `AddressesScreen` (`/addresses`); `AddressesScreen.bookingUsing()` blocks deleting an address an upcoming booking uses |

### Patterns to follow

```dart
// Card with icon row, the most common block in the app
AppCard(
  onTap: () => context.push('/service/${s.id}'),
  child: Row(children: [
    const IconBadge(Icons.local_car_wash_rounded),
    const SizedBox(width: AppSpace.md),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.name, style: AppText.bodyStrong),
      Text(s.tagline, style: AppText.small),
    ])),
    const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
  ]),
);

// Screen with sticky CTA
Scaffold(
  body: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32), children: [...]),
  bottomNavigationBar: BottomActionBar(
    child: PrimaryButton(label: 'Continue', onPressed: next),
  ),
);
```

- Every tappable custom widget gets `Semantics(button: true, label: …)`; text fields use the `_labelled()` helper pattern in `booking_steps.dart`.
- Selected state = `AppColors.primary` border/fill + `primarySoft` tint (see `CarTypePicker`, `_SlotChip`). Chips that pick one of a few (day, address label, need) are dark (`ink`) when selected.
- Light haptics on selection: `HapticFeedback.selectionClick()`.

### Business truths the screens must keep

- Payment is after the service (cash/UPI). Bills say "To pay after the service".
- A slot is a **request**; the team confirms it, "usually within 1–2 hours" (`kConfirmUsually` in `business_info.dart`). Cancel and change time are requests too (`requestCustomerChange`), never instant.
- When a slot is taken while sending, `BookingCloudException.slotTaken` is true and the flow shows other open windows.
- No ratings, reviews or expert names until they are real data (`kRatingValue` is null; bookings store only `workerId`).

---

## 4. Icons

- **Material Icons only** (`Icons.*`, built into Flutter, tree-shaken in release). Prefer the `_rounded` variants for filled glyphs and `_outlined` for line icons, matching neighbouring screens.
- No custom SVG icon set, and no `flutter_svg`. If a Figma icon has no Material match, pick the closest Material icon; only add an SVG/icon font after checking with the owner.
- Sizes in use: 18–20 inline, 22–28 in tiles, 40–46 icon containers (`IconBadge`).
- Icon colour: `AppColors.primary` on light, `Colors.white` / `AppColors.brand` on `ink`, `textSubtle` for chevrons and hints.

---

## 5. Assets

| What | Where | How |
|---|---|---|
| Photos | `assets/images/*.jpg` (~3.5 MB total, pre-compressed JPEGs) | `Image.asset('assets/images/wash_collage.jpg', fit: BoxFit.cover)`, or through `ServiceImage` |
| Logo | `assets/images/logo.png` | Also the launcher-icon source (`flutter_launcher_icons`) |
| Fonts | `assets/google_fonts/Manrope-*.ttf` (Regular, Medium, SemiBold, Bold, ExtraBold) | Loaded by `google_fonts` from the bundle; files must be named `Family-Weight.ttf` |
| Splash source art | `design/splash/` (not bundled) | Regenerate: `dart run flutter_native_splash:create` |
| Web icons | `web/icons/`, `web/favicon.png` | |

- `pubspec.yaml` registers the folders (`assets/images/`, `assets/google_fonts/`). New files dropped there are picked up without editing the pubspec.
- Name files `snake_case` by content (`card_wash_full.jpg`, `seat_shampoo.jpg`). The `card_*` files are home-card crops.
- Photos showing the team's logo are listed in `_brandedPhotos` (`lib/models/service.dart`); others get a `CornerBrandMark` overlay automatically.
- No CDN and no network images. Everything ships in the app. Export Figma images as JPEG (photos) or PNG (transparency), sized for ~3× phone width at most, compressed.

---

## 6. Styling and layout

- **No global stylesheet.** "Global styles" = `AppTheme.light` plus the tokens. Per-widget styling is via constructor params and `copyWith`.
- **Mobile-first, portrait-locked** (`main.dart`). Layouts target 360–430 px wide.
- **Text scaling:** user scale is respected but clamped to 1.3× app-wide (`main.dart`); Home clamps further to 1.15× (`MediaQuery.withClampedTextScaling` in `home_screen.dart`). Never use fixed heights or `childAspectRatio` grids for text-bearing tiles; size by content (`Wrap` + `LayoutBuilder` widths, as in `_QuickServices`). `test/layout_test.dart` fails on any overflow at 1.0× and 1.3×.
- **Responsive:** little is needed; use `LayoutBuilder` for column widths and `ConstrainedBox(maxWidth: 420–460)` on desk/web-style forms (ops screens, dialogs).
- **Important information must not hide below the fold.** Put the current selection or summary in `BottomActionBar(top: …)` (e.g. the slot summary in the booking flow).
- **Customer-facing copy:** plain language. Say "slot" and "expert arrives between 9:30 – 10:30 AM", never "arrival window", "route" or "capacity". Times via `clockLabel()` / `timeRangeLabel()` (`lib/core/scheduling.dart`), money via `rupees()`, phones via `phoneLabel()`, days via `friendlyDate()` / `addDays()` (`lib/core/format.dart`). Never do date maths with `Duration(days:)`.

---

## 7. Project structure

```
lib/
  main.dart                 app entry, theme, text-scale clamp, Firebase init
  firebase_options.dart     Firebase config from --dart-define (no keys in repo)
  core/
    theme.dart              ← design tokens + ThemeData
    router.dart             routes + OTP login gate (authRedirect)
    format.dart             rupees, dates, phone formatting
    pricing.dart            price tables, car types
    scheduling.dart         slot/route rules engine (pure Dart, unit-tested)
    constants.dart          phone, WhatsApp, links
  data/
    business_info.dart      business facts shown to customers (hours, city, areas)
    booking_cloud.dart      Firestore/Auth repository
    blog_data.dart
  models/                   booking.dart, service.dart (catalog), worker.dart, blog_post.dart
  providers/app_providers.dart
  widgets/                  ← shared components (section 3)
  screens/
    auth/                   login, OTP, name
    booking/                3-step booking flow: Extras (skipped when none) → Pick a time → Review (booking_flow_screen + booking_steps)
    ops/                    staff booking desk (board, queue, roster, capacity)
    home, services, service_detail, bookings, booking_detail, booking_sent, profile, wallet (Offers), addresses, blog, splash
test/
  *_test.dart               unit, behaviour and layout tests (run with `flutter test`)
  fixtures.dart             shared customer/booking data for tests and screenshots
  screenshots/              visual review tool (not part of the normal test run)
docs/                       setup and business docs
```

Feature pattern: a screen file owns its layout and private sub-widgets; data comes from Riverpod providers; business rules live in `core/` or `models/` as pure Dart so they can be tested.

---

## 8. Figma → code workflow for this repo

1. Get the design (`get_design_context` / `get_screenshot`) and map every colour, text style, radius and spacing to the tokens in section 2.
2. Map each Figma component to an existing widget (section 3). Only create a new widget if nothing fits. Put it in `lib/widgets/` if it's shared, otherwise as a `_Private` class in the screen file.
3. Icons → closest `Icons.*` (section 4). Images → `assets/images/` (section 5).
4. Write customer copy in plain language (section 6).
5. Verify:
   - `flutter analyze` (must be clean)
   - `flutter test` (layout tests catch overflow at 130 % text)
   - Visual check: `flutter test test/screenshots/screens_dev.dart --dart-define=ONLY=home,flow3`, with `SHOTS_DIR` set to an output folder. It writes `<name>_fold.png` (what a phone shows without scrolling) and `<name>_full.png` with real fonts. Compare them against the Figma frame. Add `--dart-define=WIDTH=360 --dart-define=TEXT_SCALE=1.15` to check a small phone with large text.
