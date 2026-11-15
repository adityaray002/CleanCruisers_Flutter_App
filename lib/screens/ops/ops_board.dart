import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/scheduling.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../models/booking.dart';
import '../../providers/app_providers.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/ui.dart';
import 'ops_actions.dart';
import 'ops_dashboard_screen.dart';

bool needsReview(BookingRecord b) =>
    b.status == BookingStatus.requested ||
    b.status == BookingStatus.teamReview ||
    (b.customerChangeRequest != null && !b.status.isFinal);

bool isOverdue(BookingRecord b, OpsSettings s, {DateTime? now}) =>
    b.status == BookingStatus.requested &&
    (now ?? DateTime.now()).difference(b.createdAt).inMinutes >
        s.reviewTargetMinutes;

enum BoardFilter {
  all,
  needsReview,
  unassigned,
  lateRisk,
  weather,
  emergency,
  completed
}

const _filterNames = {
  BoardFilter.all: 'All',
  BoardFilter.needsReview: 'Needs review',
  BoardFilter.unassigned: 'Unassigned',
  BoardFilter.lateRisk: 'Late risk',
  BoardFilter.weather: 'Weather/access',
  BoardFilter.emergency: 'Emergency',
  BoardFilter.completed: 'Completed',
};

// ── Today board ───────────────────────────────────────────────────────────────
class OpsBoard extends StatefulWidget {
  final OpsData data;
  const OpsBoard({super.key, required this.data});

  @override
  State<OpsBoard> createState() => _OpsBoardState();
}

class _OpsBoardState extends State<OpsBoard> {
  DateTime _date = dateOnly(DateTime.now());
  BoardFilter _filter = BoardFilter.all;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final day = data.bookings.where((b) => dateOnly(b.date) == _date).toList()
      ..sort((a, b) => a.slotId.compareTo(b.slotId));
    final plans = {
      for (final w in data.workers.where((w) => w.active))
        w.id: storedDayPlan(data, w, _date),
    };
    bool lateRisk(BookingRecord b) =>
        b.riskFlag != null ||
        (b.workerId != null &&
            (plans[b.workerId]?.issues.any((i) => i.ref == b.ref) ?? false));
    bool matches(BookingRecord b) => switch (_filter) {
          BoardFilter.all => !b.status.isFinal,
          BoardFilter.needsReview => needsReview(b),
          BoardFilter.unassigned =>
            b.status.holdsCapacity && b.workerId == null,
          BoardFilter.lateRisk => !b.status.isFinal && lateRisk(b),
          BoardFilter.weather => b.status == BookingStatus.rescheduleNeeded,
          BoardFilter.emergency =>
            data.worker(b.workerId)?.isEmergency ?? false,
          BoardFilter.completed => b.status == BookingStatus.completed,
        };
    final shown = day.where(matches).toList();
    final unassigned =
        day.where((b) => b.status.holdsCapacity && b.workerId == null).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(children: [
          IconButton(
              tooltip: 'Previous day',
              onPressed: () => setState(() => _date = addDays(_date, -1)),
              icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) setState(() => _date = dateOnly(picked));
              },
              child: Text(friendlyDate(_date), style: AppText.h3),
            ),
          ),
          IconButton(
              tooltip: 'Next day',
              onPressed: () => setState(() => _date = addDays(_date, 1)),
              icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        Row(children: [
          Expanded(
              child: _metric(
                  'Jobs', '${day.where((b) => !b.status.isFinal).length}')),
          const SizedBox(width: 8),
          Expanded(child: _metric('Unassigned', '$unassigned')),
          const SizedBox(width: 8),
          Expanded(
              child:
                  _metric('Needs review', '${day.where(needsReview).length}')),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in BoardFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(_filterNames[f]!),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Workers', style: AppText.h3),
        const SizedBox(height: 6),
        for (final w in data.workers.where((w) => w.active))
          _WorkerDayTile(
              worker: w,
              plan: plans[w.id]!,
              jobs: dayBookings(data, w.id, _date),
              settings: data.settings,
              date: _date),
        const SizedBox(height: 14),
        Text('Bookings', style: AppText.h3),
        const SizedBox(height: 6),
        if (shown.isEmpty)
          const AppCard(child: Text('Nothing here for this date and filter.'))
        else
          for (final b in shown)
            BookingCard(booking: b, data: data, lateRisk: lateRisk(b)),
      ],
    );
  }

  Widget _metric(String label, String value) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppText.h2),
          Text(label, style: AppText.caption),
        ]),
      );
}

