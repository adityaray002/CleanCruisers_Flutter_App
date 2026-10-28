import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/booking.dart';
import '../providers/app_providers.dart';
import '../widgets/contact_actions.dart';
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
          _title('Your details'),
          AppCard(
            child: p.isEmpty
                ? Row(children: [
                    const IconBadge(Icons.person_outline_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Your name, number, address and car are saved here after your first booking, '
                        'so next time takes seconds.',
                        style: AppText.small,
                      ),
                    ),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        if (p.name.isNotEmpty)
                          InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Name',
                              value: p.name),
                        if (p.phone.isNotEmpty)
                          InfoRow(
                              icon: Icons.phone_outlined,
                              label: 'Mobile',
                              value: '+91 ${p.phone}'),
                        if (p.address.isNotEmpty)
                          InfoRow(
                              icon: Icons.home_outlined,
                              label: 'Address',
                              value: p.address),
                        if (p.car != null)
                          InfoRow(
                            icon: Icons.directions_car_outlined,
                            label: 'Car',
                            value: p.carModel.isEmpty
                                ? carTypeNames[p.car]!
                                : '${p.carModel} · ${carTypeNames[p.car]}',
                          ),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Edit',
                              icon: Icons.edit_outlined,
                              dense: true,
                              onPressed: () => _editProfile(context, ref, p),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSubtle),
                            onPressed: () async {
                              await ref.read(profileProvider.notifier).clear();
                              if (context.mounted) {
                                showMessage(context, 'Saved details cleared.');
                              }
                            },
                            child: const Text('Clear'),
                          ),
                        ]),
                      ]),
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
                icon: Icons.call_outlined,
                label: 'Call · $kHoursLabel',
                value: kPhoneDisplay,
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSubtle),
                onTap: () => callUs(context),
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
              const InfoRow(
                  icon: Icons.business_outlined,
                  label: 'Office',
                  value: kAddress),
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
          const SizedBox(height: 32),
          Center(
              child:
                  Text('CleanCruisers app · v1.0.0', style: AppText.caption)),
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Semantics(header: true, child: Text(t, style: AppText.h3)),
      );

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
  late final _address = TextEditingController(text: widget.initial.address);
  late final _model = TextEditingController(text: widget.initial.carModel);
  late CarType? _car = widget.initial.car;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _model]) {
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
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Address'),
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
                  address: _address.text.trim(),
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
