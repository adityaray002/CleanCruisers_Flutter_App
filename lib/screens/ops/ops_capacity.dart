import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/scheduling.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../models/booking.dart';
import '../../providers/app_providers.dart';
import '../../widgets/ui.dart';
import 'ops_actions.dart';
import 'ops_dashboard_screen.dart';

class OpsCapacity extends ConsumerWidget {
  final OpsData data;
  const OpsCapacity({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(bookingCloudProvider);
    final today = dateOnly(DateTime.now());
    final manager = data.staff.isManager;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const NoticeBox(
          icon: Icons.tune_rounded,
          text:
              'Caps and closures limit what customers can request. They never create worker time: a request still needs a worker whose whole day route validates before it is confirmed. '
              'Customers never see counts, only whether a window is open.',
        ),
        const SizedBox(height: 12),
        Text('Next ${kBookingWindowDays + 1} days', style: AppText.h2),
        const SizedBox(height: 6),
        for (var i = 0; i <= kBookingWindowDays; i++)
          _DayRow(
            date: addDays(today, i),
            onEdit: manager
                ? (cap) => _editDay(context, cloud, addDays(today, i), cap)
                : null,
          ),
        const SizedBox(height: 20),
        _SettingsCard(data: data, cloud: cloud, editable: manager),
        const SizedBox(height: 20),
        _AreasCard(cloud: cloud, editable: manager),
      ],
    );
  }

  Future<void> _editDay(BuildContext context, BookingCloud cloud, DateTime date,
      CapacityDay cap) async {
    var closed = cap.closed;
    final closedWindows = {...cap.closedWindows};
    final caps = {
      for (final s in timeSlots)
        s.id: TextEditingController(text: cap.caps[s.id]?.toString() ?? ''),
    };
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Capacity · ${shortDate(date)}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Close the whole date'),
                  value: closed,
                  onChanged: (v) => setState(() => closed = v),
                ),
                const Divider(),
                Text(
                    'Per window: tick to open, cap = max requests (blank = no cap).',
                    style: AppText.caption),
                for (final s in timeSlots)
                  Row(children: [
                    Checkbox(
                      value: !closedWindows.contains(s.id),
                      onChanged: closed
                          ? null
                          : (v) => setState(() => v == true
                              ? closedWindows.remove(s.id)
                              : closedWindows.add(s.id)),
                    ),
                    Expanded(
                        child: Text('${s.range} · held ${cap.held[s.id] ?? 0}',
                            style: AppText.small)),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: caps[s.id],
                        enabled: !closed,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            isDense: true, hintText: 'cap'),
                      ),
                    ),
                  ]),
                const SizedBox(height: 8),
                TextField(
                  controller: reason,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Reason (logged with your name)'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Back')),
            FilledButton(
                onPressed: reason.text.trim().length < 3
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final newCaps = {
      for (final e in caps.entries)
        if (int.tryParse(e.value.text.trim()) case final n? when n >= 0)
          e.key: n,
    };
    final why = reason.text;
    for (final c in [...caps.values, reason]) {
      c.dispose();
    }
    if (ok != true || !context.mounted) return;
    await runOpsAction(
        context,
        () => cloud.saveCapacity(date,
            closed: closed,
            closedWindows: closedWindows,
            caps: newCaps,
            reason: why),
        'Capacity saved for ${shortDate(date)}.');
  }
}

