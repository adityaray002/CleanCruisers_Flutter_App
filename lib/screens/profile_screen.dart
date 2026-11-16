import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/address.dart';
import '../models/booking.dart';
import '../providers/app_providers.dart';
import '../widgets/contact_actions.dart';
import '../widgets/customer_sheets.dart';
import '../widgets/ui.dart';

/// Profile (v3 design): who you are, your car, addresses, bookings and
/// CleanCredit; help; about; log out (with a confirm) and team sign in.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final upcoming = ref
        .watch(myBookingsProvider)
        .where((b) => b.isUpcoming() && !b.status.isFinal)
        .length;
    final book = ref.watch(addressBookProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.section),
            children: [
              Semantics(
                  header: true, child: Text('Profile', style: AppText.h1)),
              const SizedBox(height: AppSpace.lg),
              _ProfileHeader(
                profile: p,
                onEdit: () => _editProfile(context, ref, p),
              ),
              const SizedBox(height: AppSpace.md),
              _Group(rows: [
                _Row(
                  icon: Icons.directions_car_outlined,
                  title: 'My car',
                  line: p.car == null
                      ? 'Not added yet'
                      : p.carModel.isEmpty
                          ? carTypeNames[p.car]!
                          : '${p.carModel} · ${carTypeNames[p.car]}',
                  onTap: () => showCarSheet(context, ref),
                ),
                _Row(
                  icon: Icons.location_on_outlined,
                  title: 'My addresses',
                  line: book.items.isEmpty
                      ? 'Add an address'
                      : book.items
                          .map((a) => addressLabelNames[a.label])
                          .join(', '),
                  onTap: () => context.push('/addresses'),
                ),
                _Row(
                  icon: Icons.event_note_outlined,
                  title: 'My bookings',
                  line:
                      upcoming == 0 ? 'Track and manage' : '$upcoming upcoming',
                  onTap: () => context.go('/bookings'),
                ),
                _Row(
                  icon: Icons.local_offer_outlined,
                  tint: true,
                  title: 'CleanCredit and offers',
                  line: 'Credit ${rupees(ref.watch(walletProvider).balance)} · '
                      'see your offers',
                  onTap: () => context.go('/wallet'),
                ),
              ]),
              _title('HELP'),
              _Group(rows: [
                _Row(
                  icon: Icons.chat_outlined,
                  tint: true,
                  title: 'WhatsApp',
                  line: 'Fastest reply',
                  onTap: () => openWhatsApp(context),
                ),
                _Row(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email',
                  line: kEmail,
                  onTap: () => openLink(context, 'mailto:$kEmail'),
                ),
                _Row(
                  icon: Icons.menu_book_outlined,
                  title: 'Car care tips',
                  line: 'Guides from the CleanCruisers team',
                  onTap: () => context.push('/blog'),
                ),
              ]),
              _title('ABOUT'),
              _Group(rows: [
                const _Row(
                  icon: Icons.schedule_rounded,
                  title: 'Service hours',
                  line: '$kDaysLabel, $kHoursLabel',
                ),
                _Row(
                  icon: Icons.place_outlined,
                  title: 'Areas we serve',
                  line: kServiceAreas.join(', '),
                ),
                _Row(
                  icon: Icons.public_rounded,
                  title: 'Website',
                  line: kWebsite.replaceFirst('https://', ''),
                  onTap: () => openLink(context, kWebsite),
                ),
              ]),
              const SizedBox(height: AppSpace.md),
              const Wrap(spacing: 8, runSpacing: 8, children: [
                _SocialChip('Instagram', kInstagram),
                _SocialChip('Facebook', kFacebook),
                _SocialChip('LinkedIn', kLinkedIn),
              ]),
              const SizedBox(height: AppSpace.xl),
              if (ref.watch(bookingCloudProvider).customerSignedIn)
                OutlinedButton(
                  onPressed: () => _logout(context, ref),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.error,
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    textStyle: AppText.bodyStrong,
                  ),
                  child: const Text('Log out'),
                ),
              const SizedBox(height: AppSpace.lg),
              Center(
                child: Text(
                    'CleanCruisers'
                    '${kEstablished != null ? ' · serving $kCityLabel since $kEstablished' : ''}'
                    ' · v1.0.0',
                    textAlign: TextAlign.center,
                    style: AppText.caption),
              ),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/ops/login'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSubtle,
                      minimumSize: const Size(0, 44)),
                  child: const Text('Team sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
        child: Semantics(header: true, child: Text(t, style: AppText.overline)),
      );

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'Your bookings stay safe. Log in again with your mobile number to see them.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(profileProvider.notifier).clear();
    await ref.read(bookingCloudProvider).signOutCustomer();
  }

  Future<void> _editProfile(
      BuildContext context, WidgetRef ref, CustomerProfile p) async {
    final result = await showModalBottomSheet<CustomerProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProfileSheet(
          initial: p,
          phoneIsLogin: ref.read(bookingCloudProvider).verifiedPhone != null),
    );
    if (result != null) {
      await ref.read(profileProvider.notifier).save(result);
      if (context.mounted) showMessage(context, 'Details saved.');
    }
  }
}

