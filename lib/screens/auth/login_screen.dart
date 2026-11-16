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

// ── Shared layout (v3 design) ────────────────────────────────────────────────

/// Our team at work, the logo, and the promise in one line.
class _HeroHeader extends StatelessWidget {
  final double top;
  const _HeroHeader({required this.top});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: top + 300,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/hero_team_kit.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.1, -0.5),
            cacheWidth: 1000,
            excludeFromSemantics: true),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.3, 0.75, 1],
              colors: [
                Color(0x8C0B0F10),
                Color(0x000B0F10),
                Color(0xCC0B0F10),
                AppColors.ink
              ],
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.fromLTRB(AppSpace.page, top + 14, AppSpace.page, 40),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ClipOval(
                  child: Image.asset('assets/images/logo.png',
                      width: 40,
                      height: 40,
                      cacheWidth: 160,
                      excludeFromSemantics: true)),
              const SizedBox(width: 10),
              Text.rich(
                const TextSpan(children: [
                  TextSpan(text: 'Clean'),
                  TextSpan(
                      text: 'Cruisers',
                      style: TextStyle(color: AppColors.brand)),
                ]),
                style: AppText.h3.copyWith(color: Colors.white),
              ),
            ]),
            const Spacer(),
            Text('Car wash at your\ndoorstep',
                style: AppText.display.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text(
                'Trained experts · All of $kCityLabel'
                '${kPayAfterService ? ' · Pay after service' : ''}',
                style: AppText.small.copyWith(color: const Color(0xFFD1D7DC))),
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

  /// Sign-up steps: "Step 1 of 2" and a progress bar.
  final int? step, steps;
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.action,
    this.showBack = false,
    this.hero = false,
    this.step,
    this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final head =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (step != null && steps != null) ...[
        Row(children: [
          for (var i = 0; i < steps!; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color:
                      i < step! ? AppColors.primary : const Color(0xFFDDE1E5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: AppSpace.md),
        Text('Step $step of $steps', style: AppText.caption),
        const SizedBox(height: 2),
      ],
      Semantics(header: true, child: Text(title, style: AppText.h1)),
      const SizedBox(height: 6),
      Text(subtitle, style: AppText.body),
      const SizedBox(height: AppSpace.xxl),
    ]);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: hero
          ? AppTheme.overlayDark.copyWith(
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: hero ? AppColors.ink : AppColors.bg,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: Column(children: [
            if (hero) _HeroHeader(top: top),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: hero
                      ? const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.lg))
                      : null,
                ),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(AppSpace.page,
                      hero ? 26 : top + AppSpace.md, AppSpace.page, 24),
                  children: [
                    if (showBack) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          button: true,
                          label: 'Back',
                          child: ExcludeSemantics(
                            child: Material(
                              color: AppColors.surface,
                              shape: const CircleBorder(
                                  side: BorderSide(color: AppColors.border)),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => context.pop(),
                                child: const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(Icons.arrow_back_rounded,
                                      size: 20, color: AppColors.text),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                    ],
                    head,
                    ...children,
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page,
                  12 + MediaQuery.paddingOf(context).bottom),
              child: action,
            ),
          ]),
        ),
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
      subtitle: 'We\'ll send a 6-digit code by SMS.',
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
              labelText: 'Mobile number',
              floatingLabelBehavior: FloatingLabelBehavior.always,
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
        const SizedBox(height: AppSpace.md),
        Text(
            'Our team uses this number only to reach you about your '
            'bookings.',
            style: AppText.caption),
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
        label: 'Verify and continue',
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
        // Wraps to two lines on small phones with large text.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Didn\'t get it? ', style: AppText.small),
              if (_secondsLeft > 0)
                Text('Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: AppText.smallStrong)
              else
                TextButton(
                  onPressed: _resend,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44)),
                  child: const Text('Resend code'),
                ),
            ]),
            TextButton(
              onPressed: () => context.pop(),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Change number'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _box(int i) {
    final text = _code.text;
    final filled = i < text.length;
    final active = i == text.length && _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _error != null
              ? AppColors.error
              : active
                  ? AppColors.primary
                  : filled
                      ? const Color(0xFFB9C2BC)
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
  late final _model =
      TextEditingController(text: ref.read(profileProvider).carModel);
  late CarType? _car = ref.read(profileProvider).car;
  bool _saving = false;

  bool get _valid => _name.text.trim().length >= 2 && _car != null;

  @override
  void dispose() {
    _name.dispose();
    _model.dispose();
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
            carModel: _model.text.trim(),
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
      step: 1,
      steps: 2,
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
              labelText: 'Your name',
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        Text('Your car\'s size', style: AppText.h3),
        const SizedBox(height: 2),
        Text('Prices depend on it. You can change it any time.',
            style: AppText.small),
        const SizedBox(height: AppSpace.md),
        CarTypePicker(
            selected: _car, onChanged: (c) => setState(() => _car = c)),
        const SizedBox(height: AppSpace.xl),
        Semantics(
          label: 'Model and colour, optional',
          textField: true,
          child: TextField(
            controller: _model,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Model and colour (optional)',
              hintText: 'e.g. White Swift',
              helperText: 'Helps the expert find your car',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
          ),
        ),
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
      step: 2,
      steps: 2,
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
          Text('Your car\'s size', style: AppText.h3),
          const SizedBox(height: AppSpace.md),
          CarTypePicker(
              selected: _car, onChanged: (c) => setState(() => _car = c)),
          const SizedBox(height: AppSpace.xxl),
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

/// The four car sizes as a list: name, example models (which size am I?),
/// an optional price, and a radio.
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
    return Column(children: [
      for (final c in CarType.values) ...[
        if (c != CarType.values.first) const SizedBox(height: AppSpace.sm),
        Semantics(
          button: true,
          selected: selected == c,
          label: '${carTypeNames[c]}, like ${modelExamples[c]}'
              '${priceFor?.call(c) == null ? '' : ', ${rupees(priceFor!(c)!)}'}',
          child: ExcludeSemantics(
            child: AppCard(
              selected: selected == c,
              radius: AppRadius.md,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg, vertical: AppSpace.md),
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(c);
              },
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(carTypeNames[c]!, style: AppText.title),
                        Text('Like ${modelExamples[c]}', style: AppText.small),
                      ]),
                ),
                if (priceFor?.call(c) case final p?) ...[
                  const SizedBox(width: AppSpace.sm),
                  Text(rupees(p),
                      style: AppText.bodyStrong.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800)),
                ],
                const SizedBox(width: AppSpace.md),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected == c ? AppColors.primary : null,
                    border: Border.all(
                        color: selected == c
                            ? AppColors.primary
                            : const Color(0xFFB9C2BC),
                        width: 2),
                  ),
                  child: selected == c
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        )
                      : null,
                ),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}
