import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/booking.dart';
import '../providers/app_providers.dart';
import '../widgets/ui.dart';

/// Screen 09: Customer Portal · My Bookings Dashboard
/// Matching exact mockup with Segmented Tabs: [Upcoming (2)] [Past Bookings (1)],
/// Amber "REQUESTED" card, Green "CONFIRMED" card, and Past completed invoice cards.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int _selectedTab = 0; // 0 = Upcoming, 1 = Past Bookings

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(myBookingsProvider);
    final upcoming = all
        .where((b) => b.isUpcoming() && !b.status.isFinal)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = all.where((b) => !b.isUpcoming() || b.status.isFinal).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'CUSTOMER PORTAL',
                  style: AppText.overline.copyWith(
                    color: AppColors.primaryDk,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${upcoming.length} Active',
                    style: AppText.caption.copyWith(
                      color: AppColors.primaryDk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'My Bookings',
              style: AppText.h1,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Segmented Tabs
          Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpace.page, 10, AppSpace.page, 14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          boxShadow: _selectedTab == 0 ? AppShadow.card : null,
                        ),
                        child: Text(
                          'Upcoming (${upcoming.length})',
                          textAlign: TextAlign.center,
                          style: AppText.smallStrong.copyWith(
                            color: _selectedTab == 0
                                ? AppColors.text
                                : AppColors.textSubtle,
                            fontWeight: _selectedTab == 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          boxShadow: _selectedTab == 1 ? AppShadow.card : null,
                        ),
                        child: Text(
                          'Past Bookings (${past.length})',
                          textAlign: TextAlign.center,
                          style: AppText.smallStrong.copyWith(
                            color: _selectedTab == 1
                                ? AppColors.text
                                : AppColors.textSubtle,
                            fontWeight: _selectedTab == 1
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List content
          Expanded(
            child: _selectedTab == 0
                ? (upcoming.isEmpty
                    ? Center(
                        child: EmptyState(
                          icon: Icons.event_note_rounded,
                          title: 'No active bookings',
                          message:
                              'Your scheduled doorstep appointments will show up here.',
                          action: PrimaryButton(
                            label: 'Book a service',
                            expand: false,
                            onPressed: () => context.go('/services'),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.page, 4, AppSpace.page, 24),
                        children: [
                          for (final b in upcoming)
                            _MockupBookingCard(b: b, isPast: false),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_outlined,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'CleanCruisers verifies worker routes and capacity before marking any appointment as Confirmed.',
                                    style: AppText.caption
                                        .copyWith(color: AppColors.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ))
                : (past.isEmpty
                    ? Center(
                        child: EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No past bookings',
                          message:
                              'Completed services and tax invoices will be archived here.',
                          action: PrimaryButton(
                            label: 'Book a service',
                            expand: false,
                            onPressed: () => context.go('/services'),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.page, 4, AppSpace.page, 24),
                        children: [
                          for (final b in past)
                            _MockupBookingCard(b: b, isPast: true),
                        ],
                      )),
          ),
        ],
      ),
    );
  }
}

class _MockupBookingCard extends StatelessWidget {
  final BookingRecord b;
  final bool isPast;
  const _MockupBookingCard({required this.b, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final isRequested = b.status == BookingStatus.requested;
    final isConfirmed = b.status == BookingStatus.confirmed ||
        b.status == BookingStatus.onTheWay ||
        b.status == BookingStatus.inService;

    final borderColor = isRequested
        ? const Color(0xFFF59E0B)
        : (isConfirmed ? AppColors.primary : AppColors.border);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
            Border.all(color: borderColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isRequested
                  ? const Color(0xFFFFFBEB)
                  : (isConfirmed
                      ? const Color(0xFFF0FDF4)
                      : AppColors.surfaceAlt),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md - 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      isPast
                          ? 'COMPLETED · ${monthShort(b.date).toUpperCase()} ${b.date.day}'
                          : (isRequested
                              ? 'PREFERRED · ${monthShort(b.date).toUpperCase()} ${b.date.day}'
                              : 'CONFIRMED · ${monthShort(b.date).toUpperCase()} ${b.date.day}'),
                      style: AppText.overline.copyWith(
                        color: isRequested
                            ? const Color(0xFFB45309)
                            : (isConfirmed
                                ? AppColors.primaryDk
                                : AppColors.textSubtle),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRequested
                        ? const Color(0xFFFEF3C7)
                        : (isConfirmed
                            ? AppColors.primarySoft
                            : const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isRequested
                          ? const Color(0xFFF59E0B)
                          : (isConfirmed
                              ? AppColors.primary
                              : const Color(0xFF9CA3AF)),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isPast
                        ? 'COMPLETED'
                        : (isRequested ? 'REQUESTED' : '✓ CONFIRMED'),
                    style: AppText.caption.copyWith(
                      color: isRequested
                          ? const Color(0xFF92400E)
                          : (isConfirmed
                              ? AppColors.primaryDk
                              : AppColors.text),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.serviceName, style: AppText.h3),
                const SizedBox(height: 2),
                Text(
                  '${b.ref} · ${b.carLabel}',
                  style: AppText.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      isRequested
                          ? Icons.schedule_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isRequested
                          ? const Color(0xFFD97706)
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isPast
                            ? 'Completed at 11:45 AM · Rahul Sharma'
                            : (isRequested
                                ? 'Preferred Window: ${b.slotLabel} · Awaiting Team Confirmation'
                                : 'Arrival: ${b.slotLabel} · Rahul Assigned (Van HR 26)'),
                        style: AppText.small.copyWith(
                          color: isRequested
                              ? const Color(0xFF92400E)
                              : AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPast ? 'Total Paid' : 'Pay after service',
                          style: AppText.caption
                              .copyWith(color: AppColors.textSubtle),
                        ),
                        Text(
                          rupees(b.payable),
                          style: AppText.priceSm.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/bookings/${b.ref}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRequested
                            ? const Color(0xFFD97706)
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isPast
                                ? 'View Invoice →'
                                : (isRequested
                                    ? 'Track Request →'
                                    : 'View Details →'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