class _DayRow extends ConsumerWidget {
  final DateTime date;
  final void Function(CapacityDay)? onEdit;
  const _DayRow({required this.date, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cap = ref.watch(capacityProvider(dateKey(date))).valueOrNull ??
        CapacityDay.open;
    final held = cap.held.values.fold(0, (a, b) => a + b);
    final summary = cap.closed
        ? 'Closed${cap.note == null ? '' : ' · ${cap.note}'}'
        : [
            '$held held',
            if (cap.closedWindows.isNotEmpty)
              '${cap.closedWindows.length} window${cap.closedWindows.length == 1 ? '' : 's'} closed',
            if (cap.caps.isNotEmpty) 'caps on ${cap.caps.length}',
            for (final s in timeSlots)
              if (cap.isFull(s.id)) '${s.id} full',
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onEdit == null ? null : () => onEdit!(cap),
        child: Row(children: [
          SizedBox(
              width: 110,
              child: Text(friendlyDate(date), style: AppText.smallStrong)),
          Expanded(
            child: Text(summary,
                style: AppText.caption
                    .copyWith(color: cap.closed ? AppColors.warning : null)),
          ),
          if (onEdit != null)
            const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.textSubtle),
        ]),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final OpsData data;
  final BookingCloud cloud;
  final bool editable;
  const _SettingsCard(
      {required this.data, required this.cloud, required this.editable});

  @override
  Widget build(BuildContext context) {
    final s = data.settings;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Operating settings', style: AppText.h3)),
          if (editable)
            TextButton(
                onPressed: () => _edit(context), child: const Text('Edit')),
        ]),
        Text(
            'Review target ${s.reviewTargetMinutes} min (internal) · buffer ${s.bufferMinutes} min per job · '
            'lunch at ${s.lunchStartOptions.map(clockLabel).join(' or ')} · '
            'productive target ${s.productiveHoursTarget == null ? 'not set' : '${s.productiveHoursTarget} h/worker (advisory)'}',
            style: AppText.small),
        const SizedBox(height: 6),
        Text(
            'Fixed rules: duty 8 AM, first arrival 8:30 AM, customer work done by 6 PM, every regular road leg ≤ 25 km, emergency worker back at standby by 11 AM.',
            style: AppText.caption),
      ]),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final s = data.settings;
    final review = TextEditingController(text: '${s.reviewTargetMinutes}');
    final buffer = TextEditingController(text: '${s.bufferMinutes}');
    final target =
        TextEditingController(text: s.productiveHoursTarget?.toString() ?? '');
    final lunch = {...s.lunchStartOptions};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Operating settings'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: review,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Internal review target (minutes)')),
              TextField(
                  controller: buffer,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Buffer per job (minutes)')),
              TextField(
                  controller: target,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText:
                          'Productive hours target per worker (blank = none)')),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final m in const [13 * 60, 13 * 60 + 30])
                  FilterChip(
                    label: Text('Lunch ${clockLabel(m)}'),
                    selected: lunch.contains(m),
                    onSelected: (v) => setState(() {
                      if (v) {
                        lunch.add(m);
                      } else if (lunch.length > 1) {
                        lunch.remove(m);
                      }
                    }),
                  ),
              ]),
            ]),
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
    final next = OpsSettings(
      reviewTargetMinutes:
          int.tryParse(review.text.trim()) ?? s.reviewTargetMinutes,
      bufferMinutes: int.tryParse(buffer.text.trim()) ?? s.bufferMinutes,
      lunchStartOptions: lunch.toList()..sort(),
      productiveHoursTarget: double.tryParse(target.text.trim()),
    );
    for (final c in [review, buffer, target]) {
      c.dispose();
    }
    if (ok != true || !context.mounted) return;
    await runOpsAction(
        context, () => cloud.saveOpsSettings(next), 'Settings saved.');
  }
}

class _AreasCard extends ConsumerWidget {
  final BookingCloud cloud;
  final bool editable;
  const _AreasCard({required this.cloud, required this.editable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(serviceAreasProvider).valueOrNull ?? const [];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Service areas', style: AppText.h3)),
          if (editable)
            TextButton(
                onPressed: () => _add(context, ref, areas),
                child: const Text('Add area')),
        ]),
        if (areas.isEmpty)
          Text(
              'None set up. Customers see "address to be confirmed" and you verify each address before confirming.',
              style: AppText.small)
        else
          for (final a in areas)
            Row(children: [
              Expanded(
                  child: Text('${a.name} · ${a.polygon.length} points',
                      style: AppText.small)),
              if (editable)
                IconButton(
                  tooltip: 'Remove ${a.name}',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: () async {
                    final ok = await runOpsAction(
                        context,
                        () => cloud.saveServiceAreas(
                            areas.where((x) => x != a).toList()),
                        'Removed ${a.name}.');
                    if (ok) ref.invalidate(serviceAreasProvider);
                  },
                ),
            ]),
      ]),
    );
  }

  Future<void> _add(
      BuildContext context, WidgetRef ref, List<ServiceArea> areas) async {
    final name = await askText(context,
        title: 'New service area', label: 'Area name, e.g. West Delhi');
    if (name == null || !context.mounted) return;
    final points = await askText(context,
        title: 'Boundary of $name',
        label:
            'Corner points in order, one "lat,lng" per line or separated by ";" (at least 3). Copy them from Google Maps.',
        action: 'Save area',
        minLength: 10);
    if (points == null || !context.mounted) return;
    final polygon = [
      for (final part in points.split(RegExp(r'[;\n]')))
        if (parsePin(part) case final p?) p,
    ];
    if (polygon.length < 3) {
      showMessage(context, 'Need at least 3 valid points.');
      return;
    }
    final ok = await runOpsAction(
        context,
        () => cloud.saveServiceAreas([...areas, ServiceArea(name, polygon)]),
        'Saved $name. New bookings with a map pin are checked against it.');
    if (ok) ref.invalidate(serviceAreasProvider);
  }
}
