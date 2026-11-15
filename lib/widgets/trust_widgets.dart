import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import 'contact_actions.dart';
import 'ui.dart';

/// "Why choose us" strip. Shows only facts set in business_info.dart.
/// "Pay after the service" isn't here: Home already says it in the hero and
/// in "How it works", so a third mention would only repeat it.
class WhyUsStrip extends StatelessWidget {
  /// Mint background instead of white (under a list of white cards).
  final bool tinted;
  const WhyUsStrip({super.key, this.tinted = false});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'Doorstep\nservice'),
      if (kEcoFriendly) (Icons.eco_outlined, 'Eco-friendly\nproducts'),
      kCustomersServed != null
          ? (Icons.people_outline_rounded, '$kCustomersServed happy\ncustomers')
          // Non-breaking spaces keep "8 AM – 6 PM" on one line.
          : (
              Icons.schedule_outlined,
              '$kDaysLabel\n${kHoursLabel.replaceAll(' ', ' ')}'
            ),
      if (kEstablished != null)
        (Icons.favorite_border_rounded, 'Serving\nsince $kEstablished'),
    ];
    return AppCard(
      color: tinted ? AppColors.primarySoft : null,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs, vertical: AppSpace.lg),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1),
            Expanded(
              child: Column(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(items[i].$1, size: 20, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpace.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(items[i].$2,
                      textAlign: TextAlign.center,
                      style:
                          AppText.caption.copyWith(color: AppColors.textMuted)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// "Need help? Chat with our team" card. Opens WhatsApp support.
class HelpCard extends StatelessWidget {
  final String title, line;
  final String? message;
  const HelpCard(
      {super.key,
      this.title = 'Need help?',
      this.line = 'Chat with our team',
      this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title $line',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: () => openWhatsApp(context, message: message),
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(children: [
            const IconBadge(Icons.chat_outlined, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    const SizedBox(height: 2),
                    Text(line, style: AppText.small),
                  ]),
            ),
            const SizedBox(width: AppSpace.sm),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.textSubtle),
          ]),
        ),
      ),
    );
  }
}
