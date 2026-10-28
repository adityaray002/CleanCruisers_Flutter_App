import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/service.dart';
import 'motion.dart';
import 'ui.dart';

/// Real job photo for the service, or a branded illustration tile when we don't
/// have a photo that honestly represents it (e.g. interior services).
class ServiceImage extends StatelessWidget {
  final CarService service;
  final double? height;
  final double radius;
  final BorderRadius? borderRadius;

  /// When true, the photo flies smoothly into the service detail page.
  final bool hero;

  const ServiceImage(this.service,
      {super.key,
      this.height,
      this.radius = AppRadius.md,
      this.borderRadius,
      this.hero = true});

  static String heroTag(CarService s) => 'service-image-${s.id}';

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    final img = ClipRRect(
      borderRadius: br,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: service.image != null
            ? Stack(fit: StackFit.expand, children: [
                Image.asset(service.image!,
                    fit: BoxFit.cover,
                    semanticLabel: service.name,
                    errorBuilder: (_, __, ___) => _Illustration(service)),
                if (!service.photoHasLogo) const CornerBrandMark(),
              ])
            : _Illustration(service),
      ),
    );
    return hero ? Hero(tag: heroTag(service), child: img) : img;
  }
}

/// Small round CleanCruisers logo, so photos without our uniform or kit in
/// them still carry the brand.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 6)],
      ),
      child: ClipOval(
        child: Image.asset('assets/images/logo.png',
            fit: BoxFit.cover,
            // The source is 3500px; decode it small.
            cacheWidth: 160,
            excludeFromSemantics: true),
      ),
    );
  }
}

/// [BrandMark] pinned to the bottom-right corner, scaled to the photo it
/// sits on.
class CornerBrandMark extends StatelessWidget {
  const CornerBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final size = (c.maxWidth * 0.12).clamp(22.0, 44.0);
      final gap = size * 0.3;
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: BrandMark(size: size),
        ),
      );
    });
  }
}

class _Illustration extends StatelessWidget {
  final CarService service;
  const _Illustration(this.service);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12301F), AppColors.ink],
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -24,
          bottom: -24,
          child: Icon(service.icon, size: 150, color: const Color(0x14FFFFFF)),
        ),
        Center(child: Icon(service.icon, size: 44, color: AppColors.brand)),
      ]),
    );
  }
}

/// Immersive photo card used in the home carousel: text sits on the photo.
/// Height comes from the content, so it never overflows at large font sizes.
class ServiceCard extends StatelessWidget {
  final CarService service;
  final double width;
  const ServiceCard(this.service, {super.key, this.width = 270});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.lg);
    return SizedBox(
      width: width,
      child: PressScale(
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: r, boxShadow: AppShadow.card),
          child: ClipRRect(
            borderRadius: r,
            child: Material(
              color: AppColors.ink,
              child: InkWell(
                onTap: () => context.push('/service/${service.id}'),
                child: Stack(children: [
                  Positioned.fill(child: ServiceImage(service, radius: 0)),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x000B0F10),
                            Color(0x330B0F10),
                            Color(0xF20B0F10)
                          ],
                          stops: [0.25, 0.45, 0.85],
                        ),
                      ),
                    ),
                  ),
                  if (service.badge != null)
                    Positioned(
                        top: 12,
                        left: 12,
                        child: Pill(service.badge!, tone: PillTone.dark)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 170),
                          const Spacer(),
                          Text(service.name,
                              style: AppText.h3
                                  .copyWith(color: Colors.white, fontSize: 17),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(service.tagline,
                              style: AppText.small
                                  .copyWith(color: const Color(0xFFD1D5DB)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.pill),
                                    ),
                                    child: Text(
                                      '${service.samePriceForAll ? '' : 'Starts at '}${rupees(service.fromPrice)}${service.priceSuffix}',
                                      style: AppText.smallStrong,
                                    ),
                                  ),
                                  Text(service.duration,
                                      style: AppText.caption
                                          .copyWith(color: Colors.white70)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  size: 20, color: AppColors.ink),
                            ),
                          ]),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row used in the Services list.
class ServiceRow extends StatelessWidget {
  final CarService service;
  const ServiceRow(this.service, {super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/service/${service.id}'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 96,
            height: 96,
            child: ServiceImage(service, radius: AppRadius.sm)),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (service.badge != null) ...[
              Pill(service.badge!, tone: PillTone.brand),
              const SizedBox(height: 6),
            ],
            Text(service.name, style: AppText.h3),
            const SizedBox(height: 3),
            Text(service.tagline,
                style: AppText.small,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _PriceAndDuration(service, priceSize: 17)),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSubtle),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Price and duration side by side; the duration moves to the next line when
/// there isn't room (narrow phones, long prices like "Starts at ₹1,399 /month").
class _PriceAndDuration extends StatelessWidget {
  final CarService service;
  final double priceSize;
  const _PriceAndDuration(this.service, {required this.priceSize});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PriceText(service.fromPrice,
            from: !service.samePriceForAll,
            suffix: service.priceSuffix,
            size: priceSize),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.schedule_rounded,
              size: 14, color: AppColors.textSubtle),
          const SizedBox(width: 4),
          Text(service.duration, style: AppText.caption),
        ]),
      ],
    );
  }
}
