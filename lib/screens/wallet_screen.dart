import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/api/models.dart';
import '../providers/api_providers.dart';
import '../providers/app_providers.dart';
import '../widgets/offer_card.dart';
import '../widgets/ui.dart';

/// The CleanCredit wallet, from the server (contract §7).
final walletApiProvider =
    FutureProvider.autoDispose<Wallet>((ref) => ref.watch(apiProvider).wallet());

/// Offers tab (CleanCredit + coupons), all from the server: the credit
/// balance and when the next credit expires, how to earn more (5% back,
/// referral), the coupons running now, and the credit history. "Use" saves a
/// coupon so the booking page tries it; the server says if it applies.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final wallet = ref.watch(walletApiProvider).valueOrNull;
    final offers = ref.watch(publicOffersProvider).valueOrNull ?? const [];
    final picked = ref.watch(pickedOfferProvider);
    final balance = wallet?.balance ?? me?.walletBalance ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(meProvider);
              ref.invalidate(publicOffersProvider);
              ref.invalidate(walletApiProvider);
              await ref.read(walletApiProvider.future);
            },
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
                        Text('YOUR CLEANCREDIT',
                            style: AppText.overline
                                .copyWith(color: AppColors.brand)),
                        const SizedBox(height: 4),
                        Text(rupees(balance),
                            style:
                                AppText.display.copyWith(color: Colors.white)),
                        if (me?.nextExpiryOn != null)
                          Text(
                              '${rupees(me!.nextExpiryAmount ?? 0)} expires on '
                              '${shortDate(me.nextExpiryOn!)}',
                              style: AppText.small
                                  .copyWith(color: const Color(0xFFB8C0C7))),
                        const SizedBox(height: AppSpace.md),
                        const Row(children: [
                          Expanded(
                            child: _CreditFact('5% back on every wash',
                                'Added when the wash is done'),
                          ),
                          SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: _CreditFact('Used on your next booking',
                                'Lasts 60 days'),
                          ),
                        ]),
                      ]),
                ),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  onTap: () => context.push('/referral'),
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(children: [
                    const IconBadge(Icons.card_giftcard_rounded, size: 40),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Invite a friend, both get ₹100',
                                style: AppText.title),
                            Text('After their first wash',
                                style: AppText.small),
                          ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSubtle),
                  ]),
                ),

                // ── Offers ──
                if (offers.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xxl),
                  Semantics(
                      header: true,
                      child: Text('Offers for you', style: AppText.h2)),
                  const SizedBox(height: AppSpace.md),
                  for (final o in offers) ...[
                    OfferCard.public(
                      offer: o,
                      applied: picked == o.code,
                      actionLabel: picked == o.code ? 'Saved' : 'Use',
                      onAction: () async {
                        await ref.read(pickedOfferProvider.notifier).pick(o.code);
                        if (context.mounted) {
                          showMessage(context,
                              '${o.code} saved. It\'s applied when you book, if the booking qualifies.');
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                // ── History ──
                if (wallet != null && wallet.entries.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xxl),
                  Text('Credit history', style: AppText.h3),
                  const SizedBox(height: AppSpace.md),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < wallet.entries.length; i++) ...[
                          _EntryTile(wallet.entries[i]),
                          if (i < wallet.entries.length - 1)
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

class _EntryTile extends StatelessWidget {
  final WalletEntry e;
  const _EntryTile(this.e);

  static String _title(WalletEntry e) => switch (e.kind) {
        'cashback' => 'Cashback',
        'referral' => 'Referral reward',
        'rain' => 'Rain: wash moved',
        'goodwill' => 'From the team',
        'used' => 'Used on a booking',
        'returned' => 'Returned',
        'expired' => 'Expired',
        _ => 'CleanCredit',
      };

  @override
  Widget build(BuildContext context) {
    final isCredit = e.amount > 0;
    final details = [
      if (e.note.isNotEmpty) e.note,
      if (isCredit && e.expiresOn != null) 'lasts till ${shortDate(e.expiresOn!)}',
    ].join(' · ');
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
                Text(_title(e), style: AppText.bodyStrong),
                if (details.isNotEmpty)
                  Text(details,
                      style: AppText.caption.copyWith(color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                Text(shortDate(e.at),
                    style: AppText.caption.copyWith(color: AppColors.textSubtle)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isCredit ? '+' : '-'}${rupees(e.amount.abs())}',
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
