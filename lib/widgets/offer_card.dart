import '../data/api/models.dart' show PublicOffer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'ui.dart';

/// A coupon as a ticket: big "₹40 OFF" stub on the left, the rules and the
/// code (tap to copy) on the right, and one action (Use / Apply / Applied).
class OfferCard extends StatelessWidget {
  final String code, title, headline;
  final List<String> conditions;

  /// Why it can't be used now ('Add ₹50 more…'); shown instead of the action.
  final String? blockedReason;
  final bool applied;
  final String actionLabel;
  final VoidCallback? onAction;

  /// An offer from the server (contract `GET /offers`).
  OfferCard.public({
    super.key,
    required PublicOffer offer,
    this.blockedReason,
    this.applied = false,
    required this.actionLabel,
    this.onAction,
  })  : code = offer.code,
        title = offer.title,
        headline = offer.headline,
        conditions = offer.conditions;

  @override
  Widget build(BuildContext context) {
    final off = blockedReason != null;
    // An offer you can't use yet is faded as a whole (not greyed like an
    // expired ticket); the reason underneath stays fully readable.
    final fade = off ? 0.5 : 1.0;
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: applied ? AppColors.primary : AppColors.border,
              width: applied ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Ticket stub.
            Opacity(
              opacity: fade,
              child: Container(
                width: 76,
                color: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                alignment: Alignment.center,
                child: Text(
                  headline.replaceFirst(' ', '\n'),
                  textAlign: TextAlign.center,
                  style: AppText.h3.copyWith(color: Colors.white, height: 1.1),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                        opacity: fade,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppText.bodyStrong),
                              // When blocked, the reason below says it.
                              if (conditions.isNotEmpty && !off)
                                Text(conditions.join(' · '),
                                    style: AppText.caption),
                            ]),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Row(children: [
                        Opacity(opacity: fade, child: _CopyCode(code)),
                        const Spacer(),
                        if (!off) _action(),
                      ]),
                      if (off) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(blockedReason!,
                                style: AppText.caption
                                    .copyWith(color: AppColors.textMuted)),
                          ),
                        ]),
                      ],
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _action() {
    if (applied) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded,
            size: 18, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(actionLabel,
            style: AppText.smallStrong.copyWith(color: AppColors.primaryDk)),
      ]);
    }
    return InlineButton(label: actionLabel, onPressed: onAction);
  }
}

/// The code, tap to copy (for sharing or typing elsewhere).
class _CopyCode extends StatelessWidget {
  final String code;
  const _CopyCode(this.code);

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Copy code $code',
        child: ExcludeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm - 4),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) showMessage(context, '$code copied');
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.sm - 4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(code,
                    style: AppText.caption.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded,
                    size: 14, color: AppColors.textSubtle),
              ]),
            ),
          ),
        ),
      );
}