class _SocialChip extends StatelessWidget {
  final String label, url;
  const _SocialChip(this.label, this.url);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.open_in_new_rounded, size: 16),
      labelStyle: AppText.smallStrong,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
      onPressed: () => openLink(context, url),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final CustomerProfile initial;

  /// Signed in with OTP: the number is the login and isn't edited here.
  final bool phoneIsLogin;
  const _EditProfileSheet({required this.initial, this.phoneIsLogin = false});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _model = TextEditingController(text: widget.initial.carModel);
  late CarType? _car = widget.initial.car;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _model]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _phoneOk =>
      _phone.text.isEmpty || BookingDraft.phoneRe.hasMatch(_phone.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit your details', style: AppText.h2),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          if (!widget.phoneIsLogin)
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Mobile number',
                prefixText: '+91  ',
                errorText: _submitted && !_phoneOk
                    ? 'Enter a valid 10-digit mobile number'
                    : null,
              ),
            ),
          if (widget.phoneIsLogin)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'Your phone number is your login. To change it, chat with us.',
                  style: AppText.caption),
            ),
          const SizedBox(height: 16),
          Text('Car size', style: AppText.smallStrong),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in CarType.values)
              ChoiceChip(
                label: Text(carTypeNames[c]!),
                selected: _car == c,
                onSelected: (_) => setState(() => _car = c),
                selectedColor: AppColors.ink,
                showCheckmark: false,
                labelStyle: AppText.smallStrong
                    .copyWith(color: _car == c ? Colors.white : AppColors.text),
                side: BorderSide(
                    color: _car == c ? AppColors.ink : AppColors.border),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Model and colour (optional)',
                hintText: 'e.g. White Swift'),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Save',
            onPressed: () {
              setState(() => _submitted = true);
              if (!_phoneOk) return;
              Navigator.pop(
                context,
                CustomerProfile(
                  name: _name.text.trim(),
                  phone: _phone.text.trim(),
                  // Addresses are edited in "My addresses".
                  address: widget.initial.address,
                  pin: widget.initial.pin,
                  car: _car,
                  carModel: _model.text.trim(),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final CustomerProfile profile;
  final VoidCallback onEdit;
  const _ProfileHeader({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(bookingCloudProvider);
    final name = (cloud.customerName ?? profile.name).trim();
    final phone = cloud.verifiedPhone ?? profile.phone;
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.brand,
          child:
              Text(initials, style: AppText.h2.copyWith(color: AppColors.ink)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? 'Welcome' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.h3.copyWith(color: Colors.white)),
            if (phone.isNotEmpty)
              Row(children: [
                Text(phoneLabel(phone),
                    style:
                        AppText.small.copyWith(color: const Color(0xFFB8C0C7))),
                if (cloud.verifiedPhone != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded,
                      size: 15, color: AppColors.brand),
                ],
              ]),
          ]),
        ),
        Semantics(
          button: true,
          label: 'Edit your details',
          child: ExcludeSemantics(
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF141B1D),
                side: const BorderSide(color: Color(0xFF2A3336)),
                textStyle: AppText.smallStrong,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A white card of rows with hairlines between them.
class _Group extends StatelessWidget {
  final List<_Row> rows;
  const _Group({required this.rows});

  @override
  Widget build(BuildContext context) => AppCard(
        radius: AppRadius.lg,
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 66),
            rows[i],
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title, line;
  final VoidCallback? onTap;
  final bool tint;
  const _Row({
    required this.icon,
    required this.title,
    required this.line,
    this.onTap,
    this.tint = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint ? AppColors.primarySoft : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon,
              size: 19, color: tint ? AppColors.primary : AppColors.text),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.title),
            Text(line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.small),
          ]),
        ),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
      ]),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$title. $line',
      child: ExcludeSemantics(child: InkWell(onTap: onTap, child: row)),
    );
  }
}
