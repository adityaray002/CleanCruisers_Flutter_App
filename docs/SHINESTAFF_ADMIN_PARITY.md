# Customer app ↔ ShineStaff admin: full parity spec

Status: draft for owner review, 17 Nov 2026. No code has been changed yet.

## Goal

Every promise, rule and action the customer sees in the CleanCruisers app must have a matching, working
counterpart in the ShineStaff admin panel. Nothing the customer sees may be untrue, and nothing the
customer can do may go nowhere.

Rule for every row below: **the server (ShineStaff) is the source of truth.** The app only shows what
ShineStaff says and sends requests to it. Anything that today lives only on the customer's phone
(wallet, coupon checks) must move to the server, or the admin can't see it and it can be faked.

Sources read: the app (`lib/models/booking.dart`, `lib/models/service.dart`, `lib/data/offers.dart`,
`lib/providers/app_providers.dart`, `lib/screens/booking_detail_screen.dart`, `lib/core/scheduling.dart`)
and ShineStaff (`backend/src/models/Job.ts`, `User.ts`, `CustomerContact.ts`, `Payment.ts`, `Settings.ts`,
`controllers/jobController.ts`, `routes/jobRoutes.ts`, `index.ts`).

Legend: ✅ exists in ShineStaff · 🟡 partly exists · ❌ missing.

---

## A. Decisions the owner must make first

These change what gets built. Each has a recommendation.

| # | Decision | Options | Recommendation |
|---|---|---|---|
| A1 | Slot size | App today: 8 one-hour arrival windows (8:30 AM – 4:30 PM). ShineStaff: 4 three-hour slots (8–11, 11–2, 2–5, 5–8). | One list, owned by ShineStaff (Settings), used by both. If you want one-hour arrival windows, ShineStaff capacity must count them by overlap with worker jobs (it already has `slotsOverlap`). |
| A2 | Price list | App has its own price table per car size. ShineStaff has no service catalog (title and price are typed by hand). | Add a CleanCruisers service catalog to ShineStaff (services, car-size prices, extras, durations). App reads it from the server. Server recalculates every price. |
| A3 | Coupons (FIRST100, WEEKDAY40, SUVSPECIAL) | Today checked only on the phone. | Coupons live in ShineStaff: admin can create, pause and see uses. Server checks "first booking only" by phone number. |
| A4 | CleanCredit wallet | Today stored only on the phone (SharedPreferences). Reinstalling the app wipes it; admin can't see it. | Either a real server-side ledger that admin can see and adjust, or **hide CleanCredit until it is real**. |
| A5 | Monthly plans (3 washes / 4 bucket washes a month) | ShineStaff has no plan or visit-credit tracking. | Plan record per customer with visits used/left, managed by admin; each visit is a Job linked to the plan. Or sell plans only after this exists. |
| A6 | Late cancellation fee ("adds ₹100 to your next booking") | Nothing in ShineStaff applies it. | Admin marks "late cancel fee" on the cancelled job; the server adds it to the next booking's bill. Or remove the promise from the app. |
| A7 | Service areas (covered / not covered) | App uses polygons from Firestore. ShineStaff has none. | Admin-managed service areas in ShineStaff (start with pincode list, simpler than polygons). |
| A8 | "Booking for someone else" updates to recipient | App collects recipient phone and consent. ShineStaff sends no customer messages for job status. | Store recipient and consent on the Job; send status messages only once a message channel is chosen (WhatsApp template). Until then, don't promise updates. |

---

## B. Parity matrix

### B1. Account and profile

| Customer side (app) | Admin must see / do | ShineStaff today | Work |
|---|---|---|---|
| Logs in with phone OTP (Firebase Auth) | Trust that the phone on a booking is verified | ❌ no customer accounts | Verify the Firebase ID token on every app request; take phone from token, never from the request body |
| Name, car type, car model | See them on the job | 🟡 `clientName`; no car fields | Add `carType`, `carModel` to Job |
| Saved addresses with map pin | See address + pin; open in maps | ✅ `address`, `landmark`, `location {lat,lng}` | Map app fields into these |
| Customer appears in CRM | Same customer list | ✅ `CustomerContact` synced on job create | Call `syncCustomerAndScheduleReminder` for app jobs too |

