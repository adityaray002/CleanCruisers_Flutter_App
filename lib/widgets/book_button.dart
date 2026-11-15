import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/service.dart';

/// "Book now" on a service card: opens the booking page for this service.
/// Outlined by default; [primary] fills it green for the featured package.
class BookButton extends StatelessWidget {
  final CarService service;
  final bool primary;
  const BookButton(this.service, {super.key, this.primary = false});

  @override
  Widget build(BuildContext context) {
    void book() {
      HapticFeedback.selectionClick();
      context.push('/book/${service.id}');
    }

    const label = Text('Book now');
    const size = Size(0, 36);
    const padding = EdgeInsets.symmetric(horizontal: AppSpace.lg);
    final button = primary
        ? ElevatedButton(
            onPressed: book,
            style: ElevatedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: AppText.smallStrong,
            ),
            child: label,
          )
        : OutlinedButton(
            onPressed: book,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              textStyle: AppText.smallStrong,
            ),
            child: label,
          );
    return Semantics(
      button: true,
      label: 'Book ${service.name}',
      child: ExcludeSemantics(child: button),
    );
  }
}
