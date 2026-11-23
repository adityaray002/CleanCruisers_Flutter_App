import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/pricing.dart';
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

/// "🚗 Hatchback ⌄": the car whose prices the app shows. Opens the car
/// sheet. Shows the saved model ("Swift") when there is one.
class CarPill extends ConsumerWidget {
  const CarPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final model = p.carModel.trim();
    final label = model.isNotEmpty
        ? model.split(' ').last
        : (p.car == null ? 'Your car' : carTypeNames[p.car]!);
    // On narrow phones with no car picked, drop "Your car" so the location
    // CTA beside it fits. Home also has a "Choose car" link under the
    // section heading, so nothing is lost.
    final roomy = MediaQuery.sizeOf(context).width /
        MediaQuery.textScalerOf(context).scale(1);
    final iconOnly = p.car == null && roomy < 380;
    return Semantics(
      button: true,
      label: p.car == null
          ? 'Choose your car to see exact prices'
          : 'Prices for ${carTypeNames[p.car]}. Change car',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130, minHeight: 44),
          child: RoundSurface(
            onTap: () => showCarSheet(context, ref),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.directions_car_outlined,
                  size: 18, color: AppColors.primary),
              if (!iconOnly) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.smallStrong.copyWith(color: AppColors.text)),
                ),
              ],
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),
        ),
      ),
    );
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
  /// Home header style: a small "Car parked at" line above, and the place
  /// in bold ("Home, Janakpuri").
  final bool withOverline;

  /// White text for the Home green band (only with [withOverline]).
  final bool onDark;
  const ParkedAtLine(
      {super.key, this.withOverline = false, this.onDark = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(addressBookProvider).selected;
    final place = sel == null ? null : addressLabelNames[sel.label]!;
    final color = sel == null ? AppColors.primary : AppColors.textMuted;
    if (withOverline) {
      final short = sel == null ? 'Set location' : '$place · ${sel.address}';
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
              constraints: const BoxConstraints(minHeight: 44),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Car parked at',
                        style: onDark
                            ? AppText.caption
                                .copyWith(color: const Color(0xCCFFFFFF))
                            : AppText.caption),
                    Row(children: [
                      Flexible(
                        child: Text(short,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong.copyWith(
                                color: onDark
                                    ? Colors.white
                                    : sel == null
                                        ? AppColors.primary
                                        : AppColors.text,
                                fontWeight: FontWeight.w800)),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: onDark ? AppColors.brand : AppColors.primary),
                    ]),
                  ]),
            ),
          ),
        ),
      );
    }
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
