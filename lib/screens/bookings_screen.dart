import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/booking.dart';
import '../providers/app_providers.dart';
import '../widgets/ui.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(bookingsProvider);
    final upcoming = all.where((b) => b.isUpcoming()).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = all.where((b) => !b.isUpcoming()).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: all.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.event_note_rounded,
                title: 'No bookings yet',
                message: 'Bookings you send from this phone will show up here, '
                    'so you can check the details or message us about them.',
                action: PrimaryButton(
                  label: 'Book a service',
                  expand: false,
                  onPressed: () => context.go('/services'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, 4, AppSpace.page, 32),
              children: [
                if (upcoming.isNotEmpty) ...[
                  _groupTitle('Upcoming'),
                  for (final b in upcoming) _BookingTile(b, upcoming: true),
                ],
                if (past.isNotEmpty) ...[
                  _groupTitle('Past'),
                  for (final b in past) _BookingTile(b, upcoming: false),
                ],
                const SizedBox(height: 8),
                Text(
                  'Bookings are saved on this phone only. Confirmations and changes happen on WhatsApp.',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _groupTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 10),
        child: Text(t.toUpperCase(), style: AppText.overline),
      );
}

class _BookingTile extends StatelessWidget {
  final BookingRecord b;
  final bool upcoming;
  const _BookingTile(this.b, {required this.upcoming});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => context.push('/bookings/${b.ref}'),
        child: Row(children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: upcoming ? AppColors.ink : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(children: [
              Text(monthShort(b.date).toUpperCase(),
                  style: AppText.overline.copyWith(
                      color: upcoming ? AppColors.brand : AppColors.textSubtle,
                      fontSize: 10)),
              Text('${b.date.day}',
                  style: AppText.h2.copyWith(
                      color: upcoming ? Colors.white : AppColors.textMuted)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.serviceName, style: AppText.bodyStrong),
              const SizedBox(height: 2),
              Text('${weekdayShort(b.date)} · ${b.slotLabel}',
                  style: AppText.small),
              const SizedBox(height: 6),
              Row(children: [
                Pill(upcoming ? 'Requested' : 'Past',
                    tone: upcoming ? PillTone.brand : PillTone.neutral),
                const Spacer(),
                Text(rupees(b.total), style: AppText.smallStrong),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
        ]),
      ),
    );
  }
}
