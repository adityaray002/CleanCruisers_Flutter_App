import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/scheduling.dart' show Coverage;
import '../core/theme.dart';
import '../models/address.dart';
import '../models/booking.dart';
import '../providers/app_providers.dart';
import '../widgets/customer_sheets.dart';
import '../widgets/ui.dart';

/// My addresses (v3 design): every saved address with its parking note and
/// coverage, Edit and Delete. An address that an upcoming booking uses
/// can't be deleted; the dialog says which booking and opens it. Changes
/// apply to new bookings only.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  /// The upcoming booking that uses [a], if any.
  static BookingRecord? bookingUsing(SavedAddress a, List<BookingRecord> all) {
    final line = a.address.trim();
    if (line.isEmpty) return null;
    return all
        .where((b) => !b.status.isFinal && b.address.contains(line))
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressBookProvider);
    final areas = ref.watch(serviceAreasProvider).valueOrNull ?? const [];
    final bookings = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
            children: [
              Row(children: [
                Semantics(
                  button: true,
                  label: 'Back',
                  child: ExcludeSemantics(
                    child: Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(
                          side: BorderSide(color: AppColors.border)),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/profile'),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.arrow_back_rounded,
                              size: 20, color: AppColors.text),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Semantics(
                    header: true,
                    child: Text('My addresses', style: AppText.h2)),
              ]),
              const SizedBox(height: AppSpace.md),
              Text(
                  'Changes apply to new bookings. To move a booked wash, '
                  'change it from that booking.',
                  style: AppText.small),
              const SizedBox(height: AppSpace.lg),
              if (book.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xxl),
                  child: EmptyState(
                    icon: Icons.location_on_outlined,
                    title: 'No saved addresses',
                    message: 'Add where your car is parked, and our expert '
                        'comes there.',
                    action: PrimaryButton(
                      label: 'Add address',
                      expand: false,
                      onPressed: () => showAddressForm(context, ref),
                    ),
                  ),
                ),
              for (final a in book.items) ...[
                _AddressCard(
                  address: a,
                  inUse: a.id == book.selected?.id,
                  coverage: addressCoverage(a, areas),
                  booking: bookingUsing(a, bookings),
                  onEdit: () => showAddressForm(context, ref, existing: a),
                  onDelete: () => _delete(context, ref, a, bookings),
                ),
                const SizedBox(height: AppSpace.md),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: book.items.isEmpty
          ? null
          : BottomActionBar(
              child: PrimaryButton(
                label: 'Add a new address',
                icon: Icons.add_rounded,
                onPressed: () => showAddressForm(context, ref),
              ),
            ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedAddress a,
      List<BookingRecord> bookings) async {
    final name = addressLabelNames[a.label]!;
    final using = bookingUsing(a, bookings);
    if (using != null) {
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('You can\'t delete this yet'),
          content: Text('Your booking on ${friendlyDate(using.date)} uses this '
              'address. Change or cancel that booking first.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('OK')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open that booking')),
          ],
        ),
      );
      if (open == true && context.mounted) {
        context.push('/bookings/${using.ref}');
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content:
            Text('${withParking(a.address, null)} will be removed from your '
                'saved addresses.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final wasSelected = ref.read(addressBookProvider).selected?.id == a.id;
    await ref.read(addressBookProvider.notifier).remove(a.id);
    if (!context.mounted) return;
    showMessage(context, '$name deleted',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref
              .read(addressBookProvider.notifier)
              .save(a, select: wasSelected),
        ));
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final bool inUse;
  final Coverage coverage;
  final BookingRecord? booking;
  final VoidCallback onEdit, onDelete;
  const _AddressCard({
    required this.address,
    required this.inUse,
    required this.coverage,
    required this.booking,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final a = address;
    final name = addressLabelNames[a.label]!;
    final parking = parkingOf(a.address);
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: AppSpace.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(name, style: AppText.h3),
              if (inUse)
                const Pill('For new bookings',
                    icon: Icons.check_rounded, tone: PillTone.solid),
              CoverageChip(coverage),
            ]),
        const SizedBox(height: 4),
        Text(withParking(a.address, null), style: AppText.small),
        if (parking != null && parking.isNotEmpty)
          Text(parking, style: AppText.caption),
        if (booking != null) ...[
          const SizedBox(height: AppSpace.sm),
          Pill('Booking on ${friendlyDate(booking!.date)} uses this address',
              tone: PillTone.brand),
        ],
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                textStyle: AppText.smallStrong,
              ),
              child: const Text('Edit'),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                textStyle: AppText.smallStrong,
              ),
              child: const Text('Delete'),
            ),
          ),
        ]),
      ]),
    );
  }
}
