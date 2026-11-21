import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart' show clockLabel;
import '../core/theme.dart';
import '../data/api/models.dart';
import '../data/business_info.dart';
import '../models/service.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/ui.dart';

/// My bookings (v3 design): Upcoming and Past tabs, from the server
/// (refreshed every 30 s and on pull). Upcoming shows one card per booking
/// with its status, when the expert comes and progress dots; Past is a list
/// with "Book again" on finished washes. Each tab has its own empty state.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myApiBookingsProvider);
    final mine = async.valueOrNull ?? MyBookings.none;
    final list = _past ? mine.past : mine.upcoming;

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
              onRefresh: () => ref.refresh(myApiBookingsProvider.future),
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
                    upcomingCount: mine.upcoming.length,
                    pastCount: mine.past.length,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _past = v);
                    },
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (async.isLoading && !async.hasValue)
                    const Padding(
                      padding: EdgeInsets.all(AppSpace.section),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (async.hasError && !async.hasValue)
                    const NoticeBox(
                      icon: Icons.wifi_off_rounded,
                      warning: true,
                      text: 'Couldn\'t load your bookings. Pull down to try '
                          'again.',
                    )
                  else if (list.isEmpty)
                    _Empty(past: _past)
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

String _carOf(Booking b) =>
    b.car.model.trim().isEmpty ? carTypeNames[b.car.type]! : b.car.model.trim();

String _serviceName(Booking b) =>
    serviceById(b.service.id)?.listName ?? b.service.name;

class _UpcomingCard extends StatelessWidget {
  final Booking booking;
  const _UpcomingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final (chip, tone) = chipOf(b.status);
    final line = [
      if (b.status != BookingState.requested)
        'Ready by about ${clockLabel(b.slot.end)}',
      _serviceName(b),
      _carOf(b),
    ].join(' · ');
    final waiting = b.status == BookingState.requested;
    final step = progressIndex(progressStatusOf(b.status));
    final request = switch (b.openRequest?.kind) {
      'cancel' => 'Cancellation requested. We\'ll confirm on WhatsApp.',
      'changeTime' => 'New time requested. We\'ll confirm on WhatsApp.',
      'keepAsPlanned' => 'You asked to keep the wash. We\'ll confirm.',
      _ => null,
    };

    return Semantics(
      button: true,
      label: '$chip, ${friendlyDate(b.slot.date)}. ${headlineOf(b)}. $line. '
          'Open booking',
      child: ExcludeSemantics(
        child: AppCard(
          radius: AppRadius.lg,
          onTap: () => context.push('/bookings/${b.ref}'),
          padding: const EdgeInsets.all(AppSpace.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(chip, tone: tone)),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(friendlyDate(b.slot.date), style: AppText.caption),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(headlineOf(b), style: AppText.h3),
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
                child: Text(b.statusNote, style: AppText.caption),
              ),
            ] else if (step != null) ...[
              const SizedBox(height: AppSpace.md),
              BookingProgress(status: progressStatusOf(b.status), showLabels: false),
            ],
            if (b.pendingChange != null) ...[
              const SizedBox(height: AppSpace.md),
              Text('Please check a change from the expert.',
                  style: AppText.caption.copyWith(color: AppColors.warning)),
            ] else if (request != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(request,
                  style: AppText.caption.copyWith(color: AppColors.warning)),
            ],
            const Divider(height: AppSpace.xl),
            Row(children: [
              Expanded(
                child: Text(
                    '${rupees(b.bill.total)}${kPayAfterService ? ' · pay after' : ''}',
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
  final Booking booking;
  const _PastRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final service = serviceById(b.service.id);
    final photo = service?.cardPhoto;
    final done = b.status == BookingState.completed;
    final (chip, _) = chipOf(b.status);
    final paid = b.payment.status == 'paid';
    final status = done ? (paid ? 'Done · paid' : 'Done') : chip;
    final meta = [
      friendlyDate(b.slot.date),
      _carOf(b),
      if (done) rupees(b.bill.total),
    ].join(' · ');

    return Row(children: [
      Expanded(
        child: Semantics(
          button: true,
          label: '${_serviceName(b)}. $meta. $status. Open',
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
                          Text(_serviceName(b),
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
      if (done && service != null && b.plan == null)
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.md),
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/book/${service.id}?car=${b.car.type.name}');
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
  final bool past;
  const _Empty({required this.past});

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
