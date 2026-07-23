import 'package:flutter/material.dart';
import '../core/constants.dart';

class SectionHeader extends StatelessWidget {
  final String tag;
  final String title;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.tag,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: kGreen400.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGreen400.withAlpha(77)),
          ),
          child: Text(tag,
              style: tt.labelLarge?.copyWith(
                color: kGreen400, fontSize: 11, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 10),
        Text(title, style: tt.displayMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: tt.bodyLarge?.copyWith(color: kGray400)),
        ],
      ],
    );
  }
}

class GreenDivider extends StatelessWidget {
  const GreenDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: kGray700.withAlpha(128));
  }
}
