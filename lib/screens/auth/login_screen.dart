import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/pricing.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../data/business_info.dart';
import '../../models/address.dart';
import '../../models/booking.dart';
import '../../providers/app_providers.dart';
import '../../widgets/customer_sheets.dart' show AddressForm;
import '../../widgets/ui.dart';

// ── Shared layout ─────────────────────────────────────────────────────────────

/// Dark brand header with the logo, then a white sheet holding the form and a
/// sticky action button above the keyboard.
/// Photo of the team at work with the brand and a one-line promise.
class _HeroHeader extends StatelessWidget {
  final double top;
  const _HeroHeader({required this.top});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: top + 230,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/wash_collage.jpg', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0xF20B0F10)],
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.fromLTRB(AppSpace.page, top + 14, AppSpace.page, 26),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(
                    child: Image.asset('assets/images/logo.png',
                        width: 36, height: 36)),
              ),
              const SizedBox(width: 10),
              Text('CleanCruisers',
                  style: AppText.h3.copyWith(color: Colors.white)),
            ]),
            const Spacer(),
            Text('Car wash at your\ndoorstep',
                style: AppText.display.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text('Trained experts · All of $kCityLabel · Pay after service',
                style: AppText.small.copyWith(color: AppColors.brand)),
          ]),
        ),
      ]),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  final Widget action;
  final bool showBack;
  final bool hero;
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.action,
    this.showBack = false,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayDark.copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Column(children: [
          if (hero)
            _HeroHeader(top: top)
          else
            Padding(
              padding: EdgeInsets.fromLTRB(8, top + 4, 20, 22),
              child: Row(children: [
                if (showBack)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  )
                else
                  const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: ClipOval(
                      child: Image.asset('assets/images/logo.png',
                          width: 40, height: 40)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CleanCruisers',
                            style: AppText.h3.copyWith(color: Colors.white)),
                        Text('Doorstep car care · $kCityLabel',
                            style: AppText.caption
                                .copyWith(color: Colors.white70)),
                      ]),
                ),
              ]),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.page, 28, AppSpace.page, 24),
                children: [
                  Semantics(
                      header: true, child: Text(title, style: AppText.h1)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: AppText.body),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page,
                12 + MediaQuery.paddingOf(context).bottom),
            child: action,
          ),
        ]),
      ),
    );
  }
}

// ── Step 1: mobile number ─────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _phone =
      TextEditingController(text: ref.read(profileProvider).phone);
  bool _sending = false;
  String? _error;

  bool get _valid => BookingDraft.phoneRe.hasMatch(_phone.text.trim());

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_valid || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final session =
          await ref.read(bookingCloudProvider).sendOtp(_phone.text.trim());
      if (!mounted) return;
      // Android may verify on its own; the router then moves on.
      if (!session.autoVerified) context.push('/login/otp', extra: session);
    } on BookingCloudException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(bookingCloudProvider).configured;
    return _AuthScaffold(
      hero: true,
      title: 'Log in with your mobile',
      subtitle:
          'We\'ll send a 6-digit OTP to verify your number. It\'s how our team reaches you about your bookings.',
      action: PrimaryButton(
        label: 'Get OTP',
        loading: _sending,
        onPressed: _valid ? _send : null,
      ),
      children: [
        Semantics(
          label: 'Mobile number',
          textField: true,
          child: TextField(
            controller: _phone,
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _send(),
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: AppText.h2.copyWith(letterSpacing: 1.5),
            decoration: InputDecoration(
              hintText: '98765 43210',
              hintStyle: AppText.h2
                  .copyWith(color: AppColors.border, letterSpacing: 1.5),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('+91', style: AppText.h2),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 26, color: AppColors.border),
                ]),
              ),
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final (icon, text) in const [
          (Icons.event_available_outlined, 'Book a wash in under a minute'),
          (
            Icons.track_changes_rounded,
            'Track your booking live, on any phone'
          ),
          (Icons.payments_outlined, 'Pay after the service, by cash or UPI'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              IconBadge(icon, size: 34),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: AppText.small.copyWith(color: AppColors.text))),
            ]),
          ),
        if (!configured) ...[
          const SizedBox(height: 8),
          const NoticeBox(
            icon: Icons.cloud_off_outlined,
            warning: true,
            text:
                'OTP login isn\'t connected in this build yet (Firebase setup pending).',
          ),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Browse services without logging in'),
          ),
        ],
      ],
    );
  }
}

