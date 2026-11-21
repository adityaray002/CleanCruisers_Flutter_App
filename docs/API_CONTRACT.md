# CleanCruisers app ↔ ShineStaff: API contract (v1)

Status: draft, 21 Nov 2026. Covers every customer-side row of `SHINESTAFF_ADMIN_PARITY.md`
(sections B, H, I, J). The app is built against this contract first, using a fake server inside the app;
ShineStaff then implements the same contract. If either side needs a change, this file changes first.

---

## 1. Ground rules

| Topic | Rule |
|---|---|
| Base URL | `https://<shinestaff-host>/api/app/v1` (set in the app with `--dart-define=API_BASE_URL`) |
| Format | JSON, UTF-8. Field names `camelCase`. |
| Auth | `Authorization: Bearer <Firebase ID token>` on every call except section 3. The server verifies the token with Firebase Admin and reads the **phone number from the token**. A phone number in a request body is never trusted. |
| Time | All dates and times are India time (IST). Dates `YYYY-MM-DD`, times `HH:mm` (24 h). Timestamps ISO 8601 with offset, e.g. `2026-11-21T09:30:00+05:30`. |
| Money | Whole rupees, integers. Every bill amount includes GST unless the field name says otherwise. |
| Phone | 10 digits, no `+91`. |
| Car types | `hatchback`, `sedan`, `suv`, `luxury` |
| Truth | The server computes every price, discount, duration, slot and status. The app only displays them. |
| Idempotency | Every create call carries a `clientRef` made by the app. Sending the same `clientRef` again returns the first result instead of creating a second record. |
| Versioning | Breaking changes go to `/v2`. New optional fields can be added to v1 at any time; the app must ignore unknown fields. |

### Errors

Every error has this shape and an HTTP status:

```json
{ "error": { "code": "SLOT_TAKEN", "message": "That time was just taken.", "details": { } } }
```

`message` is safe to show to the customer. The app decides what to do from `code`.

| HTTP | code | When | `details` |
|---|---|---|---|
| 400 | `INVALID_INPUT` | A field is missing or wrong | `{ "field": "date" }` |
| 401 | `AUTH_REQUIRED` | No token, bad token, expired token | |
| 403 | `NOT_YOURS` | The booking/plan belongs to another phone | |
| 404 | `NOT_FOUND` | | |
| 409 | `SLOT_TAKEN` | The chosen start time is no longer free | `{ "alternatives": [Slot] }` (same day first, then next days) |
| 409 | `PENDING_LIMIT` | Already 2 bookings waiting for confirmation on this phone | `{ "pending": ["CC-…"] }` |
| 409 | `PRICE_CHANGED` | The bill differs from the quote the customer saw | `{ "quote": Quote }` |
| 409 | `CHANGE_NOT_ALLOWED` | Request not possible in the booking's current state | `{ "status": "inService" }` |
| 409 | `OFFER_EXPIRED` | The offered time or price change has expired | |
| 422 | `NOT_COVERED` | Address is outside the service area | |
| 422 | `COUPON_INVALID` | Coupon can't be used | `{ "reason": "Only for a first booking" }` |
| 422 | `PLAN_NOT_USABLE` | Plan expired, no visits left, wrong car | |
| 429 | `TOO_MANY_REQUESTS` | Rate limit | `{ "retryAfterSeconds": 30 }` |
| 503 | `UNAVAILABLE` | Server problem or maintenance | |

---

## 2. Shared objects

### Slot
```json
{ "date": "2026-11-22", "start": "09:30", "end": "11:30", "label": "9:30 – 11:30 AM" }
```
`start` is when the expert arrives; `end` is when the car should be ready (service time included).
Customer copy: "Expert arrives at 9:30 AM, car ready by about 11:30 AM".

### Address (snapshot stored on every booking)
```json
{
  "label": "home",                 // home | work | other
  "flat": "B-12", "building": "Green Park Apartments", "area": "Pocket C, Janakpuri",
  "landmark": "near the gurudwara", "pincode": "110058",
  "parking": "Basement parking",   // one of: Basement parking | Open parking | Outside the house | Office parking | null
  "pin": { "lat": 28.6219, "lng": 77.0878, "source": "gps" },  // source: gps | pasted; pin may be null
  "line": "B-12, Green Park Apartments, Pocket C, Janakpuri, near the gurudwara"  // server-built, read-only
}
```

