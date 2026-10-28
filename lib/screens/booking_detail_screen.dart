import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import '../widgets/contact_actions.dart';
import '../widgets/ui.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String bookingRef;
  const BookingDetailScreen({super.key, required this.bookingRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bookingsProvider);
    final b = ref.read(bookingsProvider.notifier).byRef(bookingRef);

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

    final upcoming = b.isUpcoming();
    final serviceStillOffered = serviceById(b.serviceId) != null;

    return Scaffold(
      appBar: AppBar(title: Text('Booking ${b.ref}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 32),
        children: [
          AppCard(
            color: upcoming ? AppColors.primarySoft : AppColors.surfaceAlt,
            child: Row(children: [
              Icon(
                  upcoming
                      ? Icons.hourglass_top_rounded
                      : Icons.history_rounded,
                  color: upcoming ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(upcoming ? 'Requested' : 'Past booking',
                          style: AppText.bodyStrong),
                      Text(
                        upcoming
                            ? 'Our team confirms the slot on WhatsApp. No reply yet? Message us below.'
                            : 'Sent ${shortDate(b.createdAt)}.',
                        style: AppText.small,
                      ),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(children: [
              InfoRow(
                  icon: Icons.local_car_wash_outlined,
                  label: 'Service',
                  value: b.serviceName),
              const Divider(),
              InfoRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Car',
                  value: b.carLabel),
              const Divider(),
              InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'When',
                  value: '${friendlyDate(b.date)} · ${b.slotLabel}'),
              const Divider(),
              InfoRow(
                  icon: Icons.home_outlined,
                  label: 'Address',
                  value: b.address),
              const Divider(),
              InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Contact',
                  value: '${b.name} · +91 ${b.phone}'),
            ]),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(children: [
              _line(b.serviceName, b.servicePrice),
              for (final (n, q, p) in b.extras) _line(q > 1 ? '$n × $q' : n, p),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider()),
              Row(children: [
                Expanded(
                    child: Text('Estimated total', style: AppText.bodyStrong)),
                Text(rupees(b.total), style: AppText.price),
              ]),
              if (kPayAfterService) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Pay the team after the service.',
                      style: AppText.caption),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: upcoming ? 'Message us about this booking' : 'Message us',
            icon: Icons.chat_rounded,
            onPressed: () => openWhatsApp(context,
                message: 'Hi CleanCruisers, about my booking ${b.ref} '
                    '(${b.serviceName}, ${shortDate(b.date)}): '),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: SecondaryButton(
                label: 'Call',
                icon: Icons.call_outlined,
                onPressed: () => callUs(context),
              ),
            ),
            if (serviceStillOffered) ...[
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'Book again',
                  icon: Icons.replay_rounded,
                  onPressed: () =>
                      context.push('/book/${b.serviceId}?car=${b.car.name}'),
                ),
              ),
            ],
          ]),
          if (upcoming) ...[
            const SizedBox(height: 16),
            Text(
              'Need to change or cancel? Message or call us before your slot.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.textSubtle),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove from this phone?'),
                    content: const Text(
                        'This only removes it from your list. It does not cancel the booking — '
                        'to cancel, message or call us.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Keep')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await ref.read(bookingsProvider.notifier).remove(b.ref);
                  if (context.mounted) {
                    context.pop();
                    showMessage(context, 'Booking removed from this phone.');
                  }
                }
              },
              child: const Text('Remove from list'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, int amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: AppText.small.copyWith(color: AppColors.text))),
          Text(rupees(amount), style: AppText.smallStrong),
        ]),
      );
}
