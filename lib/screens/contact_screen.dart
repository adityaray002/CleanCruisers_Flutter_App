import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../widgets/section_header.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: kBgBlack,
            title: const Text('Contact & About',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 0.5, color: kGray700),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ContactActions(),
                const SizedBox(height: 32),
                _AboutSection(),
                const SizedBox(height: 32),
                _AddressSection(),
                const SizedBox(height: 32),
                _SocialSection(),
                const SizedBox(height: 32),
                _ServiceAreasSection(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Contact Buttons ────────────────────────────────────────────────────────
class _ContactActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          tag: 'GET IN TOUCH',
          title: 'Contact Us',
          subtitle: 'We\'re available 7 days a week, 7 AM to 8 PM.',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/booking'),
            icon: const Icon(Icons.local_car_wash, size: 20),
            label: const Text('Book a Car Wash'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => launchUrl(Uri.parse(kWhatsAppUrl),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.chat, size: 20),
            label: const Text('Chat on WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('tel:$kPhone')),
            icon: const Icon(Icons.call, size: 20),
            label: Text('Call $kPhoneDisplay'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                launchUrl(Uri.parse('mailto:$kEmail')),
            icon: const Icon(Icons.email_outlined, size: 20),
            label: const Text('Email Us'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }
}

// ── About ────────────────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  static const _stats = [
    ('1000+', 'Customers'),
    ('4.9★', 'Rating'),
    ('7 Days', 'Per Week'),
    ('2020', 'Est. Year'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(tag: 'ABOUT US', title: 'Who We Are'),
        const SizedBox(height: 16),
        Center(
          child: ClipOval(
            child: Image.asset('assets/images/logo.png',
                width: 90, height: 90, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'CleanCruisers is Delhi\'s trusted doorstep car wash and detailing service. We bring professional-grade car cleaning directly to your home, office, or society — at a time that works for you.',
          style: TextStyle(color: kGray400, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 12),
        const Text(
          'Our trained professionals use foam shampoo, high-pressure equipment, and eco-friendly products to deliver a thorough clean every time. No advance payment, no hassle.',
          style: TextStyle(color: kGray400, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _stats.map((s) => _StatCard(value: s.$1, label: s.$2)).toList(),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGray700.withAlpha(128)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: kGreen400, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: kGray400, fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ── Address ───────────────────────────────────────────────────────────────────────
class _AddressSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(tag: 'LOCATION', title: 'Our Address'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kBgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kGray700.withAlpha(128)),
          ),
          child: Column(
            children: [
              _AddressRow(
                icon: Icons.location_on,
                label: 'Address',
                value: kAddress,
              ),
              const SizedBox(height: 14),
              const Divider(color: kGray700, height: 1),
              const SizedBox(height: 14),
              _AddressRow(
                icon: Icons.schedule,
                label: 'Working Hours',
                value: '7 AM – 8 PM, Monday to Sunday',
              ),
              const SizedBox(height: 14),
              const Divider(color: kGray700, height: 1),
              const SizedBox(height: 14),
              _AddressRow(
                icon: Icons.phone,
                label: 'Phone',
                value: kPhoneDisplay,
              ),
              const SizedBox(height: 14),
              const Divider(color: kGray700, height: 1),
              const SizedBox(height: 14),
              _AddressRow(
                icon: Icons.email,
                label: 'Email',
                value: kEmail,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AddressRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kGreen400.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kGreen400, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: kGray400, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Social ────────────────────────────────────────────────────────────────────────
class _SocialSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(tag: 'FOLLOW US', title: 'Stay Connected'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _SocialButton(
              label: 'Instagram',
              icon: Icons.camera_alt_outlined,
              color: const Color(0xFFE1306C),
              onTap: () => launchUrl(Uri.parse(kInstagram),
                  mode: LaunchMode.externalApplication),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SocialButton(
              label: 'Facebook',
              icon: Icons.facebook,
              color: const Color(0xFF1877F2),
              onTap: () => launchUrl(Uri.parse(kFacebook),
                  mode: LaunchMode.externalApplication),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SocialButton(
              label: 'LinkedIn',
              icon: Icons.work_outline,
              color: const Color(0xFF0A66C2),
              onTap: () => launchUrl(Uri.parse(kLinkedIn),
                  mode: LaunchMode.externalApplication),
            ),
          ),
        ]),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Service Areas ─────────────────────────────────────────────────────────────────
class _ServiceAreasSection extends StatelessWidget {
  static const _areas = [
    'Dwarka', 'Janakpuri', 'Uttam Nagar', 'South Delhi',
    'East Delhi', 'New Delhi', 'West Delhi', 'Vikaspuri',
    'Paschim Vihar', 'Rohini', 'Pitampura',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(tag: 'COVERAGE', title: 'Areas We Serve'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _areas.map((a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kBgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGray700.withAlpha(128)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on, color: kGreen400, size: 12),
              const SizedBox(width: 5),
              Text(a,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          )).toList(),
        ),
      ],
    );
  }
}