### Bill (server-computed)
```json
{
  "items": [
    { "kind": "service", "name": "Exterior + Interior Wash", "qty": 1, "amount": 449 },
    { "kind": "extra", "name": "Seat cleaning", "qty": 2, "amount": 200 }
  ],
  "subtotal": 649,
  "discounts": [
    { "kind": "coupon", "code": "FIRST100", "amount": 100 },
    { "kind": "auto", "name": "Same building, same day", "amount": 50 },
    { "kind": "credit", "amount": 30 }
  ],
  "lateCancelFee": 0,              // ₹100 carried from an earlier late cancel / no-show, if any
  "total": 469,                    // what the customer pays, GST included
  "gst": { "taxable": 397, "cgst": 36, "sgst": 36, "rate": 18 },
  "discountCapNote": null,         // e.g. "Up to ₹72 off on this booking" when the margin floor limited it
  "payAfterService": true
}
```

### Booking
```json
{
  "ref": "CC-7K4Q2X9M",
  "createdAt": "2026-11-21T22:10:00+05:30",
  "status": "requested",
  "statusNote": "We'll confirm it by 9:00 AM tomorrow.",   // customer-facing line for the current status
  "confirmBy": "2026-11-22T09:00:00+05:30",                // when the team aims to confirm (working hours 8 AM – 6 PM)
  "service": { "id": "wash-full", "name": "Exterior + Interior Wash", "category": "wash" },
  "car": { "type": "hatchback", "model": "Swift" },
  "extras": [ { "id": "seat", "name": "Seat cleaning", "qty": 2, "price": 200 } ],
  "slot": Slot,
  "durationMinutes": 120,
  "address": Address,
  "coverage": "covered",           // covered | notCovered | unverified
  "notes": "Car is the white one near gate 2",
  "recipient": null,               // or { "name": "Asha", "phone": "9876500000", "notify": true, "consentAt": "…" }
  "bill": Bill,
  "plan": null,                    // or { "id": "PL-…", "visitNumber": 2, "visitsTotal": 3 }
  "history": [ { "status": "requested", "at": "2026-11-21T22:10:00+05:30", "note": "Request sent" } ],
  "teamMessage": null,             // latest message from the team, shown on the booking
  "offer": null,                   // see 2.1
  "pendingChange": null,           // see 2.2
  "openRequest": null,             // see 2.3
  "payment": { "status": "pending", "method": null, "paidAt": null },  // status: pending | paid; method: cash | upi
  "invoice": null,                 // { "number": "CC/26-27/000123", "url": "https://…/invoice.pdf" } after completion
  "canCancel": true,
  "canChangeTime": true,
  "cancelPolicy": { "freeUntil": "2026-11-22T05:30:00+05:30", "feeAfter": "2026-11-22T07:30:00+05:30", "fee": 100 }
}
```

Never returned to the customer: worker name, phone, home or live location, salary, fuel, internal notes,
material cost, margin, other customers' data. (Owner rule: no expert names until decided otherwise.)

#### 2.1 `offer`: the team offers another time
```json
{ "slot": Slot, "reason": "rain", "expiresAt": "2026-11-22T12:00:00+05:30" }
```
`reason`: `rain` | `noWorker` | `customerAsked` | `other`. When `reason` is `rain`, the app also shows
"My car is in covered parking, keep the wash".

#### 2.2 `pendingChange`: price change found on site (wrong car size)
```json
{ "id": "CH-1", "kind": "carSize", "from": "hatchback", "to": "suv",
  "newBill": Bill, "newDurationMinutes": 150, "expiresAt": "2026-11-22T10:15:00+05:30" }
```
Work does not start until the customer accepts (6.4) or the worker records the customer's OTP.

#### 2.3 `openRequest`: a request from the customer waiting for the team
```json
{ "kind": "cancel", "reason": "Plans changed", "slot": null, "at": "…", "fee": 0 }
```
`kind`: `cancel` | `changeTime` | `keepAsPlanned`. Only one open request at a time.

### Status values