### B2. Catalog, prices, extras

| Customer side | Admin | ShineStaff today | Work |
|---|---|---|---|
| Wash packages, detailing packages, monthly plans, prices per car size | Edit services and prices in one place | ❌ free-text `title`, `price` | Service catalog (A2) |
| Extras with quantity (e.g. seats) | See each extra, qty, price | ❌ | `extras: [{name, qty, price}]` on Job |
| Service duration (some flagged "time to confirm", e.g. air freshener) | See duration; confirm unknown ones | 🟡 `estimatedDuration` string | Store minutes; flag `durationNeedsConfirmation` |
| Price shown = price charged | Bill matches | ❌ (admin types price) | Server computes total; job stores price breakdown |

### B3. Booking request

| Customer side | Admin | ShineStaff today | Work |
|---|---|---|---|
| Picks date + slot; past and full slots hidden | Same availability the admin sees | 🟡 `getSlotAvailability` (admin-only, shows worker names) | Customer endpoint returning only open/closed per slot; respects weekly off, leave, emergency buffer |
| Admin can close a date or slot / cap it | Close or cap from admin | ❌ | Closures and caps in Settings, with reason |
| "Request sent" — not confirmed yet | New request appears as unassigned, needing action | ✅ unassigned job, status `pending` | Mark `source: 'app'`; "App requests" filter + alert (socket/push) to admin |
| Double tap / bad network creates one booking | — | ❌ | `appRef` unique on Job; retry returns the same job |
| Slot taken while sending → app shows other slots | — | 🟡 fleet-capacity check exists for unassigned jobs | Return a clear "slot taken" error code |
| "Usually confirmed within 1–2 hours" | See how long each request has waited; overdue flag | ❌ | Waiting-time badge; overdue after a target set in Settings |
| Booking for someone else (recipient name/phone, consent) | See booker and recipient separately | 🟡 `alternatePhone` only | `recipientName`, `recipientPhone`, `notifyRecipient`, `consentAt` |
| Covered / not covered / unverified address | See coverage; tick "address verified" before confirming | ❌ | A7 + `coverage` field + verify step |
| Coupon applied | See code and discount | ❌ | A3 |
| CleanCredit used | See amount used | ❌ | A4 |
| Notes for the team (parking etc.) | See notes | ✅ `notes`, `specialInstructions` | Map |

### B4. Status the customer sees

| App status | Meaning to customer | ShineStaff state that drives it | Gap |
|---|---|---|---|
| Requested | Sent, waiting | job unassigned, `pending` | — |
| Team review | Team looking at it | ❌ | Admin action "In review" (or drop this status from app) |
| Confirmed | Slot is yours | worker assigned (`pending`/`accepted`) | Decide: confirm on assign, or only after worker accepts. Recommendation: on assign. |
| On the way | Expert is coming | ❌ (no state between accepted and started) | Worker/admin action "On the way" |
| In service | Wash running | `started` | — |
| Reschedule needed | Team offered another time / weather | `postponed`, `pending_reschedule`, `rescheduled` | Offered date + slot fields (B5) |
| Completed | Done | `completed` | — |
| Cancelled | Cancelled | `cancelled` | — |
| Unable to serve | Rejected (area, car type…) | ❌ | Admin "Reject request" with reason shown to customer |
| Worker rejected job | Customer must **not** see this | `rejected` | Map to "Requested"/"Team review" and flag admin to reassign |
| Waitlist | — | `waitlist` | Map to "Requested" |

Every change must add a timeline entry with time and a customer-visible note. ✅ `timeline` exists; add a
`customerNote` flag so internal remarks are never shown to the customer.

### B5. Customer change requests and team replies

