import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../models/service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/ui.dart';
import 'ops_actions.dart';
import 'ops_dashboard_screen.dart';

class OpsRoster extends ConsumerWidget {
  final OpsData data;
  const OpsRoster({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(bookingCloudProvider);
    final regular = data.workers.where((w) => !w.isEmergency).toList();
    final emergency = data.workers.where((w) => w.isEmergency).toList();
    final manager = data.staff.isManager;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        NoticeBox(
          icon: Icons.groups_outlined,
          text:
              '${regular.where((w) => w.active).length} active regular workers, ${emergency.where((w) => w.active).length} emergency cover. '
              'Keep weekly off, leave and skills current here; the system uses them to block impossible assignments. '
              'Workers report problems through you for now (no worker login yet).',
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('Workers', style: AppText.h2)),
          if (manager)
            TextButton.icon(
              onPressed: () => _editWorker(context, cloud),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add worker'),
            ),
        ]),
        if (data.workers.isEmpty)
          const AppCard(
              child: Text(
                  'Add five regular workers and one emergency cover worker before assigning bookings.'))
        else
          for (final w in data.workers)
            _WorkerTile(
              worker: w,
              onEdit: manager ? () => _editWorker(context, cloud, w) : null,
              onDisruption: () => _reportDisruption(context, cloud, w),
              onResolve: (date) => runOpsAction(
                  context,
                  () => cloud.resolveDisruption(w, DateTime.parse(date)),
                  'Disruption cleared for ${w.name}.'),
            ),
        const SizedBox(height: 20),
        Text('Open incidents', style: AppText.h2),
        const SizedBox(height: 6),
        if (data.incidents.isEmpty)
          const AppCard(child: Text('No open incidents.'))
        else
          for (final i in data.incidents)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Text(
                    '${i['date']} · ${i['type']} · ${data.worker(i['workerId'] as String?)?.name ?? 'site'}\n'
                    '${i['note'] ?? ''}${(i['bookingRefs'] as List?)?.isNotEmpty == true ? '\nAffects: ${(i['bookingRefs'] as List).join(', ')}' : ''}',
                    style: AppText.small),
              ),
            ),
      ],
    );
  }

  Future<void> _reportDisruption(
      BuildContext context, BookingCloud cloud, WorkerRecord w) async {
    var type = DisruptionType.late;
    var date = dateOnly(DateTime.now());
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Report a problem · ${w.name}'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<DisruptionType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'What happened'),
                items: [
                  for (final t in DisruptionType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => type = v ?? type),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('Date: ${shortDate(date)}')),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: dateOnly(DateTime.now()),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (p != null) setState(() => date = dateOnly(p));
                  },
                  child: const Text('Change'),
                ),
              ]),
              TextField(
                controller: note,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Details'),
              ),
              const SizedBox(height: 8),
              Text(
                  'Their confirmed jobs that day get flagged at risk, and no new work can be assigned to them that day until you clear it.',
                  style: AppText.caption),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Back')),
            FilledButton(
                onPressed: note.text.trim().length < 3
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Report')),
          ],
        ),
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (ok != true || !context.mounted) return;
    await runOpsAction(
        context,
        () => cloud.reportDisruption(w, date, type, text),
        'Reported. Check the Today board for flagged jobs and reassign them.');
  }

  Future<void> _editWorker(BuildContext context, BookingCloud cloud,
      [WorkerRecord? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final area = TextEditingController(text: existing?.homeArea ?? '');
    var dayOff =
        existing?.weeklyOff.isNotEmpty == true ? existing!.weeklyOff : 'Sunday';
    var emergency = existing?.isEmergency ?? false;
    var active = existing?.active ?? true;
    final skills = {...?existing?.skills};
    final leave = [...?existing?.unavailableDates];
    final saved = await showDialog<WorkerRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add worker' : 'Worker details'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(
                    controller: area,
                    decoration: InputDecoration(
                        labelText: emergency
                            ? 'Standby office address'
                            : 'Home base (staff-only, never shown to customers)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: dayOff,
                  decoration:
                      const InputDecoration(labelText: 'Weekly day off'),
                  items: [
                    for (final d in weekdayNames)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setState(() => dayOff = v ?? dayOff),
                ),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Emergency cover worker'),
                    subtitle:
                        const Text('One morning job, back at standby by 11 AM'),
                    value: emergency,
                    onChanged: (v) => setState(() => emergency = v)),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setState(() => active = v)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Equipped for (none ticked = all)',
                      style: AppText.smallStrong),
                ),
                Wrap(spacing: 6, children: [
                  for (final c in ServiceCategory.values)
                    FilterChip(
                      label: Text(serviceCategoryNames[c]!),
                      selected: skills.contains(c),
                      onSelected: (v) =>
                          setState(() => v ? skills.add(c) : skills.remove(c)),
                    ),
                ]),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child:
                      Text('Approved leave dates', style: AppText.smallStrong),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: dateOnly(DateTime.now()),
                      lastDate: DateTime.now().add(const Duration(days: 120)),
                    );
                    if (p != null && !leave.contains(dateKey(p))) {
                      setState(() => leave.add(dateKey(p)));
                    }
                  },
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Add leave date'),
                ),
                Wrap(spacing: 6, children: [
                  for (final d in leave..sort())
                    InputChip(
                        label: Text(d),
                        onDeleted: () => setState(() => leave.remove(d))),
                ]),
                const SizedBox(height: 6),
                Text(
                    'To cover extra leave by working a weekly off, change the weekly day off for that week and note it in the reason.',
                    style: AppText.caption),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().length < 2) return;
                Navigator.pop(
                  ctx,
                  WorkerRecord(
                    id: existing?.id ??
                        'worker_${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    isEmergency: emergency,
                    active: active,
                    homeArea: area.text.trim(),
                    weeklyOff: dayOff,
                    unavailableDates: leave,
                    skills: skills,
                    disruptions: existing?.disruptions ?? const {},
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    area.dispose();
    if (saved == null || !context.mounted) return;
    if (saved.isEmergency &&
        saved.active &&
        data.workers
            .any((w) => w.id != saved.id && w.isEmergency && w.active)) {
      showMessage(context,
          'There is already an active emergency cover worker. Deactivate them first.');
      return;
    }
    await runOpsAction(
        context, () => cloud.saveWorker(saved), 'Saved ${saved.name}.');
  }
}