| `status` | Customer sees | ShineStaff job state |
|---|---|---|
| `requested` | Requested: waiting for the team | Unassigned `pending`, or `waitlist` |
| `confirmed` | Confirmed | Worker assigned (`pending`/`accepted`). A worker can't reject. |
| `onTheWay` | Expert on the way | New state set by worker or admin |
| `inService` | Your car is being cleaned | `started` |
| `rescheduleNeeded` | Pick another time | `postponed`, `pending_reschedule`, or an open `offer` |
| `completed` | Done | `completed` |
| `missed` | Expert couldn't find you | New: customer not available (photo + GPS) |
| `cancelled` | Cancelled | `cancelled` |
| `unableToServe` | We can't do this booking | New: admin rejected the request with a reason |

If a worker becomes unavailable after confirming, the status stays `confirmed` while the admin reassigns.

---

## 3. Public calls (no login)

### `GET /config`
Business settings the app needs before login.
```json
{
  "workingHours": { "open": "08:00", "close": "18:00" },
  "confirmWithinMinutes": 120,
  "bookingWindowDays": 14,
  "cancelPolicy": { "freeHoursBefore": 4, "feeHoursBefore": 2, "fee": 100 },
  "supportWhatsApp": "91XXXXXXXXXX",
  "catalogVersion": "2026-11-21",
  "minAppVersion": "1.0.0"
}
```

### `GET /catalog`
```json
{
  "version": "2026-11-21",
  "services": [
    {
      "id": "wash-full", "category": "wash", "name": "Exterior + Interior Wash", "active": true,
      "prices": { "hatchback": 449, "sedan": 499, "suv": 549, "luxury": 549 },
      "durationMinutes": { "hatchback": 120, "sedan": 120, "suv": 150, "luxury": 150 },
      "extras": [ { "id": "seat", "name": "Seat cleaning", "price": 100, "maxQty": 7, "unit": "seat", "minutes": 10 } ]
    }
  ],
  "plans": [
    { "id": "monthly-3", "name": "Complete Care", "visits": 3, "days": 30, "serviceId": "wash-full",
      "prices": { "hatchback": 1399, "sedan": 1499, "suv": 1599, "luxury": 1599 },
      "includes": ["Free car dustbin", "Air freshener", "Fixed weekday visit", "Price locked for the month"],
      "onlyInAreas": false }
  ]
}
```
Photos, descriptions and "what's included" lists stay in the app, matched by `id`. A service the app
doesn't know is shown with a plain tile. `active: false` services are hidden.

### `GET /offers`
Coupons the customer can see.
```json
{ "offers": [ { "code": "FIRST100", "title": "Off first booking", "headline": "₹100 OFF",
  "conditions": ["First booking only", "Min. bill ₹649"], "validTill": null } ] }
```

### `GET /coverage?lat=..&lng=..&pincode=..`
```json
{ "coverage": "covered", "areaName": "Janakpuri" }
```

---

## 4. Customer profile

### `GET /me`
```json
{
  "phone": "9876543210", "name": "Rahul", "car": { "type": "hatchback", "model": "Swift" },
  "isFirstBooking": true,
  "wallet": { "balance": 120, "nextExpiry": { "amount": 50, "on": "2026-12-30" } },
  "referralCode": "RAHUL7Q",
  "activePlans": [ Plan ],
  "lateCancelFeeDue": 0
}
```
Creates the customer on first call after login (and links the `CustomerContact` in ShineStaff).

### `PUT /me`
Body: `{ "name": "Rahul", "car": { "type": "hatchback", "model": "Swift" }, "referralCode": "PRIYA4X" }`.
`referralCode` is accepted only once, only before the first booking, and not the customer's own code.

### Addresses
- `GET /addresses` → `{ "addresses": [ Address & { "id": "AD-1", "isDefault": true } ] }`
- `POST /addresses` (body: Address without `line`) → the saved address with `id` and `coverage`
- `PUT /addresses/{id}`, `DELETE /addresses/{id}`
- `DELETE` returns `409 CHANGE_NOT_ALLOWED` if an upcoming booking uses the address.

---

## 5. Booking a slot

### `GET /availability`
Query: `serviceId`, `car`, `extras` (e.g. `seat:2,ac:1`), `date`, `lat`, `lng` (optional), `planId` (optional).
```json
{
  "date": "2026-11-22",
  "durationMinutes": 140,
  "slots": [ { "date": "2026-11-22", "start": "08:30", "end": "10:50", "label": "8:30 – 10:50 AM", "open": true } ],
  "closedReason": null      // e.g. "Closed for Diwali" when the whole day is closed
}
```
Rules the server applies (H3, H5, J): counts **worker hours** across CleanCruisers and SofaShine;
the whole job plus travel and buffer must fit before 6 PM; lunch is protected; weekly off, leave and
closed days are excluded; slots in the past or within the next 2 hours are not offered. The app shows
only `open: true` slots and never shows counts.

