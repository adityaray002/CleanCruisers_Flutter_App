import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/format.dart';
import '../core/scheduling.dart' show clockLabel;
import '../data/api/models.dart' show Booking, BookingState;
import 'ui.dart' show PillTone;

const _steps = ['Requested', 'Confirmed', 'On the way', 'Cleaning', 'Done'];

/// Status chip words and colour for a server booking (list, detail, Home).
(String, PillTone) chipOf(BookingState s) => switch (s) {
      BookingState.requested => ('Waiting for confirmation', PillTone.warning),
      BookingState.confirmed => ('Confirmed', PillTone.brand),
      BookingState.onTheWay => ('On the way', PillTone.brand),
      BookingState.inService => ('Cleaning now', PillTone.brand),
      BookingState.rescheduleNeeded => ('Pick a new time', PillTone.warning),
      BookingState.completed => ('Done', PillTone.brand),
      BookingState.missed => ('Missed', PillTone.neutral),
      BookingState.cancelled => ('Cancelled', PillTone.neutral),
      BookingState.unableToServe => ("Couldn't take it", PillTone.neutral),
    };

/// One line for where a server booking stands.
String headlineOf(Booking b) => switch (b.status) {
      BookingState.requested =>
        'Requested for ${friendlyDate(b.slot.date)}, ${clockLabel(b.slot.start)}',
      BookingState.confirmed => 'Expert arrives ${clockLabel(b.slot.start)}',
      BookingState.onTheWay => 'Your expert is on the way',
      BookingState.inService => 'Your car is being cleaned',
      BookingState.rescheduleNeeded => b.offer != null
          ? 'The team offered another time'
          : 'Please pick a new time',
      BookingState.completed => 'All done. Hope you love it!',
      BookingState.missed => "Our expert couldn't reach you",
      BookingState.cancelled => 'Booking cancelled',
      BookingState.unableToServe => "We couldn't take this booking",
    };

/// Position of a booking on the happy path, or null when it has left it
/// (new time needed, missed, cancelled, couldn't take it).
int? progressIndex(BookingState s) => switch (s) {
      BookingState.requested => 0,
      BookingState.confirmed => 1,
      BookingState.onTheWay => 2,
      BookingState.inService => 3,
      BookingState.completed => 4,
      _ => null,
    };

/// Horizontal stepper: dots joined by a line, labels underneath.
class BookingProgress extends StatelessWidget {
  final BookingState status;
  final bool showLabels;
  const BookingProgress(
      {super.key, required this.status, this.showLabels = true});

  @override
  Widget build(BuildContext context) {
    final current = progressIndex(status);
    if (current == null) return const SizedBox.shrink();
    return Semantics(
      label:
          'Progress: ${_steps[current]}, step ${current + 1} of ${_steps.length}',
      child: ExcludeSemantics(
        child: Column(children: [
          Row(children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    color: i <= current ? AppColors.primary : AppColors.border,
                  ),
                ),
              _Dot(done: i < current, active: i == current),
            ],
          ]),
          if (showLabels) ...[
            const SizedBox(height: 6),
            Row(children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  // One line per step; shrinks a little rather than
                  // breaking a word ("Requeste / d") on narrow phones.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: i == 0
                          ? Alignment.centerLeft
                          : i == _steps.length - 1
                              ? Alignment.centerRight
                              : Alignment.center,
                      child: Text(
                        _steps[i],
                        maxLines: 1,
                        style: AppText.caption.copyWith(
                          color: i == current
                              ? AppColors.text
                              : AppColors.textSubtle,
                          fontWeight:
                              i == current ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool done, active;
  const _Dot({required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final size = active ? 18.0 : 14.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? AppColors.primary : AppColors.surface,
        border: Border.all(
            color: done || active ? AppColors.primary : AppColors.border,
            width: 2),
        boxShadow: active
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 0,
                    spreadRadius: 4)
              ]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
          : null,
    );
  }
}