class _WorkerDayTile extends StatelessWidget {
  final WorkerRecord worker;
  final DayPlan plan;
  final List<BookingRecord> jobs;
  final OpsSettings settings;
  final DateTime date;
  const _WorkerDayTile(
      {required this.worker,
      required this.plan,
      required this.jobs,
      required this.settings,
      required this.date});

  @override
  Widget build(BuildContext context) {
    final productive =
        jobs.fold<int>(0, (s, b) => s + b.serviceDurationMinutes) / 60;
    final target = settings.productiveHoursTarget;
    // Availability problems (off, leave, disruption) matter even with no jobs.
    final dayIssues = plan.issues.where((i) => i.ref == null).toList();
    final routeIssues = plan.issues.where((i) => i.ref != null).toList();
    final status = dayIssues.isNotEmpty
        ? dayIssues.first.message
        : jobs.isEmpty
            ? 'No jobs yet'
            : routeIssues.isEmpty
                ? '${jobs.length} job${jobs.length == 1 ? '' : 's'} · route OK'
                    '${plan.lunchAt == null ? '' : ' · lunch ${clockLabel(plan.lunchAt!)}'}'
                    '${plan.endOfDay == null ? '' : ' · back ${clockLabel(plan.endOfDay!)}'}'
                : '${routeIssues.length} route problem${routeIssues.length == 1 ? '' : 's'}';
    final bad = dayIssues.isNotEmpty || routeIssues.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
                worker.isEmergency
                    ? Icons.health_and_safety_outlined
                    : Icons.person_outline_rounded,
                size: 20,
                color: bad ? AppColors.warning : AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  '${worker.name}${worker.isEmergency ? ' · emergency (standby after 11 AM)' : ''}',
                  style: AppText.smallStrong),
            ),
            Text('${productive.toStringAsFixed(1)} h', style: AppText.caption),
          ]),
          const SizedBox(height: 4),
          Text(status,
              style: AppText.caption
                  .copyWith(color: bad ? AppColors.warning : null)),
          for (final i in routeIssues.take(3))
            Text('• ${i.message}',
                style: AppText.caption.copyWith(color: AppColors.warning)),
          if (target != null &&
              dayIssues.isEmpty &&
              productive < target &&
              !worker.isEmergency)
            Text(
                'Below the ${target.toStringAsFixed(1)} h target (advisory only).',
                style: AppText.caption),
        ]),
      ),
    );
  }
}