### `POST /quote`
Body:
```json
{ "serviceId": "wash-full", "car": { "type": "hatchback", "model": "Swift" },
  "extras": [ { "id": "seat", "qty": 2 } ], "slot": { "date": "2026-11-22", "start": "08:30" },
  "addressId": "AD-1", "couponCode": "FIRST100", "useCredit": true, "planId": null }
```
Response: `{ "quote": { "id": "Q-…", "bill": Bill, "durationMinutes": 140, "coupon": { "applied": true, "reason": null }, "expiresAt": "…" } }`.
Called on the review step and whenever the customer changes something there. An invalid coupon does not
fail the quote: `coupon.applied` is `false` with a `reason`.

### `POST /bookings`
Body:
```json
{
  "clientRef": "CC-7K4Q2X9M",
  "quoteId": "Q-…",
  "expectedTotal": 469,
  "serviceId": "wash-full", "car": { "type": "hatchback", "model": "Swift" },
  "extras": [ { "id": "seat", "qty": 2 } ],
  "slot": { "date": "2026-11-22", "start": "08:30" },
  "addressId": "AD-1",                 // or "address": Address for a one-off address
  "notes": "White car near gate 2",
  "recipient": null,                   // or { "name", "phone", "notify", "consentAt" }
  "couponCode": "FIRST100", "useCredit": true, "planId": null
}
```
`201` → `{ "booking": Booking }` with `status: "requested"`.
Errors: `SLOT_TAKEN` (with alternatives), `PENDING_LIMIT`, `PRICE_CHANGED`, `NOT_COVERED`,
`COUPON_INVALID`, `PLAN_NOT_USABLE`.
Server side: creates an unassigned CleanCruisers Job with `source: "app"`, holds the time for 2 working
hours (H6), alerts the admin Inbox (sound, push, WhatsApp to the admin phone).

### `GET /bookings?scope=upcoming|past`
`{ "bookings": [ Booking ] }`. Includes jobs the admin created for this phone (phone bookings), so the
customer's history is complete.

### `GET /bookings/{ref}`
`{ "booking": Booking }`. The app refreshes this every 30 s while the page is open and on pull-to-refresh.

---

## 6. After booking: customer actions

All return `{ "booking": Booking }` with the new `openRequest` or status. None is instant unless stated.

### 6.1 `POST /bookings/{ref}/cancel`
Body: `{ "reason": "Plans changed" }` (reasons: Plans changed, Car not available, Booked by mistake, Other).
- `requested`: cancelled at once (nothing was confirmed).
- `confirmed`: becomes an `openRequest` for the admin. The response shows the fee that will apply
  (free until 4 h before; ₹100 on the next booking within 2 h or after the expert has left).
- `onTheWay` / `inService` / `completed`: `409 CHANGE_NOT_ALLOWED`.

### 6.2 `POST /bookings/{ref}/change-time`
Body: `{ "slot": { "date": "2026-11-23", "start": "11:00" } }` (must be an open slot from `/availability`).
Becomes an `openRequest`; the admin approves or offers another time.

### 6.3 `POST /bookings/{ref}/offer/accept` · `POST /bookings/{ref}/offer/decline`
Accepting moves the booking to the offered slot (capacity re-checked; `SLOT_TAKEN` if it was lost;
`OFFER_EXPIRED` after `expiresAt`). Declining opens the change-time picker in the app.

### 6.4 `POST /bookings/{ref}/keep-as-planned`
Rain only: "My car is in covered parking, keep the wash". Goes to the admin Inbox.

### 6.5 `POST /bookings/{ref}/changes/{id}/accept` · `.../reject`
Wrong car size found on site (H11). Accept: new bill and duration apply, work can start.
Reject: the worker leaves; the booking becomes `cancelled` with no fee, and the customer can rebook.
If the extra time doesn't fit before the worker's next job or 6 PM, the server doesn't create this change;
the admin is alerted instead (owner decision, section H).

### 6.6 `GET /bookings/{ref}/invoice`
After completion: `{ "number": "CC/26-27/000123", "url": "…" }`. GST invoice PDF, also sent on WhatsApp.
Before completion: `404`.