| Customer action (app) | Admin must | ShineStaff today | Work |
|---|---|---|---|
| Request cancellation, with optional reason; policy: free until 4 h before, ₹100 within 2 h | See request + reason + time left; approve; apply fee if due | 🟡 `cancelReason`, `cancelJob` | `customerRequest {kind, reason, at}`; banner + approve button; fee (A6) |
| Request another day/slot | See requested date/slot; accept or counter-offer | 🟡 `preferredDate`, `preferredTimeSlot`, `contactStatus` | Accept → moves job (capacity re-checked); counter → offer (next row) |
| Team offers another time → customer taps "Take the new slot" | Offer a slot; see when the customer accepts | ❌ | `offeredDate`, `offeredSlot`; accept endpoint moves the job and re-checks capacity |
| Rain: "My car is in covered parking, keep the wash" | See this answer before rescheduling | 🟡 `rescheduleCategory: 'rain'` | Store answer as customer request |
| Message from team shown on booking | Type a message to the customer | ❌ | `customerNote` field + history |

### B6. Visit, payment, after the visit

| Customer side | Admin | ShineStaff today | Work |
|---|---|---|---|
| "Pay after the service", cash or UPI | Record amount and method | ✅ `paymentStatus`, `paymentMode`, `Payment` model | Map; show "Paid" in app |
| Bill: service + extras − coupon − credit | Same bill | ❌ | Price breakdown on Job (B2) |
| Worker name/photo on the booking | — | ✅ worker on job | App rule today: no expert names until real. Decide whether to show first name. |
| Before/after photos | Already captured | ✅ `beforePhoto`, `afterPhotos` | Optional: show in app after completion |
| Repeat booking ("Book again") | — | — | App only; reads past jobs by phone |
| Ratings | Exists on Job | ✅ `rating` | App rule: no ratings shown publicly until real. Collecting is fine. |

### B7. Notifications and support

| Customer side | Admin | ShineStaff today | Work |
|---|---|---|---|
| Bell / status updates in app | — | ❌ customer channel | Phase 1: app refreshes every ~30 s + pull to refresh. Later: push (FCM) |
| WhatsApp "Chat with us" = general support only | — | ✅ separate | No booking details in the link (already true) |

---

## C. Things that are wrong or unsafe today and must be fixed

1. **ShineStaff `JWT_SECRET` fallback** is hardcoded in `middleware/auth.ts`. If the env var is missing,
   anyone can forge an admin token. Remove the fallback; refuse to start without it.
2. **Default admin `admin@shinestaff.com` / `admin123`** is seeded in `index.ts`. Confirm the password was
   changed. `qrSecurityPassword` also defaults to `admin123`.
3. **CleanCredit and coupon checks run only on the phone** (A3, A4). Not trustworthy and invisible to admin.
4. **App booking data goes to Firestore** today; nobody in ShineStaff sees it. Must move to ShineStaff.
5. **App slot list ≠ ShineStaff slot list** (A1). Must be one list.
6. **Old Node panel** (`C:\Booking Software`) `GET /api/bookings/:id` is public and returns the worker's
   phone and `whatsappApiKey`. Separate fix.
7. Customer-facing API must never return worker home location, salary, fuel, internal remarks or other
   customers' data.

---

## D. Build order

| Phase | Where | What |
|---|---|---|
| 0 | ShineStaff | Security fixes C1, C2 |
| 1 | ShineStaff | Catalog (A2), slot settings + closures (A1), coupons (A3), service areas (A7) — admin screens + API |
| 2 | ShineStaff | Customer API: verify Firebase token; slots; create request (idempotent, server price); my bookings; change requests; accept offer. Job fields from section B |
| 3 | ShineStaff | Admin: App requests queue with waiting time, review/confirm/reject, offer time, customer message, request banners, on-the-way, fee |
| 4 | App | Replace Firestore booking code with ShineStaff API; status mapping (B4); hide or wire CleanCredit (A4) and plans (A5) |
| 5 | Both | Plans (A5), wallet (A4), recipient messages (A8) — if chosen |
| 6 | Both | End-to-end test on a **separate test database**, every row of section B ticked off |

## E. Acceptance check

Done means: for every row in section B, a tester can do the customer action on a phone and see the
correct result in ShineStaff, and every admin action shows the correct status and message in the app,
on a test database, with no row skipped.

## G. Making operations easy for the admin