// ── Queue ─────────────────────────────────────────────────────────────────────
class OpsQueue extends StatelessWidget {
  final OpsData data;
  const OpsQueue({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final queue = data.bookings.where(needsReview).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        final bySlot = a.slotId.compareTo(b.slotId);
        return bySlot != 0 ? bySlot : a.createdAt.compareTo(b.createdAt);
      });
    final overdue = queue.where((b) => isOverdue(b, data.settings)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        NoticeBox(
          icon: Icons.timer_outlined,
          warning: overdue > 0,
          text: overdue > 0
              ? '$overdue request${overdue == 1 ? ' is' : 's are'} past the ${data.settings.reviewTargetMinutes}-minute internal response target. Each one holds window capacity until you act.'
              : 'Internal response target: ${data.settings.reviewTargetMinutes} minutes (not shown to customers). Requests hold window capacity until confirmed, offered another time, or rejected.',
        ),
        const SizedBox(height: 12),
        if (queue.isEmpty)
          const AppCard(
              child: Text('No requests waiting. New ones appear here.'))
        else
          for (final b in queue) BookingCard(booking: b, data: data),
      ],
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────
class BookingCard extends ConsumerWidget {
  final BookingRecord booking;
  final OpsData data;
  final bool lateRisk;
  const BookingCard(
      {super.key,
      required this.booking,
      required this.data,
      this.lateRisk = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final cloud = ref.watch(bookingCloudProvider);
    final worker = data.worker(b.workerId);
    final age = DateTime.now().difference(b.createdAt);
    final overdue = isOverdue(b, data.settings);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(b.serviceName, style: AppText.bodyStrong)),
            Pill(b.status.label,
                tone: needsReview(b)
                    ? PillTone.warning
                    : b.status.isFinal
                        ? PillTone.neutral
                        : PillTone.brand),
          ]),
          const SizedBox(height: 6),
          Text(
              '${b.ref} · ${shortDate(b.date)} · prefers ${slotById(b.slotId)?.range ?? b.slotLabel}',
              style: AppText.small),
          Text(
              '${b.carLabel} · ${durationLabel(b.serviceDurationMinutes)} on site'
              '${b.durationNeedsConfirmation ? ' (+ extras time unconfirmed)' : ''}'
              ' · ${rupees(b.payable)}',
              style: AppText.small),
          if (b.extras.isNotEmpty)
            Text(
                'Extras: ${b.extras.map((e) => e.$2 > 1 ? '${e.$1} × ${e.$2}' : e.$1).join(', ')}',
                style: AppText.caption),
          const SizedBox(height: 6),
          Text(
              '${b.forSomeoneElse ? 'Booker' : 'Customer'}: ${b.name} · +91 ${b.phone}',
              style: AppText.small),
          if (b.forSomeoneElse)
            Text(
                'Car owner: ${b.recipientName ?? '-'}${b.recipientPhone == null ? '' : ' · +91 ${b.recipientPhone}'}'
                '${b.notifyRecipient ? ' · consented to updates' : ''}',
                style: AppText.small),
          Text(b.address, style: AppText.small),
          Row(children: [
            Text(
                switch (b.coverage) {
                  Coverage.covered => 'Inside service area',
                  Coverage.notCovered => 'OUTSIDE service area',
                  Coverage.unverified => 'Area not verified',
                },
                style: AppText.caption.copyWith(
                    color: b.coverage == Coverage.covered
                        ? null
                        : AppColors.warning)),
            if (b.mapsUrl != null)
              TextButton(
                  onPressed: () => openLink(context, b.mapsUrl!),
                  child: const Text('Open pin')),
          ]),
          if (worker != null) ...[
            Text(
                'Worker: ${worker.name}${b.plannedArrivalMinute == null ? '' : ' · arrive ${clockLabel(b.plannedArrivalMinute!)}'}'
                '${b.plannedFinishMinute == null ? '' : ' · finish ${clockLabel(b.plannedFinishMinute!)}'}',
                style: AppText.caption),
            Text(
                'Leg in: ${_leg(b.legIn)}${b.returnLeg == null ? '' : ' · leg home: ${_leg(b.returnLeg)}'}',
                style: AppText.caption),
          ],
          if (b.riskFlag != null || lateRisk)
            _flag(b.riskFlag ?? 'Route check failed: see the worker above'),
          if (b.customerChangeRequest != null)
            _flag('Customer asks: ${b.customerChangeRequest}'),
          if (b.operationsNote != null)
            Text(b.operationsNote!, style: AppText.caption),
          if (b.creditPreserved)
            Text('Package credit kept (team-caused reschedule).',
                style: AppText.caption),
          if (b.status == BookingStatus.requested)
            Text(
                'Waiting ${age.inHours > 0 ? '${age.inHours} h ' : ''}${age.inMinutes % 60} min${overdue ? ' · past target' : ''}',
                style: AppText.caption
                    .copyWith(color: overdue ? AppColors.error : null)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final a in _actions(context, cloud, b)) a,
          ]),
        ]),
      ),
    );
  }

  static String _leg(RouteLeg? leg) => leg == null
      ? 'missing'
      : '${leg.km.toStringAsFixed(leg.km == leg.km.roundToDouble() ? 0 : 1)} km / ${leg.minutes} min${leg.isManual ? ' (manual estimate)' : ''}';

  Widget _flag(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text,
            style: AppText.caption.copyWith(color: AppColors.warning)),
      );

  List<Widget> _actions(
      BuildContext context, BookingCloud cloud, BookingRecord b) {
    Widget primary(String label, IconData icon, VoidCallback onTap) =>
        FilledButton.icon(
            onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label));
    Widget secondary(String label, IconData icon, VoidCallback onTap) =>
        OutlinedButton.icon(
            onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label));

    void assign() => assignFlow(context, cloud, data, b);
    void offer() => offerAlternativeFlow(context, cloud, b);
    void weather() => siteIncidentFlow(context, cloud, b);
    Future<void> cancel() async {
      final reason = await askText(context,
          title: 'Cancel booking',
          label: 'Reason (shown to the customer)',
          action: 'Cancel booking');
      if (reason != null && context.mounted) {
        await runOpsAction(context, () => cloud.cancel(b, reason),
            'Booking cancelled; capacity released.');
      }
    }

    return switch (b.status) {
      BookingStatus.requested || BookingStatus.teamReview => [
          primary('Assign & confirm', Icons.route_rounded, assign),
          secondary('Ask for details', Icons.help_outline_rounded, () async {
            final q = await askText(context,
                title: 'Ask the customer',
                label: 'Your question (shown in their app)',
                action: 'Send');
            if (q != null && context.mounted) {
              await runOpsAction(context, () => cloud.askForDetails(b, q),
                  'Question shown to the customer.');
            }
          }),
          secondary('Offer another time', Icons.schedule_rounded, offer),
          if (b.customerChangeRequest != null)
            secondary('Apply new time', Icons.edit_calendar_outlined,
                () => applyNewTimeFlow(context, cloud, b)),
          secondary('Reject', Icons.block_rounded, () async {
            final reason = await askText(context,
                title: 'Unable to serve',
                label: 'Reason (shown to the customer)',
                action: 'Reject');
            if (reason != null && context.mounted) {
              await runOpsAction(context, () => cloud.reject(b, reason),
                  'Marked unable to serve; capacity released.');
            }
          }),
          secondary('Cancel', Icons.event_busy_outlined, cancel),
        ],
      BookingStatus.confirmed => [
          primary(
              'On the way',
              Icons.directions_car_rounded,
              () => runOpsAction(
                  context, () => cloud.markOnTheWay(b), 'Marked on the way.')),
          secondary(
              'Reassign / re-enter route', Icons.swap_horiz_rounded, assign),
          secondary('Rain / access', Icons.umbrella_outlined, weather),
          secondary('Offer another time', Icons.schedule_rounded, offer),
          secondary('Cancel', Icons.event_busy_outlined, cancel),
        ],
      BookingStatus.onTheWay => [
          primary(
              'Work started',
              Icons.play_arrow_rounded,
              () => runOpsAction(
                  context, () => cloud.markInService(b), 'Marked in service.')),
          secondary('Rain / access', Icons.umbrella_outlined, weather),
        ],
      BookingStatus.inService => [
          primary('Complete & record payment', Icons.check_rounded,
              () => completeFlow(context, cloud, b)),
        ],
      BookingStatus.rescheduleNeeded => [
          primary('Apply agreed time', Icons.edit_calendar_outlined,
              () => applyNewTimeFlow(context, cloud, b)),
          secondary('Offer another time', Icons.schedule_rounded, offer),
          secondary('Cancel', Icons.event_busy_outlined, cancel),
        ],
      _ => const [],
    };
  }
}
