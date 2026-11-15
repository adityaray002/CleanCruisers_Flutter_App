import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/booking.dart';
import '../providers/app_providers.dart';
import '../widgets/contact_actions.dart';
import '../widgets/customer_sheets.dart';
import '../widgets/ui.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 40),
        children: [
          const SizedBox(height: 8),
          _ProfileHeader(
            profile: p,
            onEdit: () => _editProfile(context, ref, p),
          ),
          _title('Help & support'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              InfoRow(
                icon: Icons.chat_outlined,
                label: 'WhatsApp · fastest reply',
                value: 'Chat with us',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSubtle),
                onTap: () => openWhatsApp(context),
              ),
              const Divider(),
              InfoRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: kEmail,
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSubtle),
                onTap: () => openLink(context, 'mailto:$kEmail'),
              ),
            ]),
          ),
          _title('Learn'),
          AppCard(
            onTap: () => context.push('/blog'),
            child: Row(children: [
              const IconBadge(Icons.menu_book_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Car care tips', style: AppText.bodyStrong),
                      Text('Guides from the CleanCruisers team',
                          style: AppText.small),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSubtle),
            ]),
          ),
          _title('About CleanCruisers'),
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipOval(
                    child: Image.asset('assets/images/logo.png',
                        width: 48, height: 48)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CleanCruisers', style: AppText.h3),
                        Text(
                          'Doorstep car wash & detailing'
                          '${kEstablished != null ? ' · since $kEstablished' : ''}',
                          style: AppText.caption,
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                'We bring professional car cleaning to your home, office or society in $kCityLabel. '
                'Our team arrives with foam shampoo, high-pressure equipment and polishing tools, '
                'and cleans your car where it\'s parked.',
                style: AppText.small,
              ),
              const SizedBox(height: 8),
              const Divider(),
              const InfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Service hours',
                  value: '$kHoursLabel · $kDaysLabel'),
              const SizedBox(height: 6),
              const Wrap(spacing: 8, runSpacing: 8, children: [
                _SocialChip('Instagram', kInstagram),
                _SocialChip('Facebook', kFacebook),
                _SocialChip('LinkedIn', kLinkedIn),
                _SocialChip('Website', kWebsite),
              ]),
            ]),
          ),
          _title('Areas we serve'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in kServiceAreas) Pill(a, icon: Icons.place_outlined),
          ]),
          const SizedBox(height: 28),
          if (ref.watch(bookingCloudProvider).customerSignedIn)
            SecondaryButton(
              label: 'Log out',
              icon: Icons.logout_rounded,
              onPressed: () => _logout(context, ref),
            ),
          const SizedBox(height: 20),
          Center(
              child:
                  Text('CleanCruisers app · v1.0.0', style: AppText.caption)),
          Center(
            child: TextButton(
              onPressed: () => context.push('/ops/login'),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.textSubtle),
              child: const Text('Team sign in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Semantics(header: true, child: Text(t, style: AppText.h3)),
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
      builder: (_) => _EditProfileSheet(initial: p),
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
  const _EditProfileSheet({required this.initial});

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
          const SizedBox(height: 16),
          Text('Car size', style: AppText.smallStrong),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in CarType.values)
              ChoiceChip(
                label: Text(carTypeNames[c]!),
                selected: _car == c,
                onSelected: (_) => setState(() => _car = c),
                selectedColor: AppColors.primarySoft,
                side: BorderSide(
                    color: _car == c ? AppColors.primary : AppColors.border),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(labelText: 'Car make & model (optional)'),
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
    final name = cloud.customerName ?? profile.name;
    final phone = cloud.verifiedPhone ?? profile.phone;
    final p = profile;
    return Column(children: [
      AppCard(
        color: AppColors.ink,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.brand,
            child: Text(
                name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                style: AppText.h1.copyWith(color: AppColors.ink)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.trim().isEmpty ? 'Welcome' : name,
                  style: AppText.h2.copyWith(color: Colors.white)),
              if (phone.isNotEmpty)
                Row(children: [
                  Text(phoneLabel(phone),
                      style: AppText.small.copyWith(color: Colors.white70)),
                  if (cloud.verifiedPhone != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        size: 15, color: AppColors.brand),
                  ],
                ]),
            ]),
          ),
          IconButton(
            tooltip: 'Edit details',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          InfoRow(
            icon: Icons.directions_car_outlined,
            label: 'My car',
            value: p.car == null
                ? 'Not added yet'
                : p.carModel.isEmpty
                    ? carTypeNames[p.car]!
                    : '${p.carModel} · ${carTypeNames[p.car]}',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSubtle),
            onTap: onEdit,
          ),
          const Divider(),
          InfoRow(
            icon: Icons.location_on_outlined,
            label: 'My addresses',
            value: p.address.isEmpty ? 'Add an address' : p.address,
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSubtle),
            onTap: () => showAddressSheet(context, ref),
          ),
          const Divider(),
          InfoRow(
            icon: Icons.event_note_outlined,
            label: 'My bookings',
            value: 'Track and manage',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSubtle),
            onTap: () => context.go('/bookings'),
          ),
          const Divider(),
          Consumer(
            builder: (context, ref, _) => InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'CleanCredit & offers',
              value: rupees(ref.watch(walletProvider).balance),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSubtle),
              onTap: () => context.go('/wallet'),
            ),
          ),
        ]),
      ),
    ]);
  }
}