// ── Step 2: OTP ───────────────────────────────────────────────────────────────
class OtpScreen extends ConsumerStatefulWidget {
  final OtpSession session;
  const OtpScreen({super.key, required this.session});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 6;
  static const _resendAfter = 30;
  final _code = TextEditingController();
  final _focus = FocusNode();
  late OtpSession _session = widget.session;
  bool _verifying = false;
  String? _error;
  int _secondsLeft = _resendAfter;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != _length || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(bookingCloudProvider).verifyOtp(_session, _code.text);
      // The router redirects once the user is signed in.
    } on BookingCloudException catch (e) {
      setState(() {
        _error = e.message;
        _code.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      _session = await ref
          .read(bookingCloudProvider)
          .sendOtp(_session.phone, resend: _session);
      _startTimer();
      if (mounted) showMessage(context, 'A new OTP is on its way.');
    } on BookingCloudException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _session.phone;
    final shown = '+91 ${p.substring(0, 5)} ${p.substring(5)}';
    return _AuthScaffold(
      showBack: true,
      title: 'Enter the OTP',
      subtitle: 'Sent by SMS to $shown',
      action: PrimaryButton(
        label: 'Verify & continue',
        loading: _verifying,
        onPressed: _code.text.length == _length ? _verify : null,
      ),
      children: [
        // One real field (for paste and SMS autofill) drawn as six boxes.
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Stack(children: [
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _code,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                onChanged: (v) {
                  setState(() => _error = null);
                  if (v.length == _length) _verify();
                },
              ),
            ),
            Semantics(
              label: 'OTP, ${_code.text.length} of $_length digits entered',
              child: Row(children: [
                for (var i = 0; i < _length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _box(i)),
                ],
              ]),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppText.small.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Text('Didn\'t get it? ', style: AppText.small),
          if (_secondsLeft > 0)
            Text('Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                style: AppText.smallStrong)
          else
            TextButton(
              onPressed: _resend,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
              child: const Text('Resend OTP'),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Change number'),
          ),
        ]),
      ],
    );
  }

  Widget _box(int i) {
    final text = _code.text;
    final filled = i < text.length;
    final active = i == text.length && _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.primarySoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: _error != null
              ? AppColors.error
              : active
                  ? AppColors.primary
                  : filled
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.border,
          width: active ? 2 : 1.2,
        ),
      ),
      child: Text(filled ? text[i] : '', style: AppText.h1),
    );
  }
}

