import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/scheduling.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../models/booking.dart';
import '../../widgets/ui.dart';
import 'ops_dashboard_screen.dart';

/// Runs a desk action and reports the outcome.
Future<bool> runOpsAction(BuildContext context, Future<void> Function() action,
    String success) async {
  try {
    await action();
    if (context.mounted) showMessage(context, success);
    return true;
  } on BookingCloudException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  } on Object catch (_) {
    if (context.mounted) {
      showMessage(context,
          'Could not save. Check your connection and permissions, then try again.');
    }
  }
  return false;
}

/// Asks for a short text such as a reason. Returns null if cancelled.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String? initial,
  String action = 'Save',
  int minLength = 3,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: label),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          FilledButton(
            onPressed: controller.text.trim().length < minLength
                ? null
                : () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}

/// Picks a date (next 14 days) and an arrival window that fits the service.
Future<(DateTime, TimeSlot)?> pickDateAndWindow(
    BuildContext context, BookingRecord b,
    {DateTime? initialDate, String? initialSlot}) async {
  final today = dateOnly(DateTime.now());
  final start = initialDate != null && !initialDate.isBefore(today)
      ? initialDate
      : (b.date.isBefore(today) ? today : b.date);
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: today,
    lastDate: addDays(today, kBookingWindowDays),
  );
  if (date == null || !context.mounted) return null;
  final fits = [
    for (final s in timeSlots)
      if (s.isAvailable(date) &&
          canFinishByClose(s.startMinute, b.serviceDurationMinutes))
        s
  ];
  if (fits.isEmpty) {
    showMessage(context,
        'No window on that date can fit ${durationLabel(b.serviceDurationMinutes)} before 6 PM.');
    return null;
  }
  var selected =
      fits.where((s) => s.id == initialSlot).firstOrNull ?? fits.first;
  final slot = await showDialog<TimeSlot>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Arrival window · ${shortDate(date)}'),
      content: StatefulBuilder(
        builder: (ctx, setState) => DropdownButton<TimeSlot>(
          value: selected,
          isExpanded: true,
          items: [
            for (final s in fits)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (v) => setState(() => selected = v ?? selected),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: const Text('Use this time')),
      ],
    ),
  );
  return slot == null ? null : (date, slot);
}

Future<void> offerAlternativeFlow(
    BuildContext context, BookingCloud cloud, BookingRecord b) async {
  final pick = await pickDateAndWindow(context, b);
  if (pick == null || !context.mounted) return;
  final why = await askText(context,
      title: 'Why can\'t the requested time work?',
      label: 'Shown to the customer, e.g. "Our team is fully booked then."',
      action: 'Offer this time');
  if (why == null || !context.mounted) return;
  await runOpsAction(
      context,
      () => cloud.offerAlternative(b, pick.$1, pick.$2, why),
      'Alternative offered. The customer sees it in the app.');
}

Future<void> applyNewTimeFlow(
    BuildContext context, BookingCloud cloud, BookingRecord b) async {
  final pick = await pickDateAndWindow(context, b,
      initialDate: b.offeredDate, initialSlot: b.offeredSlotId);
  if (pick == null || !context.mounted) return;
  await runOpsAction(context, () => cloud.applyNewTime(b, pick.$1, pick.$2),
      'Booking moved. Assign a worker to confirm it.');
}

Future<void> completeFlow(
    BuildContext context, BookingCloud cloud, BookingRecord b) async {
  final amount = TextEditingController(text: '${b.payable}');
  final km = TextEditingController();
  final minutes = TextEditingController();
  var method = PaymentMethod.cash;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Mark completed'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Record only what was actually collected.',
                  style: AppText.caption),
              const SizedBox(height: 8),
              TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Amount collected (₹)')),
              const SizedBox(height: 8),
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
                  ButtonSegment(value: PaymentMethod.upi, label: Text('UPI')),
                ],
                selected: {method},
                onSelectionChanged: (v) => setState(() => method = v.first),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: km,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Actual km driven for this job (optional)')),
              TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Actual minutes of work (optional)')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    ),
  );
  final collected = int.tryParse(amount.text.trim());
  final actualKm = double.tryParse(km.text.trim());
  final actualMinutes = int.tryParse(minutes.text.trim());
  amount.dispose();
  km.dispose();
  minutes.dispose();
  if (ok != true || !context.mounted) return;
  if (collected == null || collected < 0) {
    showMessage(context, 'Enter the amount collected.');
    return;
  }
  await runOpsAction(
      context,
      () => cloud.complete(b,
          amount: collected,
          method: method,
          actualKm: actualKm,
          actualMinutes: actualMinutes),
      'Completed and payment recorded.');
}

