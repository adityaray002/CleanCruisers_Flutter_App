import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/address.dart';
import '../providers/app_providers.dart';
import 'customer_sheets.dart';

/// Logo + "CleanCruisers" wordmark, with where the car is parked underneath
/// ([ParkedAtLine]). Shrinks to fit narrow rows.
class BrandWithAddress extends StatelessWidget {
  const BrandWithAddress({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ClipOval(
        child: Image.asset('assets/images/logo.png',
            width: 40, height: 40, cacheWidth: 160, excludeFromSemantics: true),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            label: 'CleanCruisers, doorstep car care',
            child: ExcludeSemantics(
              child: Text.rich(
                const TextSpan(children: [
                  TextSpan(text: 'Clean'),
                  TextSpan(
                      text: 'Cruisers',
                      style: TextStyle(color: AppColors.primary)),
                ]),
                maxLines: 1,
                style: AppText.h3.copyWith(height: 1.2),
              ),
            ),
          ),
          const ParkedAtLine(),
        ]),
      ),
    ]);
  }
}

/// White pill or circle with a hairline border (header chips).
class RoundSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback onTap;
  const RoundSurface(
      {super.key,
      required this.child,
      required this.padding,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// "📍 Home · <address> ⌄": where the car is parked, as one line under a
/// heading. Tap to pick another address. With no address yet it reads
/// "Set your car's location" in green, as a call to action.
class ParkedAtLine extends ConsumerWidget {
  const ParkedAtLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(addressBookProvider).selected;
    final place = sel == null ? null : addressLabelNames[sel.label]!;
    final color = sel == null ? AppColors.primary : AppColors.textMuted;
    return Semantics(
      button: true,
      label: sel == null
          ? 'Set where your car is parked'
          : 'Car parked at $place, ${sel.address}. Change',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => showAddressSheet(context, ref),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpace.xs),
              Flexible(
                child: Text(
                    sel == null
                        ? 'Set your car\'s location'
                        : '$place · ${sel.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (sel == null ? AppText.smallStrong : AppText.small)
                        .copyWith(color: color)),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
            ]),
          ),
        ),
      ),
    );
  }
}
