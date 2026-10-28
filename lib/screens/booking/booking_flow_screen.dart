import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/pricing.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/ui.dart';
import 'booking_steps.dart';

enum BookingStep { car, schedule, details, review }

const _stepNames = {
  BookingStep.car: 'Car',
  BookingStep.schedule: 'Date & time',
  BookingStep.details: 'Address',
  BookingStep.review: 'Review',
};

class BookingFlowScreen extends ConsumerStatefulWidget {
  final String serviceId;
  final CarType? initialCar;
  const BookingFlowScreen(
      {super.key, required this.serviceId, this.initialCar});

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  BookingStep _step = BookingStep.car;
  bool _forward = true;
  bool _showErrors = false;
  bool _saveDetails = true;
  bool _sending = false;

  CarService? get _service => serviceById(widget.serviceId);

  @override
  void initState() {
    super.initState();
    if (widget.initialCar != null && _service != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(draftProvider(widget.serviceId).notifier)
              .setCar(widget.initialCar!);
        }
      });
    }
  }

  bool _stepDone(BookingDraft d, BookingStep s) => switch (s) {
        BookingStep.car => d.carDone,
        BookingStep.schedule => d.scheduleDone,
        BookingStep.details => d.detailsDone,
        BookingStep.review => true,
      };

  String? _blockReason(BookingDraft d) => switch (_step) {
        BookingStep.car =>
          d.carDone ? null : 'Select your car size to continue',
        BookingStep.schedule => d.date == null
            ? 'Pick a date to continue'
            : (d.scheduleDone ? null : 'Pick a time slot to continue'),
        BookingStep.details =>
          d.detailsDone ? null : 'Fill in the highlighted fields',
        BookingStep.review => null,
      };

  void _goTo(BookingStep s) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = s.index > _step.index;
      _step = s;
      _showErrors = false;
    });
  }

  void _next(BookingDraft d) {
    if (!_stepDone(d, _step)) {
      setState(() => _showErrors = true);
      return;
    }
    _goTo(BookingStep.values[_step.index + 1]);
  }

  bool _back() {
    if (_step.index == 0) return false;
    _goTo(BookingStep.values[_step.index - 1]);
    return true;
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave booking?'),
        content: const Text('Your selections on this booking will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep booking')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      context.canPop() ? context.pop() : context.go('/home');
    }
  }

  Future<void> _send(BookingDraft d) async {
    if (_sending) return;
    setState(() => _sending = true);
    final record = BookingRecord.fromDraft(d);
    final opened =
        await openWhatsApp(context, message: record.whatsAppMessage());
    if (!mounted) return;
    if (opened) {
      await ref.read(bookingsProvider.notifier).add(record);
      final profile = ref.read(profileProvider.notifier);
      if (_saveDetails) {
        await profile.save(CustomerProfile(
          name: record.name,
          phone: record.phone,
          address: record.address,
          pin: record.pin,
          car: record.car,
          carModel: record.carModel,
        ));
      }
      if (mounted) context.pushReplacement('/booking-sent/${record.ref}');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Service not found',
            message: 'Please choose a service to book.',
            action: PrimaryButton(
                label: 'See services',
                expand: false,
                onPressed: () => context.go('/services')),
          ),
        ),
      );
    }

    final d = ref.watch(draftProvider(widget.serviceId));
    final notifier = ref.read(draftProvider(widget.serviceId).notifier);
    final reason = _blockReason(d);

    final body = switch (_step) {
      BookingStep.car =>
        CarStep(draft: d, notifier: notifier, showErrors: _showErrors),
      BookingStep.schedule =>
        ScheduleStep(draft: d, notifier: notifier, showErrors: _showErrors),
      BookingStep.details => DetailsStep(
          draft: d,
          notifier: notifier,
          showErrors: _showErrors,
          saveDetails: _saveDetails,
          onSaveDetailsChanged: (v) => setState(() => _saveDetails = v),
        ),
      BookingStep.review => ReviewStep(
          draft: d,
          notifier: notifier,
          onEdit: _goTo,
        ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_back()) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _step.index == 0 ? 'Close' : 'Back',
            icon: Icon(_step.index == 0
                ? Icons.close_rounded
                : Icons.arrow_back_rounded),
            onPressed: () {
              if (!_back()) _confirmLeave();
            },
          ),
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(service.name,
                style: AppText.h3, overflow: TextOverflow.ellipsis),
            Text('Step ${_step.index + 1} of 4 · ${_stepNames[_step]}',
                style: AppText.caption),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: _StepIndicator(
              current: _step,
              isDone: (s) => _stepDone(d, s),
              onTap: (s) {
                // Allow jumping back, or forward only through completed steps.
                final canReach = BookingStep.values
                    .take(s.index)
                    .every((prev) => _stepDone(d, prev));
                if (s.index < _step.index || canReach) _goTo(s);
              },
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: Offset(_forward ? 0.04 : -0.04, 0),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_step), child: body),
        ),
        bottomNavigationBar: BottomActionBar(
          top: _showErrors && reason != null
              ? Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(reason,
                        style:
                            AppText.caption.copyWith(color: AppColors.error)),
                  ),
                ])
              : null,
          child: Row(children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _step == BookingStep.review
                        ? 'Estimated total'
                        : d.car == null
                            ? 'Starts at'
                            : 'Price',
                    style: AppText.caption),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    d.car == null ? rupees(service.fromPrice) : rupees(d.total),
                    key: ValueKey(d.total),
                    style: AppText.price
                        .copyWith(fontSize: d.car == null ? 17 : 22),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _step == BookingStep.review
                  ? PrimaryButton(
                      label: 'Send on WhatsApp',
                      icon: Icons.chat_rounded,
                      loading: _sending,
                      onPressed: () => _send(d),
                    )
                  : PrimaryButton(
                      label: 'Continue',
                      // Stays tappable so a tap explains what's missing.
                      onPressed: () => _next(d),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final BookingStep current;
  final bool Function(BookingStep) isDone;
  final ValueChanged<BookingStep> onTap;

  const _StepIndicator(
      {required this.current, required this.isDone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 12),
      child: Row(children: [
        for (final s in BookingStep.values) ...[
          if (s.index > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Step ${s.index + 1}, ${_stepNames[s]}'
                  '${s == current ? ', current' : isDone(s) && s.index < current.index ? ', completed' : ''}',
              child: InkWell(
                onTap: () => onTap(s),
                borderRadius: BorderRadius.circular(6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        decoration: BoxDecoration(
                          color: s.index <= current.index
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stepNames[s]!,
                        style: AppText.caption.copyWith(
                          fontSize: 11.5,
                          color: s == current
                              ? AppColors.text
                              : AppColors.textSubtle,
                          fontWeight:
                              s == current ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
