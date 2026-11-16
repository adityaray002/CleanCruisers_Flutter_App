import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offers.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../widgets/offer_card.dart';
import '../widgets/ui.dart';

/// CleanCredit tab: credit balance, the offers (coupons) running now, and
/// credit history. Offers come from lib/data/offers.dart; "Use" saves one so
/// the booking page applies it automatically when the booking qualifies.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final picked = ref.watch(pickedOfferProvider);
    final car = ref.watch(profileProvider).car;
    final first = ref.watch(myBookingsProvider).isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.section),
            children: [
              Semantics(header: true, child: Text('Offers', style: AppText.h1)),
              const SizedBox(height: AppSpace.lg),
              // ── CleanCredit ──
              Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('YOUR CLEANCREDIT',
                              style: AppText.overline
                                  .copyWith(color: AppColors.brand)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('Never expires',
                              style: AppText.caption
                                  .copyWith(color: AppColors.ink)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(rupees(wallet.balance),
                          style: AppText.display.copyWith(color: Colors.white)),
                      const SizedBox(height: AppSpace.md),
                      const Row(children: [
                        Expanded(
                          child: _CreditFact('Given by our team',
                              'When something goes wrong with a visit'),
                        ),
                        SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: _CreditFact('Used automatically',
                              'Taken off your next booking'),
                        ),
                      ]),
                    ]),
              ),

              // ── Offers ──
              if (kOffers.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xxl),
                Semantics(
                    header: true,
                    child: Text('Offers for you', style: AppText.h2)),
                const SizedBox(height: AppSpace.md),
                for (final o in kOffers) ...[
                  OfferCard(
                    offer: o,
                    // Bill size isn't known yet; car and first booking are.
                    blockedReason:
                        o.whyNot(total: 1 << 30, car: car, firstBooking: first),
                    applied: picked == o.code,
                    actionLabel: picked == o.code ? 'Saved' : 'Use',
                    onAction: () async {
                      await ref.read(pickedOfferProvider.notifier).pick(o.code);
                      if (context.mounted) {
                        showMessage(context,
                            '${o.code} saved. It\'s applied when you book.');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],

              // ── History ──
              if (wallet.transactions.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xxl),
                Text('Credit history', style: AppText.h3),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < wallet.transactions.length; i++) ...[
                        _TransactionTile(wallet.transactions[i]),
                        if (i < wallet.transactions.length - 1)
                          const Divider(height: 1, indent: 60),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditFact extends StatelessWidget {
  final String title, line;
  const _CreditFact(this.title, this.line);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: const Color(0xFF141B1D),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: const Color(0xFF2A3336)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.smallStrong.copyWith(color: Colors.white)),
          const SizedBox(height: 2),
          Text(line,
              style: AppText.caption.copyWith(color: const Color(0xFFB8C0C7))),
        ]),
      );
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionTile(this.tx);

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  isCredit ? const Color(0xFFE8F8EE) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isCredit ? AppColors.primary : AppColors.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  tx.description,
                  style: AppText.caption.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                  style: AppText.caption.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isCredit ? '+' : ''}${rupees(tx.amount)}',
            style: AppText.bodyStrong.copyWith(
              color: isCredit ? AppColors.primary : AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
