import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'motion.dart';

// ── Buttons ───────────────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool dense;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: loading || onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      style: dense
          ? ElevatedButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18))
          : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: loading
            ? const SizedBox(
                key: ValueKey('l'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Row(
                key: const ValueKey('c'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8)
                  ],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool dense;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: onPressed,
      style: dense
          ? OutlinedButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16))
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.selected = false,
    this.color,
    this.radius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return PressScale(
      enabled: onTap != null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              color ?? (selected ? AppColors.primarySoft : AppColors.surface),
          borderRadius: r,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected ? null : AppShadow.card,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title,
      {super.key, this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: AppText.h2)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppText.small),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

// ── Pills / badges ────────────────────────────────────────────────────────────
enum PillTone { neutral, brand, dark, warning }

class Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final PillTone tone;

  const Pill(this.label, {super.key, this.icon, this.tone = PillTone.neutral});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (AppColors.surfaceAlt, AppColors.textMuted),
      PillTone.brand => (AppColors.primarySoft, AppColors.primaryDk),
      PillTone.dark => (const Color(0xCC0B0F10), Colors.white),
      PillTone.warning => (AppColors.warningSoft, AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5)
        ],
        Text(label,
            style: AppText.caption
                .copyWith(color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Checklist item ────────────────────────────────────────────────────────────
class CheckItem extends StatelessWidget {
  final String text;
  final bool included;
  const CheckItem(this.text, {super.key, this.included = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: included ? AppColors.primarySoft : AppColors.surfaceAlt,
            shape: BoxShape.circle,
          ),
          child: Icon(included ? Icons.check_rounded : Icons.close_rounded,
              size: 14,
              color: included ? AppColors.primary : AppColors.textSubtle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: AppText.body.copyWith(
                  color: included ? AppColors.text : AppColors.textMuted,
                  fontSize: 14.5)),
        ),
      ]),
    );
  }
}

// ── Info row (icon + label + value) ───────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            Text(value, style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
    if (onTap == null) return content;
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: content);
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool dark;
  const IconBadge(this.icon, {super.key, this.size = 40, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? const Color(0x1FFFFFFF) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon,
          size: size * 0.5, color: dark ? AppColors.brand : AppColors.primary),
    );
  }
}

// ── Price ─────────────────────────────────────────────────────────────────────
class PriceText extends StatelessWidget {
  final int amount;
  final bool from;
  final String suffix;
  final double size;

  const PriceText(this.amount,
      {super.key, this.from = false, this.suffix = '', this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        if (from) TextSpan(text: 'Starts at ', style: AppText.caption),
        TextSpan(
            text: rupees(amount),
            style: AppText.price.copyWith(fontSize: size)),
        if (suffix.isNotEmpty)
          TextSpan(text: ' $suffix', style: AppText.caption),
      ]),
    );
  }
}

// ── Sticky bottom action bar ──────────────────────────────────────────────────
class BottomActionBar extends StatelessWidget {
  final Widget child;
  final Widget? top;
  const BottomActionBar({super.key, required this.child, this.top});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadow.raised,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (top != null) ...[top!, const SizedBox(height: 10)],
            child,
          ]),
        ),
      ),
    );
  }
}

// ── Empty / error state ───────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
              color: AppColors.primarySoft, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        Text(title, style: AppText.h2, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, style: AppText.body, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ]),
    );
  }
}

// ── Notice box ────────────────────────────────────────────────────────────────
class NoticeBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;
  const NoticeBox(
      {super.key,
      required this.icon,
      required this.text,
      this.warning = false});

  @override
  Widget build(BuildContext context) {
    final fg = warning ? AppColors.warning : AppColors.primaryDk;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? AppColors.warningSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.small.copyWith(color: fg))),
      ]),
    );
  }
}

void showMessage(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}
