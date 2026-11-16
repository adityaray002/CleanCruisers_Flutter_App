import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/ui.dart';

/// My bookings (v3 design): Upcoming and Past tabs. Upcoming shows one card
/// per booking with its status, when the expert comes and progress dots;
/// Past is a list with "Book again" on finished washes. Each tab has its own
/// empty state.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(myBookingsProvider);
    final upcoming = all
        .where((b) => b.isUpcoming() && !b.status.isFinal)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = all.where((b) => !b.isUpcoming() || b.status.isFinal).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final list = _past ? past : upcoming;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(customerCloudBookingsProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
                children: [
                  Semantics(
                    header: true,
                    child: Text('My bookings', style: AppText.h1),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _Tabs(
                    past: _past,
                    upcomingCount: upcoming.length,
                    pastCount: past.length,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _past = v);
                    },
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (list.isEmpty)
                    _Empty(past: _past, firstBooking: all.isEmpty)
                  else if (!_past)
                    for (final b in list) ...[
                      _UpcomingCard(booking: b),
                      const SizedBox(height: AppSpace.md),
                    ]
                  else
                    AppCard(
                      radius: AppRadius.lg,
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _PastRow(booking: list[i]),
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final bool past;
  final int upcomingCount, pastCount;
  final ValueChanged<bool> onChanged;
  const _Tabs({
    required this.past,
    required this.upcomingCount,
    required this.pastCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final on = past == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.surface : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: on
                      ? const [
                          BoxShadow(
                              color: Color(0x290B0F10),
                              blurRadius: 3,
                              offset: Offset(0, 1))
                        ]
                      : null,
                ),
                child: Text(label,
                    style: AppText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w800,
                        color: on ? AppColors.text : AppColors.textMuted)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        tab('Upcoming · $upcomingCount', false),
        tab('Past · $pastCount', true),
      ]),
    );
  }
}

/// Status chip colours and words, shared by the list and the detail page.
(String, PillTone) statusChip(BookingRecord b) => switch (b.status) {
      BookingStatus.requested => ('Waiting for confirmation', PillTone.warning),
      BookingStatus.teamReview => ('Team checking', PillTone.warning),
      BookingStatus.confirmed => ('Confirmed', PillTone.brand),
      BookingStatus.onTheWay => ('On the way', PillTone.brand),
      BookingStatus.inService => ('Cleaning now', PillTone.brand),
      BookingStatus.rescheduleNeeded => ('Pick a new time', PillTone.warning),
      BookingStatus.completed => ('Done', PillTone.brand),
      BookingStatus.cancelled => ('Cancelled', PillTone.neutral),
      BookingStatus.unableToServe => ('Couldn\'t take it', PillTone.neutral),
    };

class _UpcomingCard extends StatelessWidget {
  final BookingRecord booking;
  const _UpcomingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final (chip, tone) = statusChip(b);
    final service = serviceById(b.serviceId);
    final arrival = b.confirmedArrivalLabel;
    final line = [
      if (arrival != null) 'Likely around $arrival',
      service?.listName ?? b.serviceName,
      b.carModel.trim().isEmpty ? carTypeNames[b.car]! : b.carModel.trim(),
    ].join(' · ');
    final waiting = b.status == BookingStatus.requested ||
        b.status == BookingStatus.teamReview;

    return Semantics(
      button: true,
      label: '$chip, ${friendlyDate(b.date)}. ${progressHeadline(b)}. $line. '
          'Open booking',
      child: ExcludeSemantics(
        child: AppCard(
          radius: AppRadius.lg,
          onTap: () => context.push('/bookings/${b.ref}'),
          padding: const EdgeInsets.all(AppSpace.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Pill(chip, tone: tone)),
              const SizedBox(width: AppSpace.sm),
              const Spacer(),
              Text(friendlyDate(b.date), style: AppText.caption),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(progressHeadline(b), style: AppText.h3),
            const SizedBox(height: 2),
            Text(line, style: AppText.small),
            if (waiting) ...[
              const SizedBox(height: AppSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                    'We usually confirm within $kConfirmUsually. '
                    'You\'ll see it here.',
                    style: AppText.caption),
              ),
            ] else if (progressIndex(b.status) != null) ...[
              const SizedBox(height: AppSpace.md),
              BookingProgress(status: b.status, showLabels: false),
            ],
            if (b.customerChangeRequest != null) ...[
              const SizedBox(height: AppSpace.md),
              Text('Change requested. We\'ll confirm in the app.',
                  style: AppText.caption.copyWith(color: AppColors.warning)),
            ],
            const Divider(height: AppSpace.xl),
            Row(children: [
              Expanded(
                child: Text(
                    '${rupees(b.payable)}${kPayAfterService ? ' · pay after' : ''}',
                    style: AppText.small),
              ),
              Text('View details',
                  style:
                      AppText.smallStrong.copyWith(color: AppColors.primary)),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  final BookingRecord booking;
  const _PastRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final service = serviceById(b.serviceId);
    final photo = service?.cardPhoto;
    final done = b.status == BookingStatus.completed;
    final (chip, _) = statusChip(b);
    final status = done ? 'Done · paid' : chip;
    final meta = [
      friendlyDate(b.date),
      b.carModel.trim().isEmpty ? carTypeNames[b.car]! : b.carModel.trim(),
      if (done) rupees(b.amountCollected ?? b.payable),
    ].join(' · ');

    return Row(children: [
      Expanded(
        child: Semantics(
          button: true,
          label: '${service?.listName ?? b.serviceName}. $meta. $status. Open',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: () => context.push('/bookings/${b.ref}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.thumb),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: photo != null
                          ? Image.asset(photo,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              excludeFromSemantics: true)
                          : const ColoredBox(
                              color: AppColors.primarySoft,
                              child: Icon(Icons.local_car_wash_rounded,
                                  color: AppColors.primary),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(service?.listName ?? b.serviceName,
                              style: AppText.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(meta, style: AppText.caption),
                          Text(status,
                              style: AppText.caption.copyWith(
                                  color: done
                                      ? AppColors.primaryDk
                                      : AppColors.textSubtle,
                                  fontWeight: FontWeight.w800)),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (done && service != null)
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.md),
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/book/${service.id}?car=${b.car.name}');
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              textStyle: AppText.smallStrong,
            ),
            child: const Text('Book again'),
          ),
        ),
    ]);
  }
}

class _Empty extends StatelessWidget {
  final bool past, firstBooking;
  const _Empty({required this.past, required this.firstBooking});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(children: [
        Container(
          width: 104,
          height: 104,
          decoration: const BoxDecoration(
              color: AppColors.primarySoft, shape: BoxShape.circle),
          child: const Icon(Icons.event_note_rounded,
              size: 44, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpace.xl),
        Text(past ? 'Nothing here yet' : 'No bookings yet',
            style: AppText.h2, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.sm),
        Text(
            past
                ? 'Your finished washes show up here, with the bill.'
                : 'Your washes show up here, with the time\n'
                    'your expert arrives and the bill.',
            textAlign: TextAlign.center,
            style: AppText.body),
        const SizedBox(height: AppSpace.xl),
        PrimaryButton(
          label: 'Book a wash',
          icon: Icons.arrow_forward_rounded,
          expand: false,
          onPressed: () => context.go('/services?cat=wash'),
        ),
      ]),
    );
  }
}