// ── Step 3: name and car (first login only) ──────────────────────────────────
/// Asked once. Every booking reuses it, so checkout never asks again.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final _name =
      TextEditingController(text: ref.read(profileProvider).name);
  late CarType? _car = ref.read(profileProvider).car;
  bool _saving = false;

  bool get _valid => _name.text.trim().length >= 2 && _car != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final cloud = ref.read(bookingCloudProvider);
    final profile = ref.read(profileProvider);
    try {
      await ref.read(profileProvider.notifier).save(CustomerProfile(
            name: _name.text.trim(),
            phone: cloud.verifiedPhone ?? profile.phone,
            address: profile.address,
            pin: profile.pin,
            car: _car,
            carModel: profile.carModel,
          ));
      await cloud.saveCustomerName(_name.text);
      // The router moves on once the name is saved.
    } on Object {
      if (mounted) {
        showMessage(context, 'Couldn\'t save. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Welcome!',
      subtitle: 'Tell us about you and your car. Just once.',
      action: PrimaryButton(
          label: 'Continue',
          loading: _saving,
          onPressed: _valid ? _save : null),
      children: [
        Semantics(
          label: 'Your name',
          textField: true,
          child: TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text('Your car', style: AppText.h3),
        const SizedBox(height: 12),
        CarTypePicker(
            selected: _car, onChanged: (c) => setState(() => _car = c)),
      ],
    );
  }
}

// ── Step 4: where the car is parked (first login only) ───────────────────────
class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key});

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  late final _profile = ref.read(profileProvider);
  late String _address = _profile.address;
  late String? _pin = _profile.pin;
  late CarType? _car = _profile.car;
  bool _saving = false;

  bool get _valid => _address.isNotEmpty && _car != null;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    // Car first, then the address goes into the address book as "Home"
    // (selecting it fills the profile). The router then moves on to Home.
    await ref
        .read(profileProvider.notifier)
        .save(ref.read(profileProvider).copyWith(car: _car));
    final book = ref.read(addressBookProvider);
    final home =
        book.items.where((a) => a.label == AddressLabel.home).firstOrNull;
    await ref.read(addressBookProvider.notifier).save(SavedAddress(
          id: home?.id ?? 'home',
          label: AddressLabel.home,
          address: _address,
          pin: _pin,
        ));
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _skip() async {
    // Keep the car if they picked one: it gives exact prices while browsing.
    if (_car != null && _profile.car == null) {
      await ref
          .read(profileProvider.notifier)
          .save(ref.read(profileProvider).copyWith(car: _car));
    }
    await ref.read(setupSkippedProvider.notifier).skip();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Where do you park?',
      subtitle: 'Our expert comes here for every wash.',
      action: Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(
            label: 'Start booking',
            loading: _saving,
            onPressed: _valid ? _save : null),
        // Let people look at services and prices first; booking will ask
        // for the address if it's still missing.
        TextButton(
          onPressed: _saving ? null : _skip,
          child: const Text('Skip, just browsing'),
        ),
      ]),
      children: [
        // Customers from before onboarding asked for the car may not have one.
        if (_profile.car == null) ...[
          Text('Your car', style: AppText.h3),
          const SizedBox(height: 12),
          CarTypePicker(
              selected: _car, onChanged: (c) => setState(() => _car = c)),
          const SizedBox(height: 26),
        ],
        AddressForm(
          initialAddress: _profile.address,
          initialPin: _profile.pin,
          onChanged: (a, p) => setState(() {
            _address = a;
            _pin = p;
          }),
        ),
      ],
    );
  }
}

/// Four car categories as large tappable tiles.
class CarTypePicker extends StatelessWidget {
  final CarType? selected;
  final ValueChanged<CarType> onChanged;
  final int? Function(CarType)? priceFor;
  const CarTypePicker(
      {super.key,
      required this.selected,
      required this.onChanged,
      this.priceFor});

  static const icons = {
    CarType.hatchback: Icons.directions_car_filled_rounded,
    CarType.sedan: Icons.local_taxi_rounded,
    CarType.suv: Icons.airport_shuttle_rounded,
    CarType.luxury: Icons.diamond_outlined,
  };

  static const modelExamples = {
    CarType.hatchback: 'Swift, i10, Baleno, Tiago',
    CarType.sedan: 'City, Verna, Dzire, Ciaz',
    CarType.suv: 'Brezza, Nexon, Creta, Venue',
    CarType.luxury: 'BMW, Audi, Mercedes, Jaguar',
  };

  @override
  Widget build(BuildContext context) {
    // Two per row; each tile is as tall as its text, so the model examples
    // are never cut off, even with large system text.
    return LayoutBuilder(
      builder: (context, box) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in CarType.values)
            SizedBox(
              width: (box.maxWidth - 10) / 2,
              child: Semantics(
                button: true,
                selected: selected == c,
                label: '${carTypeNames[c]}, like ${modelExamples[c]}',
                child: AppCard(
                  selected: selected == c,
                  padding: const EdgeInsets.all(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(c);
                  },
                  child: ExcludeSemantics(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selected == c
                                  ? AppColors.primary
                                  : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(icons[c],
                                color: selected == c
                                    ? Colors.white
                                    : AppColors.primary,
                                size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(carTypeNames[c]!,
                                      style: AppText.bodyStrong,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  // Which size am I? Examples settle it.
                                  Text(modelExamples[c]!,
                                      style: AppText.caption,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  if (priceFor?.call(c) case final p?) ...[
                                    const SizedBox(height: 2),
                                    Text(rupees(p),
                                        style: AppText.bodyStrong.copyWith(
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ]),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
