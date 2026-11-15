import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart' show clockLabel;
import '../core/theme.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/ui.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String bookingRef;
  const BookingDetailScreen({super.key, required this.bookingRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteAsync = ref.watch(customerCloudBookingsProvider);
    final remote = remoteAsync.valueOrNull;
    final b = ref
        .watch(myBookingsProvider)
        .where((item) => item.ref == bookingRef)
        .firstOrNull;
    final live = remote?.any((item) => item.ref == bookingRef) ?? false;

    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Booking not found',
            message: 'It may have been removed from this phone.',
            action: PrimaryButton(
                label: 'My bookings',
                expand: false,
                onPressed: () => context.go('/bookings')),
          ),
        ),
      );
    }

    final isCompleted = b.status == BookingStatus.completed;
    final isWeatherHold = b.status == BookingStatus.rescheduleNeeded;
    final isConfirmed = b.status == BookingStatus.confirmed ||
        b.status == BookingStatus.onTheWay ||
        b.status == BookingStatus.inService;
    final parking = parkingOf(b.address) ?? '';
    final isCovered = parking.toLowerCase().contains('basement') ||
        parking.toLowerCase().contains('covered') ||
        parking.toLowerCase().contains('stilt');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(
            isCompleted
                ? 'Completed Service'
                : isWeatherHold
                    ? (isCovered
                        ? 'Rain Alert · Active Wash'
                        : 'Weather Reschedule')
                    : 'Booking #${b.ref.substring(b.ref.length > 8 ? b.ref.length - 8 : 0)}',
            style: AppText.h3,
          ),
          actions: [
            if (isCompleted)
              TextButton.icon(
                onPressed: () =>
                    showMessage(context, 'Downloading tax invoice PDF...'),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF Invoice'),
              )
            else
              IconButton(
                onPressed: () => _requestChange(context, ref, b),
                icon: const Icon(Icons.more_vert_rounded),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(customerCloudBookingsProvider),
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32),
            children: [
              // ── SCREEN 12: Weather Delay / Monsoon Reschedule ───────────────
              if (isWeatherHold) ...[
                _WeatherHoldCard(
                  booking: b,
                  onConfirmPriority: () => _sendChange(context, ref, b,
                      'Priority slot confirmed for tomorrow 9:30 AM'),
                  onPickOther: () => _pickNewSlot(context, ref, b),
                ),
                const SizedBox(height: 16),
              ],

              // ── SCREEN 14: Completed Banner ─────────────────────────────────
              if (isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7EE),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SERVICE COMPLETED & INSPECTED',
                              style: AppText.caption.copyWith(
                                color: AppColors.primaryDk,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Completed today at 11:45 AM · Rahul Sharma',
                              style:
                                  AppText.small.copyWith(color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── SCREEN 10: Confirmed Banner & Stepper ───────────────────────
              if (isConfirmed) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7EE),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CONFIRMED & ASSIGNED',
                              style: AppText.overline.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expert Arrives Tomorrow',
                        style: AppText.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${friendlyDate(b.date)} · Slot: ${slotById(b.slotId)?.short ?? b.slotLabel}',
                        style:
                            AppText.small.copyWith(color: AppColors.textSubtle),
                      ),
                      const SizedBox(height: 14),
                      BookingProgress(status: b.status),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Technician Card (Rahul Sharma) ──────────────────────────────
              if (isConfirmed || isCompleted || isWeatherHold) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadow.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0C2417),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'RS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Rahul Sharma',
                                        style: AppText.bodyStrong),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              size: 12, color: AppColors.star),
                                          const SizedBox(width: 2),
                                          Text(
                                            '4.92',
                                            style: AppText.caption.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryDk,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lead Detailer, CleanCruisers verified',
                                  style: AppText.caption
                                      .copyWith(color: AppColors.textSubtle),
                                ),
                                Text(
                                  'Mobile Van: HR 26 DL 4821',
                                  style: AppText.caption.copyWith(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Receipt (from this booking's real amounts) ──────────────────
              if (isCompleted) ...[
                _Receipt(booking: b),
                const SizedBox(height: 16),

                // Google 5-Star Review Widget
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Rated 5 out of 5 stars by customers',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.star_rounded,
                                color: Color(0xFFD97706), size: 22),
                            Icon(Icons.star_rounded,
                                color: Color(0xFFD97706), size: 22),
                            Icon(Icons.star_rounded,
                                color: Color(0xFFD97706), size: 22),
                            Icon(Icons.star_rounded,
                                color: Color(0xFFD97706), size: 22),
                            Icon(Icons.star_rounded,
                                color: Color(0xFFD97706), size: 22),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Loved the doorstep service on your ${b.carModel.isNotEmpty ? b.carModel : carTypeNames[b.car]}?',
                        style: AppText.smallStrong,
                        textAlign: TextAlign.center,
                      ),
                      ElevatedButton(
                        onPressed: () => showMessage(
                            context, 'Opening Google Review page...'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm)),
                        ),
                        child: const Text('Rate Rahul on Google Reviews'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── SERVICE & LOCATION CARD ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SERVICE & LOCATION',
                      style: AppText.overline.copyWith(
                        color: AppColors.textSubtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _specRow('Package:', b.serviceName),
                    _specRow(
                        'Car:',
                        b.carModel.isNotEmpty
                            ? b.carModel
                            : carTypeNames[b.car]!),
                    _specRow(
                        'On-Site Time:', '~2.5 hrs work (Travel separate)'),
                    _specRow('On-Site Setup:',
                        'Water tap & plug needed (30m cords brought by team)'),
                    _specRow('Service Address:', b.address),
                    _specRow(
                        'Car Recipient:',
                        b.forSomeoneElse && b.recipientName != null
                            ? b.recipientName!
                            : '${b.name} (${phoneLabel(b.phone)})'),
                    const Divider(height: 16, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Amount Due',
                                style: AppText.caption
                                    .copyWith(color: AppColors.textSubtle)),
                            Text(rupees(b.payable), style: AppText.priceSm),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Pay after service - Cash or UPI',
                            style: AppText.caption.copyWith(
                              color: AppColors.textSubtle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── STATUS TIMELINE ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS TIMELINE',
                      style: AppText.overline.copyWith(
                        color: AppColors.textSubtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _timelineItem('10:34 AM',
                        'Booking request submitted by customer in app'),
                    _timelineItem('10:38 AM',
                        'Route validated (7.8 km road leg from Sector 29 hub)'),
                    _timelineItem(
                        '10:41 AM', 'Booking Confirmed & Rahul assigned'),
                    if (isCompleted)
                      _timelineItem(
                          '11:45 AM', 'Service completed & inspected on-site'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── STICKY FOOTER ACTIONS ──────────────────────────────────────
              if (isCompleted) ...[
                PrimaryButton(
                  label: 'Download Official Tax Invoice (PDF)',
                  icon: Icons.picture_as_pdf_rounded,
                  onPressed: () =>
                      showMessage(context, 'Downloading tax invoice...'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/services'),
                  child: const Text('Book Next Doorstep Detailing'),
                ),
              ] else if (isWeatherHold) ...[
                if (isCovered) ...[
                  PrimaryButton(
                    label: 'Wash on Schedule (Covered Parking)',
                    icon: Icons.check_circle_rounded,
                    onPressed: () => _sendChange(context, ref, b,
                        'Covered parking confirmed - wash on schedule'),
                  ),
                ] else ...[
                  PrimaryButton(
                    label: 'Confirm Priority Slot (Tomorrow 9:30 AM)',
                    onPressed: () => _sendChange(context, ref, b,
                        'Priority weather reschedule accepted'),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Pick Another Date / Time Slot',
                    onPressed: () => _pickNewSlot(context, ref, b),
                  ),
                ],
              ] else ...[
                SecondaryButton(
                  label: 'Request Reschedule / Change',
                  icon: Icons.edit_calendar_outlined,
                  onPressed: () => _requestChange(context, ref, b),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: AppText.caption.copyWith(color: AppColors.textSubtle)),
          ),
          Expanded(
            child: Text(value, style: AppText.smallStrong),
          ),
        ],
      ),
    );
  }

  static Widget _timelineItem(String time, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $time:',
              style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: AppText.caption.copyWith(color: AppColors.text)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChange(BuildContext context, WidgetRef ref,
      BookingRecord booking, String request) async {
    try {
      await ref
          .read(bookingCloudProvider)
          .requestCustomerChange(booking, request);
      if (context.mounted) {
        showMessage(context,
            'Updated! Our operations team has noted your priority slot.');
      }
    } catch (_) {
      if (context.mounted)
        showMessage(context, 'Unable to update. Call our team.');
    }
  }

  Future<void> _pickNewSlot(
      BuildContext context, WidgetRef ref, BookingRecord booking) async {
    DateTime selectedDay = DateTime.now().add(const Duration(days: 1));
    TimeSlot? selectedSlot;

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final availableSlots =
              timeSlots.where((s) => s.isAvailable(selectedDay)).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page,
                20 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Priority Reschedule Slot', style: AppText.h3),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Pick an arrival window over the next 4 days:',
                    style: AppText.caption),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final day = DateTime.now().add(Duration(days: i + 1));
                      final isSel = day.year == selectedDay.year &&
                          day.month == selectedDay.month &&
                          day.day == selectedDay.day;
                      return ChoiceChip(
                        selected: isSel,
                        label: Text(i == 0 ? 'Tomorrow' : friendlyDate(day)),
                        onSelected: (_) => setState(() => selectedDay = day),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in availableSlots)
                      ChoiceChip(
                        selected: selectedSlot?.id == s.id,
                        label: Text(s.short),
                        onSelected: (_) => setState(() => selectedSlot = s),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Confirm Reschedule',
                  onPressed: selectedSlot == null
                      ? null
                      : () => Navigator.pop(
                            ctx,
                            'Rescheduled to  at ',
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked != null && context.mounted) {
      await _sendChange(context, ref, booking, picked);
    }
  }

  // ── SCREEN 11: Cancellation & Reschedule Modal ──────────────────────────────
  Future<void> _requestChange(
      BuildContext context, WidgetRef ref, BookingRecord booking) async {
    int selectedReason = 0;
    final reasons = [
      'Change in personal schedule / traveling',
      'Weather forecast looks rainy / overcast',
      'Selected time slot no longer suitable',
      'Got vehicle cleaned elsewhere',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page,
              20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cancel or Reschedule', style: AppText.h2),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 6),
              // Summary bar
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${booking.ref} · Tomorrow, 9:30 - 10:30 AM',
                              style: AppText.caption
                                  .copyWith(fontWeight: FontWeight.w700)),
                          Text(
                              '${booking.serviceName} - ${booking.carModel.isNotEmpty ? booking.carModel : 'White Swift'}',
                              style: AppText.caption
                                  .copyWith(color: AppColors.textSubtle)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Urban Company Policy Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7EE),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Free Cancellation Active: 100% free up to 4 hours before arrival window. Cancellations within 2 hours or after technician departs incurs ₹100 fee on your next booking.',
                        style: AppText.caption
                            .copyWith(color: AppColors.primaryDk, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Reason for cancellation', style: AppText.bodyStrong),
              const SizedBox(height: 8),
              for (var i = 0; i < reasons.length; i++)
                RadioListTile<int>(
                  value: i,
                  groupValue: selectedReason,
                  title: Text(reasons[i], style: AppText.small),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => selectedReason = v ?? 0),
                ),
              const SizedBox(height: 10),
              // Help notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Need to change your plan? Avoid cancellation charges and keep your preferred lead detailer by moving your booking to another date or time for free.',
                        style: AppText.caption.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Reschedule Booking (100% Free)',
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendChange(
                      context, ref, booking, 'Requested free reschedule');
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Cancel this booking?'),
                        content: Text(
                          'Your reserved slot for  on  will be released.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Keep Booking'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Yes, Cancel'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!context.mounted) return;

                    final wallet = ref.read(walletProvider);
                    final appliedTx = wallet.transactions
                        .where(
                          (t) => t.referenceId == booking.ref && t.amount < 0,
                        )
                        .firstOrNull;
                    if (appliedTx != null) {
                      await ref.read(walletProvider.notifier).refundCredit(
                            appliedTx.amount.abs(),
                            booking.ref,
                          );
                    }

                    await _sendChange(context, ref, booking, 'Cancelled: ');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Booking # cancelled.'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              _sendChange(context, ref, booking,
                                  'Undo cancellation: re-opened');
                            },
                          ),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Proceed to Cancel (Fee: ₹0)',
                    style: AppText.bodyStrong.copyWith(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SCREEN 12: Weather Hold Reschedule Component ──────────────────────────────
class _WeatherHoldCard extends StatelessWidget {
  final BookingRecord booking;
  final VoidCallback onConfirmPriority;
  final VoidCallback onPickOther;
  const _WeatherHoldCard(
      {required this.booking,
      required this.onConfirmPriority,
      required this.onPickOther});

  @override
  Widget build(BuildContext context) {
    final parking = parkingOf(booking.address) ?? '';
    final isCovered = parking.toLowerCase().contains('basement') ||
        parking.toLowerCase().contains('covered') ||
        parking.toLowerCase().contains('stilt');

    if (isCovered) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          boxShadow: AppShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rain in Sector 48 · Wash On Schedule',
                        style: AppText.bodyStrong
                            .copyWith(color: AppColors.primaryDk),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Good news! Because your car is in covered parking (${parking.isNotEmpty ? parking : "Basement"}), rain will not delay your appointment. Our detailer will arrive as planned.',
                        style: AppText.caption
                            .copyWith(color: AppColors.text, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.thunderstorm_rounded,
                    color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Paused: Heavy Rain in Sector 48',
                      style: AppText.bodyStrong
                          .copyWith(color: const Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Outdoor foam detailing is temporarily suspended to protect drying finish and technician safety. Your booking remains our top priority.',
                      style: AppText.caption
                          .copyWith(color: AppColors.text, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7EE),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRIORITY RESCHEDULE · NO EXTRA CHARGE',
                  style: AppText.overline.copyWith(
                    color: AppColors.primaryDk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Held Priority Slot:',
                    style:
                        AppText.caption.copyWith(color: AppColors.textSubtle)),
                Text(
                  'Wednesday, Nov 4 · 9:30 AM - 10:30 AM',
                  style:
                      AppText.bodyStrong.copyWith(color: AppColors.primaryDk),
                ),
                const SizedBox(height: 2),
                Text(
                  'Assigned: Rahul Sharma (Lead Detailer) · Van HR 26 DL 4821',
                  style: AppText.caption.copyWith(color: AppColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CleanCruisers Policy: Zero fee for weather reschedule. You inspect your ${booking.carModel.isNotEmpty ? booking.carModel : carTypeNames[booking.car]} after detailing and pay ${rupees(booking.payable)} via Cash or UPI on site.',
            style: AppText.caption
                .copyWith(color: AppColors.textSubtle, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Receipt for a completed booking, built from what was actually booked
/// and collected (no invoice numbers or tax lines the app can't back up).
class _Receipt extends StatelessWidget {
  final BookingRecord booking;
  const _Receipt({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final paid = b.amountCollected ?? b.payable;
    final method = switch (b.paymentMethod) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.upi => 'UPI',
      null => null,
    };
    Widget line(String label, String value, {bool green = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(label,
                    style: AppText.small.copyWith(color: AppColors.text))),
            const SizedBox(width: AppSpace.md),
            Text(value,
                style: AppText.smallStrong.copyWith(
                    color: green ? AppColors.primaryDk : AppColors.text)),
          ]),
        );
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('RECEIPT · ${b.ref}', style: AppText.overline)),
          if (method != null)
            Pill('Paid · $method',
                icon: Icons.check_rounded, tone: PillTone.brand),
        ]),
        const Divider(height: AppSpace.xl),
        line(b.serviceName, rupees(b.servicePrice)),
        for (final (name, qty, price) in b.extras)
          line(qty > 1 ? '$name × $qty' : name, rupees(price)),
        if (b.couponDiscount > 0)
          line('Coupon ${b.couponCode ?? ''}', '-${rupees(b.couponDiscount)}',
              green: true),
        if (b.creditUsed > 0)
          line('CleanCredit', '-${rupees(b.creditUsed)}', green: true),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Expanded(
              child: Text(method == null ? 'To pay' : 'Paid',
                  style: AppText.bodyStrong)),
          Text(rupees(paid), style: AppText.priceSm),
        ]),
      ]),
    );
  }
}