Future<void> siteIncidentFlow(
    BuildContext context, BookingCloud cloud, BookingRecord b) async {
  final kind = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('What happened?'),
      children: [
        SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'weather'),
            child: const Text('Rain / weather')),
        SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'access'),
            child: const Text('Couldn\'t access the car / site')),
      ],
    ),
  );
  if (kind == null || !context.mounted) return;
  final note = await askText(context,
      title: 'Incident note (internal)',
      label: 'What the worker found',
      action: 'Mark reschedule needed');
  if (note == null || !context.mounted) return;
  await runOpsAction(context, () => cloud.reportSiteIncident(b, kind, note),
      'Marked "Reschedule needed". Offer the customer a new time.');
}

// ── Assignment ────────────────────────────────────────────────────────────────

/// Stored day plan for [worker] on [date], from the legs already entered.
DayPlan storedDayPlan(OpsData data, WorkerRecord worker, DateTime date) {
  final day = dayBookings(data, worker.id, date);
  return planWorkerDay(
    worker: worker,
    date: date,
    jobs: [for (final b in day) jobFor(b, b.legIn)],
    returnLeg: day.isEmpty ? null : day.last.returnLeg,
    rules: data.settings.rules,
  );
}

List<BookingRecord> dayBookings(OpsData data, String workerId, DateTime date,
        {String? exclude}) =>
    data.bookings
        .where((b) =>
            b.workerId == workerId &&
            b.ref != exclude &&
            dateOnly(b.date) == dateOnly(date) &&
            b.status.holdsCapacity)
        .toList()
      ..sort((a, b) => slotById(a.slotId)!
          .startMinute
          .compareTo(slotById(b.slotId)!.startMinute));

PlannedJob jobFor(BookingRecord b, RouteLeg? legIn) => PlannedJob(
      ref: b.ref,
      windowStart: slotById(b.slotId)!.startMinute,
      windowEnd: slotById(b.slotId)!.endMinute,
      serviceMinutes: b.serviceDurationMinutes,
      category: b.category,
      legIn: legIn,
    );

Future<void> assignFlow(BuildContext context, BookingCloud cloud, OpsData data,
    BookingRecord b) async {
  if (data.workers.where((w) => w.active).isEmpty) {
    showMessage(context, 'Add active workers on the Roster tab first.');
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _AssignDialog(cloud: cloud, data: data, booking: b),
  );
}

class _AssignDialog extends StatefulWidget {
  final BookingCloud cloud;
  final OpsData data;
  final BookingRecord booking;
  const _AssignDialog(
      {required this.cloud, required this.data, required this.booking});

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late WorkerRecord? _worker = widget.data.worker(widget.booking.workerId) ??
      widget.data.workers.where((w) => w.active && !w.isEmergency).firstOrNull;
  final _inKm = TextEditingController();
  final _inMin = TextEditingController();
  final _outKm = TextEditingController();
  final _outMin = TextEditingController();
  final _reason = TextEditingController();
  bool _addressVerified = false;
  bool _saving = false;
  String? _error;

  BookingRecord get b => widget.booking;

  @override
  void initState() {
    super.initState();
    final legIn = b.legIn;
    if (legIn != null) {
      _inKm.text = _num(legIn.km);
      _inMin.text = '${legIn.minutes}';
    }
  }