Goal: the admin handles a normal app booking in **one tap**, and the system does the checking.
Built on what ShineStaff already has: worker home and live location, weekly off, leave, Google Maps
distance (`calculateLegDistance`), slot capacity, push/socket alerts to workers, admin alert phone
(`Settings.adminAlertPhone`), and waitlist backfill when a slot frees (`checkAndBroadcastFreedSlot`).

### G1. One inbox for everything that needs a decision

A single "Inbox" page, newest-urgent first, with a count badge in the menu:

- New app booking requests
- Customer cancel / change-time requests
- Customer answers to a team offer (accepted / covered parking)
- Jobs a worker rejected (needs reassignment)
- Requests waiting longer than the target (red)

New items play a sound, show a browser push, and send a WhatsApp alert to `adminAlertPhone`.
Each card shows a waiting timer: green under 30 min, amber under 1 h, red after the target
(the app promises "usually within 1–2 hours").

### G2. Each request card: everything on one card, one main button

The card shows customer, phone, car, service + extras, bill, date + slot, address with a map link,
coverage, notes, and whether this is a first booking.

The system picks a **suggested worker**:
1. Works that day (not weekly off, not on leave), active, company CleanCruisers or Both
2. Free in that slot (no overlapping job)
3. Has the skill for the service (detailing vs wash)
4. Shortest road distance from their previous job that day (or home), using Google Maps; flags a leg
   over the distance limit set in Settings
5. Fewer jobs that day wins a tie

Main button: **"Confirm with <worker>"**. That assigns the job, sets the customer's status to
Confirmed, and runs the existing worker alert flow. A small "Change" link shows the next 2–3 workers
with their distance and jobs that day.

If nobody fits, the card offers instead:
- **Offer another time:** the next 3 free slots, picked by the system; one tap sends the offer
- **Waitlist:** filled automatically if a slot frees (already built)
- **Reject:** preset reasons (area not covered, car type not served, fully booked) shown to the customer

### G3. Customer requests are one tap too

- Cancel: the card shows time left before the slot and whether the late fee applies. Buttons:
  "Approve cancel" / "Approve and add ₹100 fee". Approving frees the slot, which triggers waitlist backfill.
- Change time: shows the requested slot and whether a worker is free. "Approve" moves the job,
  or "Offer instead" with free slots.

### G4. Day board

Today's jobs per worker on a timeline (8 AM – 8 PM), with:
- Late flag when a worker hasn't started 15 min after the slot start (`lateTimeGraceMins`)
- Unassigned jobs in a separate lane at the top
- **Rain button:** picks today's open-air jobs and sends each customer the "rain" choice in the app
  (keep the wash if covered parking / pick another time); answers come back to the Inbox
- Worker sick / bike puncture: one action marks the worker unavailable and moves their jobs to the
  Inbox for reassignment

### G5. Message templates

Customer messages (shown in the app) come from templates the admin can edit in Settings:
confirmed, running late, on the way, offered new time, rejected, rain. The admin picks one and can
edit the text before sending. Nothing internal (worker phone, remarks, fuel) is ever sent.

### G6. End of day

- Jobs completed but not marked paid
- Cash vs UPI totals (Payment module already exists)
- Tomorrow's unassigned requests

### G7. Auto-confirm (later, optional)

A Settings switch: auto-confirm an app request when the address is covered, the suggested worker is
within the distance limit, and the price came from the catalog. **Keep it off at launch**; turn it on
after a few weeks of correct suggestions. Recommendation, not yet decided.

## H. Launch scenarios: decided solutions (19 Nov 2026)

Agreed with the owner. These are needed before launch.