class _WorkerTile extends StatelessWidget {
  final WorkerRecord worker;
  final VoidCallback? onEdit;
  final VoidCallback onDisruption;
  final ValueChanged<String> onResolve;
  const _WorkerTile(
      {required this.worker,
      required this.onEdit,
      required this.onDisruption,
      required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final upcomingLeave = w.unavailableDates
        .where((d) => d.compareTo(dateKey(DateTime.now())) >= 0)
        .toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: onEdit,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
                w.isEmergency
                    ? Icons.health_and_safety_outlined
                    : Icons.person_outline_rounded,
                color: w.active ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(w.name, style: AppText.smallStrong)),
            if (!w.active) const Pill('Inactive'),
          ]),
          const SizedBox(height: 4),
          Text(
              '${w.isEmergency ? 'Emergency cover' : 'Regular'} · off ${w.weeklyOff.isEmpty ? 'not set' : w.weeklyOff}'
              ' · ${w.skills.isEmpty ? 'all services' : w.skills.map((s) => serviceCategoryNames[s]).join(', ')}'
              '${w.homeArea.isEmpty ? ' · base not set' : ''}',
              style: AppText.caption),
          if (upcomingLeave.isNotEmpty)
            Text('Leave: ${upcomingLeave.take(5).join(', ')}',
                style: AppText.caption),
          for (final e in w.disruptions.entries)
            Row(children: [
              Expanded(
                child: Text('${e.key}: ${e.value.label}',
                    style: AppText.caption.copyWith(color: AppColors.warning)),
              ),
              TextButton(
                  onPressed: () => onResolve(e.key),
                  child: const Text('Clear')),
            ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onDisruption,
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: const Text('Report late / puncture / absence'),
            ),
          ),
        ]),
      ),
    );
  }
}