  @override
  void dispose() {
    for (final c in [_inKm, _inMin, _outKm, _outMin, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  RouteLeg? _leg(TextEditingController km, TextEditingController min) {
    final k = double.tryParse(km.text.trim());
    final m = int.tryParse(min.text.trim());
    if (k == null || m == null || k < 0 || m < 0) return null;
    return RouteLeg(km: k, minutes: m, recordedAt: DateTime.now());
  }

  /// Neighbours on the worker's route if this booking joins it.
  (BookingRecord?, BookingRecord?) _neighbours(WorkerRecord w) {
    final others = dayBookings(widget.data, w.id, b.date, exclude: b.ref);
    final start = slotById(b.slotId)!.startMinute;
    final before = others.where((o) => slotById(o.slotId)!.startMinute < start);
    final after = others.where((o) => slotById(o.slotId)!.startMinute >= start);
    return (before.lastOrNull, after.firstOrNull);
  }

  DayPlan? _preview() {
    final w = _worker;
    if (w == null) return null;
    final legIn = _leg(_inKm, _inMin);
    final legOut = _leg(_outKm, _outMin);
    final others = dayBookings(widget.data, w.id, b.date, exclude: b.ref);
    final (_, next) = _neighbours(w);
    final jobs = [
      for (final o in others) jobFor(o, identical(o, next) ? legOut : o.legIn),
      jobFor(b, legIn),
    ];
    return planWorkerDay(
      worker: w,
      date: b.date,
      jobs: jobs,
      returnLeg: next == null
          ? legOut
          : (others.isEmpty ? null : others.last.returnLeg),
      rules: widget.data.settings.rules,
      allowEmergencyLongLegs: _emergencyDispatch,
    );
  }

  bool get _emergencyDispatch =>
      _worker?.isEmergency == true &&
      widget.data.staff.isManager &&
      _reason.text.trim().length >= 8;

  Future<void> _save() async {
    final w = _worker;
    final legIn = _leg(_inKm, _inMin);
    final legOut = _leg(_outKm, _outMin);
    if (w == null || legIn == null || legOut == null) {
      setState(() => _error =
          'Choose a worker and enter both legs (road km and drive minutes).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final plan = await widget.cloud.assignWorker(
        booking: b,
        worker: w,
        legIn: legIn,
        legOut: legOut,
        rules: widget.data.settings.rules,
        staff: widget.data.staff,
        addressVerified: _addressVerified,
        emergencyDispatchReason: _reason.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context,
          'Confirmed with ${w.name}, arriving around ${clockLabel(plan.stopFor(b.ref)!.arriveAt)}. The customer sees Confirmed.');
    } on BookingCloudException catch (e) {
      setState(() => _error = e.message);
    } on Object catch (_) {
      setState(() => _error =
          'Could not save. Check your connection and permissions, then try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _worker;
    final (prev, next) = w == null ? (null, null) : _neighbours(w);
    final base = w?.isEmergency == true ? 'standby office' : 'home';
    final fromLabel = prev == null ? base : prev.ref;
    final toLabel = next == null ? base : next.ref;
    final plan = _preview();
    final me = plan?.stopFor(b.ref);
    final others = w == null
        ? const <BookingRecord>[]
        : dayBookings(widget.data, w.id, b.date, exclude: b.ref);

    return AlertDialog(
      title: const Text('Check route and confirm'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${b.ref} · ${shortDate(b.date)} · prefers ${b.slotLabel}\n'
                  '${durationLabel(b.serviceDurationMinutes)} on site'
                  '${b.durationNeedsConfirmation ? ' + unconfirmed extras time' : ''}'
                  ' · must finish by 6 PM',
                  style: AppText.small),
              const SizedBox(height: 12),
              DropdownButtonFormField<WorkerRecord>(
                initialValue: w,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Worker'),
                items: [
                  for (final worker
                      in widget.data.workers.where((x) => x.active))
                    DropdownMenuItem(
                        value: worker,
                        child: Text(worker.isEmergency
                            ? '${worker.name} · emergency cover'
                            : worker.name)),
                ],
                onChanged: (v) => setState(() {
                  _worker = v;
                  _outKm.clear();
                  _outMin.clear();
                }),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                    'Already on ${w!.name}\'s route: ${others.map((o) => '${o.ref} (${slotById(o.slotId)!.range})').join(', ')}',
                    style: AppText.caption),
              ],
              const SizedBox(height: 12),
              Text('Road distance and drive time from your map app.',
                  style: AppText.caption),
              const SizedBox(height: 4),
              _legRow('$fromLabel → this site', _inKm, _inMin),
              const SizedBox(height: 6),
              _legRow('This site → $toLabel', _outKm, _outMin),
              if (next != null)
                Text(
                    'This replaces the leg into ${next.ref}, because the worker will now come from this site.',
                    style: AppText.caption),
              if (b.coverage != Coverage.covered)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _addressVerified,
                  onChanged: (v) =>
                      setState(() => _addressVerified = v ?? false),
                  title: Text(
                      'Address verified as inside our service area${b.pin == null ? '' : ' (pin attached)'}',
                      style: AppText.small),
                ),
              if (w?.isEmergency == true && widget.data.staff.isManager) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText:
                          'Emergency dispatch reason (only to go beyond 25 km)'),
                ),
              ],
              const SizedBox(height: 12),
              if (plan != null) _PlanPreview(plan: plan, me: me, ref: b.ref),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: AppText.caption.copyWith(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || plan == null || !plan.feasible ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Assign and confirm'),
        ),
      ],
    );
  }

  Widget _legRow(
          String label, TextEditingController km, TextEditingController min) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.smallStrong),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: km,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Road km'))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: min,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Drive minutes'))),
        ]),
      ]);
}

class _PlanPreview extends StatelessWidget {
  final DayPlan plan;
  final StopPlan? me;
  final String ref;
  const _PlanPreview({required this.plan, required this.me, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (plan.feasible && me != null) {
      return NoticeBox(
        icon: Icons.check_circle_outline_rounded,
        text:
            'Route works: arrive around ${clockLabel(me!.arriveAt)}, finish ${clockLabel(me!.workEnd)}.'
            '${plan.lunchAt == null ? '' : ' Lunch ${clockLabel(plan.lunchAt!)}.'}'
            '${plan.endOfDay == null ? '' : ' Back at base ${clockLabel(plan.endOfDay!)}.'}'
            ' Legs are manual estimates.',
      );
    }
    return NoticeBox(
      icon: Icons.block_rounded,
      warning: true,
      text:
          'Can\'t confirm yet:\n${plan.issues.map((i) => '• ${i.message}').join('\n')}',
    );
  }
}