| # | Scenario | Solution |
|---|---|---|
| H1 | Request comes in at night | Working hours (e.g. 8 AM – 8 PM) set in Settings. Requests outside them are accepted, but the app says when they will be confirmed ("by 9 AM tomorrow"), never "within 1–2 hours". |
| H2 | Customer doesn't know the booking was confirmed | **One admin button "Confirm" does everything:** assigns the worker, sets status Confirmed in the app, sends a WhatsApp message "Your booking is confirmed" with date, slot and booking ID, and emails a booking confirmation PDF (service, extras, estimated bill, "pay after the service"). The final invoice is sent after completion, because the bill can change on site (H11). Needs: an approved WhatsApp utility template, and an email address (optional field in sign-up and booking; WhatsApp is the main channel when there is no email). In-app status also updates. |
| H3 | Long jobs (detailing up to 5 h) don't fit a 3 h slot | Capacity is counted in **worker hours**, not slots. Each service has a server-side duration (plus buffer). A job blocks the worker from start to finish. The app only offers start times where the whole job fits that day. |
| H5 | SofaShine and CleanCruisers share workers ("Both") | Capacity is counted **per worker across both companies**. A worker on a sofa job is busy for car jobs at that time. |
| H6 | Pending requests holding slots / spam | A request holds its time for 2 working hours; then the admin gets an alert. At most 2 pending requests per phone number. |
| H8 | Worker refuses a job | **Workers cannot reject jobs.** Remove the Reject action from the worker app and API (`PUT /jobs/:id/reject`). Assigning = confirmed. The worker app shows "Seen" so the admin knows the alert arrived. If a worker can't go (sick, breakdown), the admin uses "Worker unavailable" (G4), which moves their jobs to the Inbox for reassignment; the customer keeps seeing Confirmed while a new worker is found. |
| H9 | Customer not home / car not there | Worker taps "Customer not available" with photo + GPS after waiting 15 min. First time no fee; repeat no-show adds ₹100 to the next booking. Customer is notified on WhatsApp. |
| H11 | Car size wrong on site (booked hatchback, it's an SUV) | Worker changes the size in the worker app. The new price shows in the customer's app; the customer taps Accept before work starts (fallback: customer OTP on the worker's phone). The final invoice uses the accepted price. |

Owner answers (19 Nov 2026):
- **No email.** Customers are not asked for an email. Confirmation, booking PDF and final invoice go on **WhatsApp only** (overrides the email part of H2).
- **Working hours: 8 AM – 6 PM.** Requests outside these hours are confirmed after 8 AM; the app says so.
- **Bills must be GST invoices.** Needs: GSTIN, legal name and address on the bill, SAC code and GST rate (to confirm with the CA), invoice number series, and whether app prices include GST.
- **Customer messages are sent from the CleanCruisers WhatsApp number.**

More owner decisions (19 Nov 2026):
- **No extras added on site** at launch. Extras are chosen only in the app while booking (H12 replaced).
  Reason: an on-site extra can make the worker late for the next booking.
- **Wrong car size on site stays (H11)**, with a time check: if the bigger car's extra time doesn't fit
  before the worker's next job (travel + buffer) or before 6 PM, the worker stops and the admin is
  alerted to move the next job or offer the customer a new slot.
- **Nothing is hidden at launch.** CleanCredit, coupons and monthly plans are all built end to end,
  server-side, with admin screens (section I). It may take longer; that is accepted.

## I. CleanCredit, coupons, monthly plans: server-side design

Today all three live only in the app: the wallet in SharedPreferences, coupon rules in
`lib/data/offers.dart`, plans as catalog items with no visit tracking. Finding: **nothing in the app
ever adds CleanCredit** (`addCredit` has no caller; the old ₹200 sign-up credit was removed), so every
real customer's balance is ₹0. Earning rules must be decided (I1).

### I1. CleanCredit (wallet)
- Ledger in ShineStaff: one row per credit/debit (customer phone, amount, reason, booking, admin, time).
  Balance = sum of the ledger. Admin can see every customer's ledger and add or remove credit with a reason.
- Rules kept from the app: at most 40% of a bill can be paid with credit; credit used on a cancelled
  booking is returned.
- Credit is applied when the booking is confirmed and settled on the final invoice.
- **Owner to decide: how customers earn credit** (e.g. cashback % on each completed wash, referral,
  goodwill from admin, rain/no-fault compensation) and whether credit expires.

### I2. Coupons
- Coupons managed in ShineStaff admin: code, flat ₹ or %, max off, minimum bill, car types, first booking
  only, start/end date, total uses, uses per customer, active switch.
- The server checks every rule at booking time. "First booking" = no completed or confirmed job on that
  phone number before. One use per phone number by default.
- Admin sees uses per coupon. The 40% cap on coupon + credit together stays.
- App shows the offers list from the server instead of `lib/data/offers.dart`.

### I3. Monthly plans
- Customer buys a plan in the app (pay after first visit, same as bookings). ShineStaff creates a Plan:
  customer, car, plan type, visits included (3 or 4), start date, end date (30 days), visits used.
- Each visit is booked by the customer in the app like a normal booking and is linked to the plan
  (bill ₹0 for that visit). Admin sees visits left.
- Missed visit because of rain, worker or company: plan extended by 7 days. Missed because of the
  customer (no-show, late cancel): visit counted as used.
- Admin can extend, pause or cancel a plan with a reason.
- Renewal: reminder on WhatsApp 3 days before the end.
- **Owner to confirm:** payment timing for plans (all upfront at first visit?), and whether unused
  visits carry over.

### I4. GST
Coupon and credit discounts reduce the bill before GST is calculated, and show as separate lines on the
GST invoice. To confirm with the CA.

## J. Offers and money rules: decided (21 Nov 2026)

The owner accepted these recommendations. Margin figures use assumptions: salary ₹17,000 over 26 days
of 8 AM – 6 PM with a 30 min lunch (≈ ₹1.15 per worker minute), ₹5/km travel at 8 km per job
(≈ ₹69 per trip with worker time), guessed material costs, and prices including 18% GST. Replace them
with real figures in Settings when known; the rules below read those settings, not fixed numbers.

### J1. Margin floor (replaces the 40% cap)
- Each service in the catalog has a material cost. Settings hold worker cost per minute and travel cost per trip.
- Contribution = (bill without GST) − worker minutes × cost per minute − travel − material.
- **Discounts (coupon + credit + automatic offers together) may never push a booking's contribution
  below ₹60.** The server lowers the discount to what is allowed and the app shows "Up to ₹X off on this
  booking". A service already below ₹60 (bucket wash, ≈ ₹54) takes no discount.

### J2. Coupons at launch
| Code | Rule |
|---|---|
| FIRST50 | ₹50 off a first booking of a wash ≥ ₹349 |
| FIRST100 | ₹100 off a first booking of ₹649 or more |
| WEEKDAY40 | ₹40 off, Monday–Friday dates only, bill ≥ ₹449 |
| SUVSPECIAL | 10% off for SUVs |

All subject to J1. One use per phone number. "First booking" = no earlier confirmed or completed job on the phone.

### J3. Automatic offers (no code needed)
- **Same building, same day:** ₹50 off each car when two or more bookings at the same building are confirmed for the same day.
- **Second car at the same home, same visit:** ₹75 off the second car.
- **Wash + 3M wax combo:** ₹100 off when both are in one booking.

### J4. CleanCredit
- **Earn:** 5% of the amount paid on each completed booking (plan purchases included); referral ₹100 to both
  people after the friend's first completed booking of ₹449 or more; ₹50 when a wash is postponed for rain;
  goodwill credit from the admin with a reason.
- **Expiry:** each credit expires 60 days after it was given (oldest used first).
- **Use:** on any booking, within J1. Returned if the booking is cancelled.

### J5. Monthly plans
- **Complete Care (3 washes):** price stays ₹1,399 / ₹1,499 / ₹1,599 (hatch / sedan / SUV). Value instead of a
  price cut: free dustbin and air freshener, a fixed weekday visit, price locked for the month.
- **Bucket plan (4 washes):** ₹899 hatchback/sedan (from ₹799). SUV and luxury: owner to confirm
  (suggested ₹1,099 / ₹1,299). Sold only in areas the admin enables (where several customers are close together).
- **Payment:** full plan price paid at the first visit.
- **Validity:** 30 days. Unused visits don't carry over. A visit missed because of rain, a worker or the company
  extends the plan by 7 days; a customer no-show or late cancel counts as used.
- Renewal reminder on WhatsApp 3 days before the end.

### J6. Rain
A wash postponed for rain gives the customer ₹50 CleanCredit (J4) and a new-time offer.

## F. Not known yet

- Where ShineStaff's real git repo is (only a zip was shared).
- Render plan for ShineStaff (free tier sleeps; no keep-alive found).
- Whether workers should be able to set "On the way" from their app, or only admin.
