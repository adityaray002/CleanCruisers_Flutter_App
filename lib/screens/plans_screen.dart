import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/api/models.dart';
import '../providers/api_providers.dart';
import '../providers/booking_providers.dart';
import '../widgets/ui.dart';

/// My monthly plans (contract §8, owner rules J5): visits used and left,
/// when the plan ends, and "Book next visit" (the wash is already paid).
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPlansProvider);
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final plans = async.valueOrNull ?? const <Plan>[];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('My plans')),
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myPlansProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.section),
            children: [
              if (async.isLoading && !async.hasValue)
                const Center(child: CircularProgressIndicator())
              else if (plans.isEmpty)
                EmptyState(
                  icon: Icons.event_repeat_rounded,
                  title: 'No plan yet',
                  message: 'A monthly plan books your washes for the month at '
                      'one price.',
                  action: PrimaryButton(
                    label: 'See monthly plans',
                    expand: false,
                    onPressed: () => context.go('/services?cat=monthly'),
                  ),
                )
              else
                for (final p in plans) ...[
                  _PlanCard(
                      plan: p,
                      serviceId: catalog?.plan(p.planId)?.serviceId),
                  const SizedBox(height: AppSpace.md),
                ],
              const SizedBox(height: AppSpace.lg),
              const NoticeBox(
                icon: Icons.info_outline_rounded,
                text: 'A plan lasts 30 days from the first visit. If we move a '
                    'visit for rain or on our side, the plan gets 7 more days. '
                    'A missed visit or a late cancel counts as used.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final String? serviceId;
  const _PlanCard({required this.plan, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final (status, tone) = switch (p.status) {
      PlanState.pendingFirstVisit => ('Starts at the first visit', PillTone.warning),
      PlanState.active => ('Active', PillTone.brand),
      PlanState.expired => ('Ended', PillTone.neutral),
      PlanState.cancelled => ('Cancelled', PillTone.neutral),
    };
    final canBook = p.status == PlanState.active &&
        p.visitsUsed + p.visitsBooked < p.visitsTotal &&
        serviceId != null;
    final car = p.car.model.trim().isEmpty
        ? carTypeNames[p.car.type]!
        : '${p.car.model} · ${carTypeNames[p.car.type]}';
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(p.name, style: AppText.h3)),
          Pill(status, tone: tone),
        ]),
        const SizedBox(height: 2),
        Text(car, style: AppText.small),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          for (var i = 0; i < p.visitsTotal; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: i < p.visitsUsed
                      ? AppColors.primary
                      : i < p.visitsUsed + p.visitsBooked
                          ? AppColors.brand
                          : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text(
            '${p.visitsUsed} done · ${p.visitsBooked} booked · '
            '${p.visitsTotal - p.visitsUsed - p.visitsBooked} left',
            style: AppText.caption),
        if (p.endsOn != null)
          Text('Ends on ${shortDate(p.endsOn!)}', style: AppText.caption),
        Text(
            p.paid
                ? '${rupees(p.price)} paid'
                : '${rupees(p.price)} to pay at the first visit',
            style: AppText.caption),
        if (canBook) ...[
          const SizedBox(height: AppSpace.md),
          PrimaryButton(
            label: 'Book next visit',
            icon: Icons.add_rounded,
            onPressed: () => context.push(
                '/book/$serviceId?car=${p.car.type.name}&plan=${p.id}'),
          ),
        ] else if (p.status == PlanState.pendingFirstVisit) ...[
          const SizedBox(height: AppSpace.sm),
          Text('You can book the other visits once the first one is done.',
              style: AppText.small),
        ],
      ]),
    );
  }
}
