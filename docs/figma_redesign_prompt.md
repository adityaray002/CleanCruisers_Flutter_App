# CleanCruisers: Figma redesign prompt

Paste everything below the line into Figma (Figma Make / First Draft / any AI design tool), or hand it to a designer as the brief. It is written so each part can also be pasted on its own: the **system** first, then one **screen** at a time.

---

## 0. Your role and the one goal

You are a senior product designer redesigning **CleanCruisers**, an Android/iOS app for **doorstep car washing in Delhi NCR**. The team comes to where the customer's car is parked and washes it there.

**The one goal of this redesign: more customers finish a booking, and nobody is confused on the way.** Every screen is judged by two questions:

1. Can a first-time customer understand this screen in 3 seconds?
2. Does it move them one step closer to "Request slot"?

If an element answers neither, remove it.

Design for a mass-market Indian audience on mid-range Android phones (360–412 px wide), often one-handed, sometimes in sunlight, many reading English as a second language. Plain words beat clever words.

---

## 1. Product facts (never contradict these)

- **What we do:** car wash and detailing at the customer's home or office parking.
- **Payment:** customer pays **after** the service, cash or UPI. **The app takes no payment.** Never show a card form, "Pay now", or a wallet top-up.
- **Booking is a request:** the customer picks a time slot, taps **"Request slot"**, and the team **confirms it in the app**. Never say "Booked!" or "Confirmed" before the team confirms. States: Requested → Confirmed → On the way → Cleaning → Done (also: Team checking, Pick a new time, Cancelled, Couldn't take this booking).
- **Time:** slots are 1-hour windows, e.g. "9:30 – 10:30 AM". Once confirmed, the app may also show a likely arrival, e.g. "Likely around 9:55 AM". The window is the promise; the arrival time is a hint.
- **Hours:** all 7 days, 8 AM – 6 PM.
- **Customer must provide:** a water tap and a plug point near the car. The team brings 30 m cords and pipes, chemicals and cloths.
- **Car types (price depends on it):** Hatchback, Sedan, SUV, Luxury.
- **Since 2020.** Service areas: Dwarka, Janakpuri, Uttam Nagar, Vikaspuri, Paschim Vihar, Rohini, Pitampura, and parts of West, South, East and New Delhi.
- **Cancel and reschedule:** the customer can cancel or reschedule from the booking. Cancelling is free up to 4 hours before the slot; cancelling within 2 hours of the slot, or after the expert has left, adds a ₹100 fee to the next booking. In bad weather the team can put a booking on hold and ask the customer to pick a new slot (priority reschedule).
- **Support:** WhatsApp chat only. **No phone-call buttons anywhere.**
- **No ratings, review counts or "10,000+ customers" claims.** These are not verified yet. Leave a clearly marked, empty slot for a future "Reviews" block, but don't fill it with fake numbers or names.
- **Login:** phone number + OTP. Then name, car type and address once. After that, nothing is typed again.

### Prices (₹, per car type: Hatchback / Sedan / SUV / Luxury)

**Washes**

| Package (customer-facing name) | Internal name | Time | H | S | SUV | L |
|---|---|---|---|---|---|---|
| Full wash (Most booked) | Exterior + Interior Wash | 1.5–2.5 hrs | 449 | 499 | 549 | 549 |
| Outside only | Exterior Wash | 1 hr | 349 | 349 | 399 | 399 |
| Inside only | Interior Clean | 1 hr | 349 | 349 | 399 | 399 |
| Quick bucket wash | Bucket Wash | 1 hr | 249 | 249 | 299 | 299 |

Wash add-ons: Seat cleaning ₹100 per seat (up to 7) · Roof cleaning ₹200 · Door and dashboard shampoo ₹250 · AC vent and foam cleaning ₹250 · Air freshener ₹149.

**Detailing**

| Package | Time | H | S | SUV | L |
|---|---|---|---|---|---|
| 3M Wax + Foam Wash | 2 hrs | 649 | 649 | 749 | 949 |
| Interior Dry Cleaning | 3 hrs | 999 | 999 | 1,099 | 1,099 |
| Dry Cleaning + 3M Wax | 4–4.5 hrs | 1,499 | 1,499 | 1,699 | 1,799 |
| Rubbing + Foam Wash | 3 hrs | 1,599 | 1,599 | 1,799 | 1,899 |
| Rubbing + 3M Wax | 2–3 hrs | 1,699 | 1,699 | 1,899 | 1,999 |
| Rubbing + Dry Cleaning | 5 hrs | 2,199 | 2,199 | 2,399 | 2,499 |
| Full Detailing Package (Complete care) | 5 hrs | 2,499 | 2,499 | 2,699 | 2,799 |

**Monthly plans**

| Plan | H | S | SUV | L |
|---|---|---|---|---|
| Monthly Plan · 3 full washes (Best value) | 1,399 | 1,499 | 1,599 | 1,599 |
| Monthly Bucket Wash · 4 washes | 799 | 799 | 999 | 1,199 |

**Live offers**

- `FIRST100`: ₹100 off, first booking only
- `WEEKDAY40`: ₹40 off any wash, min. bill ₹449
- `SUVSPECIAL`: 10% off, SUVs only

Offers are coupon codes the customer applies on the booking page. Tap a code anywhere to copy it.

---

## 2. Design principles (in priority order)

1. **One primary action per screen.** It's always a full-width green button pinned to the bottom (thumb zone). Never two green buttons on one screen.
2. **Show the exact price early.** As soon as the car type is known, show "₹449", never "from ₹249". Keep the selected price visible next to the main button.
3. **Pre-select the likely answer.** Default to the customer's saved car and the "Most booked" package. A returning customer should be able to book in 2 taps.
4. **Remove fear before it appears.** "Pay after the service" sits next to every booking button. "We confirm your slot in the app" sits next to "Request slot".
5. **Plain language, one idea per line.** "Outside only", not "Exterior detailing". Max ~40 characters per line of body copy.
6. **Real photos of real work only.** Team in black polo and cap with the CleanCruisers logo, real cars, Indian residential parking. No stock-smiling models, no 3D renders, no illustrations of cars.
7. **Calm, not loud.** One accent colour, generous white space, no gradients behind text, no confetti except on "Booking requested".

---

## 3. Visual system: build this first, as Figma variables and styles

### 3.1 Colour variables (collection "CC / Color", one mode: Light)

| Variable | Hex | Use |
|---|---|---|
| `brand/neon` | #1DE874 | Logo green. **Only on dark (ink/forest) backgrounds**: CTA on dark hero, highlights. Fails contrast on white: never use on white. |
| `brand/primary` | #15803D | Primary buttons, links, selected states, icons on light |
| `brand/primary-dark` | #166534 | Text on `brand/primary-soft` |
| `brand/primary-soft` | #E8F7EE | Selected card fill, info notices, tinted chips |
| `ink` | #0B0F10 | Dark hero, dark cards, number badges |
| `forest` | #083322 | Secondary dark (hero overlays, dark pills) |
| `bg/page` | #F5F6F8 | Screen background |
| `bg/surface` | #FFFFFF | Cards, sheets, inputs, bottom bars |
| `bg/surface-alt` | #F0F2F5 | Neutral chips, segmented-control track, disabled fills |
| `border/default` | #E3E6EA | Card and input borders, dividers |
| `text/primary` | #111827 | Headings and body |
| `text/secondary` | #4B5563 | Supporting text (passes 4.5:1 on white and on bg/page) |
| `text/tertiary` | #5A6270 | Captions, chevrons, hints |
| `text/on-dark` | #FFFFFF | Text on ink |
| `text/on-dark-muted` | #B8C0C7 | Secondary text on ink |
| `status/warning` / `warning-soft` | #B45309 / #FFF7E6 | "Pick a new time", attention states |
| `status/error` / `error-soft` | #DC2626 / #FEF2F2 | Errors, "not in service area" |

Rule: every text/background pair must pass WCAG AA (4.5:1 body, 3:1 for 18 px+ bold). Don't use `brand/neon` for text on white or `bg/page`.

### 3.2 Typography: Manrope only (Google Fonts)

Create these as text styles. Sizes are fixed; don't invent in-between sizes.

| Style | Size / line height | Weight | Use |
|---|---|---|---|
| Display | 30 / 36 | ExtraBold 800 | One per screen max, hero headline |
| H1 | 24 / 30 | Bold 700 | Screen titles |
| H2 | 20 / 26 | Bold 700 | Section titles |
| H3 | 18 / 24 | Bold 700 | Card titles |
| Title | 16 / 22 | SemiBold 600 | Compact card and list titles |
| Body | 14 / 20 | Regular 400 | Body text |
| Body strong | 14 / 20 | SemiBold 600 | Emphasised values |
| Small | 13 / 18 | Regular 400 | Secondary text |
| Caption | 12 / 16 | SemiBold 600 | Labels, chips, meta |
| Price | 24 / 28 | ExtraBold 800 | Price beside the main button |
| Price small | 18 / 22 | ExtraBold 800 | Prices in cards and rows |
| Button | 16 / 20 | Bold 700 | Buttons |
| Nav | 12 / 16 | Medium 500 | Bottom nav labels |

Nothing smaller than 12 px. Sentence case everywhere ("Book a service", not "Book A Service"). ALL CAPS only for tiny overline labels, 12 px, letter-spacing 1.

### 3.3 Spacing, grid, radius, elevation

- **Spacing variables:** 4, 8, 12, 16, 20, 24, 32. Use auto layout gap and padding only from this set.
- **Screen gutter:** 20 px left/right (16 px on screens with 2-up tiles).
- **Layout grid on every frame:** 4 columns, 20 px margin, 12 px gutter; plus an 8 px baseline row grid.
- **Radius:** 10 (small chips, inputs inside cards), 12 (thumbnails), 14 (buttons, default cards), 20 (large cards, sheets top corners), 28 (bottom sheet), 999 (pills).
- **Elevation:** `shadow/card` = 0 1 2 rgba(11,15,16,.06) + 0 4 12 rgba(11,15,16,.06). `shadow/raised` (bottom bars) = 0 -8 24 rgba(11,15,16,.08). Selected cards get no shadow, but a 2 px `brand/primary` border.

### 3.4 Icons

Material Symbols **Rounded**, outline style, 2 px weight. Sizes 20 (inline), 24 (tiles), 40–44 (icon containers with `primary-soft` fill, 12 px radius). Icon colour `brand/primary` on light, `brand/neon` or white on ink.

### 3.5 Photography

- Real job photos: team member in black CleanCruisers polo and cap, kit bag with logo, foam on real cars in apartment parking.
- Crop rules: 16:9 for hero, 4:3 for package cards, 1:1 (12 px radius) for list thumbnails.
- Text never sits directly on a busy photo: use a solid ink panel, or a bottom-to-top ink scrim (0% → 85%) under the text.
- Before/after: one photo split down the middle, "Before" pill (ink 75%) bottom-left, "After" pill (`brand/neon` on ink text) bottom-right.

---

## 4. Figma file setup

**Pages:** `00 Cover` · `01 Foundations` (variables, type, spacing, icons, photo rules) · `02 Components` · `03 Customer flows` · `04 States` (empty/loading/error per screen) · `05 Prototype` · `99 Archive`.

**Frames:** design at **390 × 844** (base). Duplicate every key screen at **360 × 800** with text at 115% to prove nothing breaks. Name frames `Area / Screen / State`, e.g. `Booking / Choose slot / Default`.

**Rules for every frame:**

- 100% auto layout. No absolutely positioned elements except overlays (badges on photos, sticky bottom bar, floating pill).
- Text layers never use a fixed height. Every text box must reflow when copy grows by 30%.
- Status bar: plain system status bar placeholder (no fake carrier names or battery icons in brand colours).
- Bottom safe area: 16 px under the bottom bar or nav.
- Touch targets ≥ 48 × 48 px.

---

## 5. Component library (page `02 Components`)

Build each as a component set with the variants and properties listed. Use component properties (boolean, text, instance swap) instead of separate copies.

1. **Button**: Variant: `Primary` (primary fill, white text) · `Primary on dark` (neon fill, ink text) · `Secondary` (white, 1.5 px primary border, primary text) · `Ghost` (text only). Size: `Large 54` / `Medium 44` / `Small 36`. State: Default / Pressed / Loading (spinner replaces label) / Disabled. Props: label (text), leading icon (bool + swap), trailing arrow (bool).
2. **Sticky action bar**: white, top border, `shadow/raised`. Left: price (Price style) + one-line summary (Caption, secondary). Right: Primary Large button filling the rest. Optional slot above: a notice pill (e.g. "Pay after the service, cash or UPI"). Variants: `Price + button`, `Button only`, `With notice`.
3. **Car type selector**: 4 equal tiles in a row (car silhouette icon, name, "₹449" price line). State per tile: Default / Selected (primary-soft fill, 2 px primary border, primary-dark text). Prop: show price (bool).
4. **Package option (radio card)**: photo 64 × 64 (12 radius) · name (Title) · "Most booked" pill (bool) · one-line what's included (Small, secondary) · duration · price (Price small) · radio. State: Default / Selected (2 px primary border, soft green shadow).
5. **Package card (large)**: 4:3 photo with badge and duration pills · name (H3) · up to 4 ticks in 2 columns · divider · price + "for Hatchback" + Book button. Variants: Featured / Normal.
6. **List row**: thumbnail or icon badge · title · subtitle · trailing (chevron / price / switch / text button). Variants: with thumbnail, with icon, with value.
7. **Booking status card**: status overline ("Confirmed · Tomorrow, 14 Nov") · headline ("Expert arrives 9:30 – 10:30 AM") · sub-line ("Likely around 9:55 AM · Full wash") · 5-dot progress (done / current / upcoming) · optional labels row. Variants by status: Requested, Team checking, Confirmed, On the way, Cleaning, Done, Pick a new time (warning), Cancelled (neutral).
8. **Slot chip**: "9:30 – 10:30 AM". States: Available / Selected / Few left (warning dot) / Unavailable (struck, disabled). Day chip: "Today", "Tmrw", "Sat 16".
9. **Offer ticket**: icon · "₹100 off" (Body strong) · condition line · dashed code box ("FIRST100") · "Tap to copy". Variants: Green / Amber. State: Default / Copied ("Code copied").
10. **Pill / badge**: Solid green, Soft green, Neutral, Dark-on-photo, Warning. With/without leading icon.
11. **Notice box**: icon + text, Info (primary-soft) / Warning (warning-soft) / Error (error-soft).
12. **Input**: label above, 54 px field, white, 1 px border, 14 radius, focus = 2 px primary. Variants: Text, Phone (+91 prefix), OTP (6 boxes), Search, Multiline. States: Empty / Filled / Focus / Error (message below).
13. **Bottom sheet**: 28 px top radius, drag handle, title (H3), content, optional sticky button.
14. **Bottom navigation**: 4 items: Home, My Bookings, Offers, Profile. Active item = soft green pill behind icon + primary label. Optional dot badge on My Bookings.
15. **Header**: Variant `Home` (logo 36 + "Car parked at" overline + address with chevron + bell) and `Page` (back button 44 circle + title + optional trailing action).
16. **Stepper (booking progress)**: "Step 2 of 3" + 3 segment bar. Used only inside the booking flow.
17. **Before/after card**, **How-it-works row** (3 numbered steps, the 3rd highlighted green: "Pay after we finish"), **Empty state** (icon in 64 circle, title, one line, one button), **Skeleton loaders** for cards and rows, **Snackbar** (ink, white text, optional action), **WhatsApp help row**.

---

## 6. Screens

For each screen: design **Default**, plus every state listed. Always include the sticky action bar where noted.

### 6.1 Splash
Logo centered on white (or ink), app name below, nothing else. 1.5 s max.

### 6.2 Login (phone)
- H1 "Car wash at your door". Sub-line "Log in with your phone number".
- One Phone input (+91 fixed). Primary button "Get OTP" in the sticky bar.
- Small trust row under the field: "Pay after the service · All 7 days, 8 AM – 6 PM".
- Small text link at the bottom: "Staff login" (secondary, not prominent).
- States: invalid number error, sending (loading button).

### 6.3 OTP
- "Enter the 6-digit code sent to +91 98765 43210" with an "Edit" link.
- 6-box OTP input, auto-advance. "Resend code in 0:24" → "Resend code".
- Button "Verify". States: wrong code, expired code.

### 6.4 Name → Car → Address (one-time setup, 3 short steps)
- Use the Stepper "Step 1 of 3".
- **Name:** one input "Your name".
- **Car:** Car type selector (no prices yet) + optional "Car model (e.g. Swift)" input.
- **Address:** "Use my current location" button (primary-soft row) or "Add address manually" (house/flat, area, landmark). Label chips: Home / Office / Other. Show coverage result: green notice "We wash cars here" or red "We don't wash cars here yet" + list of areas.
- Every step: one button "Continue". Allow "Skip for now" only on the car model and number.

### 6.5 Home (most important screen), book-first

The home screen *is* the start of the booking. Two layouts by customer state:

**A. New or returning customer with no booking in progress**
1. Header (Home variant): logo · "Car parked at / Home, Janakpuri ⌄" · bell.
2. Headline block: Display "Car wash at your door." + second line in primary green "Pay after it's done." + 2 ticks: "We bring the kit" · "7 days, 8 AM – 6 PM".
3. **Step 1 · Your car**: Car type selector, saved car pre-selected.
4. **Step 2 · Choose a wash**: 4 Package option radio cards (Full wash pre-selected with "Most booked", Outside only, Inside only, Quick bucket wash), each with its **exact price** for the selected car.
5. Dashed row: "Need wax, polish or a deep clean? Detailing from ₹649 · Monthly plans from ₹799 ›".
6. **Returning customers only**, above step 1: "Book again" card: last package, car, "last done 2 Nov", exact price, and a Secondary button "Book again".
7. Below the fold: "What happens next" (1 Pick a time · 2 We confirm and an expert comes · 3 **Pay only when you're happy**), before/after card, WhatsApp help row ("Not sure what to pick? Chat with us").
8. **Sticky action bar (always visible):** notice "First booking? Use FIRST100 for ₹100 off" (new customers only) · "₹449 / Full wash · Hatchback" · **"Pick a time →"** · tiny line "No payment now. Pay the team after the wash."

**B. Booking in progress**
1. Header.
2. Full-width **Booking status card** on ink: "CONFIRMED · TOMORROW, 14 NOV" (neon dot), "Your expert arrives", Display "9:30 – 10:30 AM", "Likely around 9:55 AM · Full wash", 5-step progress with labels, two buttons: "View booking" (Primary on dark) + "Chat with us" (outline on dark).
3. Below: the same car + wash picker as layout A, titled "Book another car".
4. Status-specific copy: Requested: "We're confirming your slot. You'll see it here." · Pick a new time (warning card): "Your slot is full. Pick a new time." + button "Pick a new time".

States to design: no address yet (address sheet opens over home), address not covered (error notice under header, booking button disabled with reason), loading skeleton, offline.

### 6.6 All services (category list)
- Page header "All services". Segmented control: Wash · Detailing · Monthly.
- Car type selector at top (prices follow it).
- Wash: the 4 radio cards (same as home). Detailing: Package cards (large) with exact price. Monthly: 2 plan cards; the 3-wash plan has "Best value" and a short "what you get" list (3 full washes, free dustbin, air freshener).
- "Compare what's included" opens a bottom sheet comparison table (rows = inclusions, columns = packages, ✓ / –).
- Sticky bar appears once a package is selected.

### 6.7 Package detail
- 16:9 photo with badge and duration. Name (H1), one-line summary.
- "What's included" ticks list. "Not included" list (grey ✕) with the alternative named, e.g. "Seat cleaning (available as an extra)".
- "Best for" one line in a soft-green notice.
- "Before you book" box: "Keep a water tap and plug point ready. We bring 30 m cords and pipes."
- Car type selector (exact price). Sticky bar: price + "Book this".

### 6.8 Booking flow (3 steps, one screen each, Stepper on top)
**Step 1: Extras (skippable).** Selected package summary card at top (photo, name, price, "Change"). Add-ons as list rows with steppers or switches (Seat cleaning ₹100 × seats, Roof ₹200, Door and dashboard shampoo ₹250, AC vent ₹250, Air freshener ₹149). Running total in the sticky bar. Button "Continue" (or "Skip extras").

**Step 2: Pick a time.** Day chips row (Today, Tmrw, next 5 days). Slot chip grid grouped Morning / Afternoon. "Few left" and "Unavailable" states. Note: "We confirm your slot in the app". Button "Continue" disabled until a slot is picked; when tapped without a slot, scroll to slots and show "Pick a time to continue".

**Step 3: Review and request.**
- Summary card: car (model · type), address (with "Change"), package + extras, date and slot.
- Coupon row: "Apply coupon" → bottom sheet listing eligible offers with "Apply"; applied state shows "FIRST100 applied · −₹100" with remove ✕.
- Bill: package, extras, coupon, **Total to pay after service**.
- "Before you request" box (3 rows): We confirm your slot in the app · Keep a water tap and plug point ready · Pay after the wash, cash or UPI.
- Optional "Booking for someone else?" toggle → name + phone.
- Sticky bar: "₹349 / pay after service" + **"Request slot"**.
- States: sending (loading), failed ("Couldn't send your request. Try again."), slot just got full (warning, back to step 2).

### 6.9 Booking requested (success)
- Big check animation (one-time, subtle confetti), H1 "Slot requested", body "We'll confirm it in the app, usually within [X] minutes." (leave [X] as a placeholder).
- Status card (Requested). Booking ref "CC-7K4Q2X9M" with copy icon.
- Buttons: "View booking" (Primary) and "Back to home" (Ghost).

### 6.10 My bookings
- Tabs: Upcoming · Past.
- Upcoming: Booking status cards (compact). Past: list rows (package, date, price, status pill) + "Book again" text button per row.
- Empty state: icon, "No bookings yet", "Your car wash bookings show up here.", button "Book a wash".

### 6.11 Booking detail
- Status card with full 5-step progress and labels; history timeline below (time + note per status).
- Expert section when assigned (first name, "Arrives between 9:30 – 10:30 AM"). No call button; "Chat on WhatsApp" only.
- Details: car, address with map pin, package, extras, bill, ref.
- Actions by status: Requested/Confirmed → "Reschedule" (Secondary) and "Cancel booking" (destructive text button). Both open one bottom sheet "Cancel or reschedule" that shows the policy in plain words ("Free to cancel until 4 hours before your slot") and, for cancel, a reason picker. Weather hold / Pick a new time → warning card "Rain expected. Pick a new time and you get priority." + "Pick a new time" primary. Done → "Book again" primary.

### 6.12 Offers
- List of Offer tickets with conditions ("Min. bill ₹449", "SUV only", "First booking only"). Ineligible offers shown greyed with the reason ("For your first booking only").
- Copy state feedback via snackbar "Code FIRST100 copied".

### 6.13 Profile
- Header card: name, phone, edit.
- Rows: My car (type + model), Saved addresses (Home/Office/Other), Help on WhatsApp, Car care tips (blog), About us, Terms, Privacy, Log out (destructive, confirmation sheet).

### 6.14 Address sheet (used everywhere)
- Title "Where's your car?". Rows: "Use my current location" (primary), saved addresses with label chip and coverage chip ("We wash here" / "Not covered yet"), "Add a new address". Selected address = radio.

### 6.15 Car care tips (blog list + article)
- List: 16:9 thumbnail, title (Title), read time. Article: H1, hero photo, body at 16/26, a "Book a wash" card at the end.

---

## 7. Copy rules

- Sentence case, no exclamation marks except "Slot requested" success. No "please", no "successfully", no "kindly".
- Buttons are verbs, 1–3 words: "Pick a time", "Request slot", "Book again", "Apply", "Chat with us".
- Times: "9:30 – 10:30 AM" (en dash with spaces). Money: "₹1,399" (Indian grouping), "/month" for plans.
- Say "slot", "expert", "pay after the service". Never "arrival window", "route", "capacity", "technician".
- Errors say what happened + what to do: "That code has expired. Request a new one."
- Keep every label ≤ 2 lines at 360 px with 115% text.

---

## 8. Accessibility and quality bar

- Contrast AA for every pair (check with a contrast plugin; `brand/neon` only on ink/forest).
- Touch targets ≥ 48 px; 8 px minimum between adjacent targets.
- Don't use colour alone for state: selected = border + fill + radio dot; unavailable slot = struck text + "Full".
- Every icon-only button gets a visible tooltip/label note for developers (e.g. "Booking updates").
- Test each key screen at 360 × 800 with 115% and 130% text scale: no truncation of prices or button labels.

---

## 9. Prototype (page `05 Prototype`)

Wire these flows with Smart Animate (200 ms, ease-out):

1. **First booking:** Splash → Login → OTP → Name → Car → Address → Home (A) → change car type (prices update) → Pick a time → Extras → Slot → Review → apply FIRST100 → Request slot → Slot requested → View booking.
2. **Repeat booking in 2 taps:** Home with "Book again" → Book again → Review (slot step pre-focused) → Request slot.
3. **Status follow-up:** Home (B, Confirmed) → View booking → Chat with us.
4. **Recovery:** Booking detail (Pick a new time) → Slot → Request.

---

## 10. Deliverables

1. Foundations page with all variables and styles, documented.
2. Component library with variants and properties as listed, each with a short usage note.
3. All screens in section 6 at 390 × 844, key screens also at 360 × 800, every listed state.
4. Clickable prototype for the 4 flows.
5. A one-page "Redlines" frame for Home and Review: spacing, type styles and colour variables annotated for developers (the app is built in Flutter; tokens above map 1:1 to the code).

## 11. Don'ts

- No fake reviews, ratings, customer counts, "trusted by" logos or countdown timers.
- No "Pay now", card forms, wallets with balance top-ups, or phone-call buttons.
- No "from ₹X" once the car type is known.
- No more than one primary green button per screen.
- No gradients behind body text, no glassmorphism, no emoji in UI, no stock 3D cars.
- No carousels for anything the customer needs to see (prices, packages, status).
- Don't hide the price, the "pay after" promise or the main button below the fold.
