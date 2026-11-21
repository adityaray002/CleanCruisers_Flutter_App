import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart' show clockLabel;
import '../core/theme.dart';
import '../data/api/fake/fake_api.dart';
import '../data/api/models.dart';
import '../providers/api_providers.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/ui.dart';

/// Test builds only (--dart-define=FAKE_SERVER=true): do what the admin and
/// the worker would do in ShineStaff, so every customer screen can be tried
/// on a phone. Never part of a customer build.
class TestToolsScreen extends ConsumerStatefulWidget {
  const TestToolsScreen({super.key});

  @override
  ConsumerState<TestToolsScreen> createState() => _TestToolsScreenState();
}

class _TestToolsScreenState extends ConsumerState<TestToolsScreen> {
  FakeApi get _api => ref.read(fakeApiProvider);

  void _refresh([String? bookingRef]) {
    ref.invalidate(myApiBookingsProvider);
    ref.invalidate(meProvider);
    if (bookingRef != null) ref.invalidate(apiBookingProvider(bookingRef));
    setState(() {});
  }

  void _do(String label, String bookingRef, void Function() action) {
    try {
      action();
      showMessage(context, label);
    } on StateError catch (e) {
      showMessage(context, e.message);
    } on ApiException catch (e) {
      showMessage(context, e.message);
    }
    _refresh(bookingRef);
  }

  /// The first open start time on the day after the booking (for offers).
  Future<SlotPick?> _nextOpen(Booking b) async {
    for (var i = 1; i <= 5; i++) {
      final day = addDays(dateOnly(b.slot.date), i);
      final a = await _api.availability(
        serviceId: b.service.id,
        car: b.car,
        extras: {for (final e in b.extras) e.id: e.qty},
        date: day,
      );
      final s = a.openSlots.firstOrNull;
      if (s != null) return SlotPick(day, s.start);
    }
    return null;
  }

  Future<void> _offer(Booking b, {bool rain = false}) async {
    final slot = await _nextOpen(b);
    if (!mounted) return;
    if (slot == null) {
      showMessage(context, 'No open time in the next 5 days');
      return;
    }
    _do(rain ? 'Rain: new time offered, ₹50 credit given' : 'New time offered',
        b.ref, () => rain ? _api.adminRain(b.ref, slot) : _api.adminOfferTime(b.ref, slot));
  }

  List<(String, VoidCallback)> _actions(Booking b) {
    final r = b.ref;
    final open = b.openRequest;
    return [
      if (open != null) ...[
        ('Approve ${open.kind}', () => _do('Request approved', r, () => _api.adminApproveRequest(r))),
        ('Decline ${open.kind}', () => _do('Request declined', r,
            () => _api.adminDeclineRequest(r, 'Sorry, we can\'t do that. Please chat with us.'))),
      ],
      if (b.status == BookingState.requested) ...[
        ('Confirm', () => _do('Confirmed, WhatsApp sent', r, () => _api.adminConfirm(r))),
        ('Offer another time', () => _offer(b)),
        ('Reject', () => _do('Rejected', r,
            () => _api.adminReject(r, 'Sorry, we can\'t reach this area on that day.'))),
      ],
      if (b.status == BookingState.confirmed) ...[
        ('On the way', () => _do('On the way', r, () => _api.adminOnTheWay(r))),
        ('Rain', () => _offer(b, rain: true)),
        ('Worker sick', () => _do('Worker unavailable: needs a new worker', r, () {
          final w = _api.adminWorkerOf(r);
          if (w == null) throw StateError('No worker on $r');
          _api.adminWorkerUnavailable(w, b.slot.date);
        })),
        ('Re-confirm (new worker)', () => _do('New worker assigned', r, () => _api.adminConfirm(r))),
      ],
      if (b.status == BookingState.onTheWay) ...[
        ('Start work', () => _do('Work started', r, () => _api.adminStart(r))),
      ],
      if (const [BookingState.confirmed, BookingState.onTheWay].contains(b.status)) ...[
        ('Customer not available', () => _do('Marked missed', r, () => _api.adminMissed(r))),
        if (b.car.type != CarType.suv)
          ('Car is an SUV', () => _do('Car size change sent', r, () {
            if (_api.adminCarSize(r, CarType.suv) == null) {
              throw StateError('Doesn\'t fit before the next job or 6 PM: admin must move it');
            }
          })),
      ],
      if (b.status == BookingState.inService) ...[
        ('Complete (cash)', () => _do('Completed, invoice sent', r, () => _api.adminComplete(r, method: 'cash'))),
        ('Complete (UPI)', () => _do('Completed, invoice sent', r, () => _api.adminComplete(r, method: 'upi'))),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(fakeApiProvider);
    final all = api.adminAllBookings();
    final phone = api.signedInPhone;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Test tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.xxl),
        children: [
          const NoticeBox(
            icon: Icons.science_outlined,
            text: 'Test build only. These buttons do what the admin and the '
                'worker will do in ShineStaff.',
          ),
          const SizedBox(height: AppSpace.lg),
          if (phone != null)
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
              OutlinedButton(
                onPressed: () {
                  api.adminGoodwill(phone, 100, 'Test goodwill');
                  _refresh();
                  showMessage(context, '₹100 CleanCredit added');
                },
                child: const Text('Give ₹100 credit'),
              ),
              OutlinedButton(
                onPressed: () {
                  api.adminCloseDay(addDays(dateOnly(DateTime.now()), 2), 'Closed for a holiday');
                  _refresh();
                  showMessage(context, 'Day after tomorrow closed');
                },
                child: const Text('Close a day'),
              ),
            ]),
          const SizedBox(height: AppSpace.lg),
          Text('Bookings', style: AppText.h2),
          const SizedBox(height: AppSpace.sm),
          if (all.isEmpty) Text('No bookings yet.', style: AppText.small),
          for (final b in all) ...[
            AppCard(
              onTap: () => context.push('/bookings/${b.ref}'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(b.ref, style: AppText.smallStrong)),
                  Pill(chipOf(b.status).$1, tone: chipOf(b.status).$2),
                ]),
                const SizedBox(height: 4),
                Text(
                    '${b.service.name} · ${carTypeNames[b.car.type]} · '
                    '${friendlyDate(b.slot.date)} ${clockLabel(b.slot.start)} · '
                    '${rupees(b.bill.total)}',
                    style: AppText.small),
                if (b.openRequest != null)
                  Text('Customer asked: ${b.openRequest!.kind}',
                      style: AppText.caption.copyWith(color: AppColors.warning)),
                const SizedBox(height: AppSpace.sm),
                Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  for (final (label, onTap) in _actions(b))
                    InlineButton(label: label, onPressed: onTap),
                ]),
              ]),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          const SizedBox(height: AppSpace.lg),
          Text('WhatsApp messages sent', style: AppText.h2),
          const SizedBox(height: AppSpace.sm),
          if (api.outbox.isEmpty) Text('None yet.', style: AppText.small),
          for (final m in api.outbox.reversed.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text('${phoneLabel(m.phone)} · ${m.template}\n${m.text}',
                  style: AppText.caption),
            ),
        ],
      ),
    );
  }
}