---

## 7. CleanCredit

### `GET /wallet`
```json
{ "balance": 120,
  "entries": [ { "id": "W-1", "amount": 25, "kind": "cashback", "note": "5% of CC-7K4Q2X9M", "at": "…", "expiresOn": "2027-01-20", "bookingRef": "CC-7K4Q2X9M" } ] }
```
`kind`: `cashback` | `referral` | `rain` | `goodwill` | `used` | `returned` | `expired`. Read-only for the
customer; credit is only added by the server or the admin (J4).

---

## 8. Monthly plans

### Plan
```json
{ "id": "PL-…", "planId": "monthly-3", "name": "Complete Care", "car": { "type": "hatchback", "model": "Swift" },
  "status": "active",                  // pendingFirstVisit | active | expired | cancelled
  "startsOn": "2026-11-22", "endsOn": "2026-12-21",
  "visitsTotal": 3, "visitsUsed": 1, "visitsBooked": 1,
  "price": 1399, "paid": true, "addressId": "AD-1" }
```

### `POST /plans`
Body: `{ "clientRef": "PL-…", "planId": "monthly-3", "car": {…}, "addressId": "AD-1", "firstVisit": { "date": "2026-11-22", "start": "09:00" } }`.
Creates the plan and its first visit booking together (`201 { "plan": Plan, "booking": Booking }`).
The full price is paid at the first visit (J5). Errors as `POST /bookings`, plus `NOT_COVERED` when the
plan is limited to admin-enabled areas.

### `GET /plans`
`{ "plans": [ Plan ] }`

Each later visit is booked with `POST /bookings` and `planId`; its bill total is ₹0. Extension (+7 days
for a visit missed by rain/worker/company) and expiry are done by the server; the app only shows dates.

---

## 9. Referral

### `GET /referral`
`{ "code": "RAHUL7Q", "rewardEach": 100, "joined": 2, "rewarded": 1, "shareText": "…" }`

---

## 10. What WhatsApp sends (server side, for reference)

From the CleanCruisers number, using approved templates. The app never sends these.

| Event | Message |
|---|---|
| Booking confirmed (admin taps Confirm) | Date, arrival time, booking ID, estimated bill, "pay after the service" |
| New time offered / rain | Offer and a link to open the booking |
| Running late > 15 min | New arrival estimate |
| Missed (customer not available) | What happened, fee if any |
| Completed | GST invoice PDF and CleanCredit earned |
| Plan ending in 3 days | Renewal reminder |

---

## 11. Coverage of the spec

| Spec | Contract |
|---|---|
| B1 account, profile, addresses | 4 |
| B2 catalog, prices, extras, durations | 3 `/catalog`, 5 `/quote` |
| B3 request, capacity, idempotency, slot taken, recipient, coverage, coupon, credit | 5, 3 `/coverage`, errors |
| B4 statuses | 2 status table |
| B5 cancel, change time, offers, rain, team message | 6, `teamMessage`, `offer` |
| B6 payment, bill, invoice | `Bill`, `payment`, 6.6 |
| B7 notifications | 10 (WhatsApp), polling in 5 |
| H1 night requests | `confirmBy`, `statusNote`, `/config.workingHours` |
| H2 confirm message | 10 |
| H3, H5 worker hours, shared workers | 5 `/availability` rules |
| H6 pending limit | `PENDING_LIMIT` |
| H8 no worker reject | status table note |
| H9 no-show | `missed` status, `lateCancelFee` |
| H11 wrong car size | 2.2, 6.5 |
| I1, J4 CleanCredit | 7, `Bill.discounts` |
| I2, J2 coupons | 3 `/offers`, 5 `/quote` |
| I3, J5 plans | 8 |
| I4 GST | `Bill.gst`, 6.6 |
| J1 margin floor | `Bill.discountCapNote` |
| J3 automatic offers | `Bill.discounts[kind=auto]` |
| J6 rain credit | 7 (`kind: rain`), 2.1 |

## 12. Not in v1 (on purpose)

- Complaints / redo request after completion (scenario 15): planned for v1.1.
- Push notifications (FCM): WhatsApp covers launch; the app polls while open.
- "Green slots" (cheaper when a worker is nearby): after worker-hours capacity is proven.
- Admin and worker APIs: ShineStaff internal, not part of this contract.
