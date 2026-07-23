import 'package:flutter/material.dart';
import '../core/constants.dart';

class InclusionItem extends StatelessWidget {
  final String text;
  const InclusionItem(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: kGreen400, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class InclusionChip extends StatelessWidget {
  final String text;
  const InclusionChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kGreen400.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGreen400.withAlpha(77)),
      ),
      child: Text(text,
          style: const TextStyle(color: kGreen400, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class PriceTag extends StatelessWidget {
  final int price;
  final String? suffix;
  const PriceTag({super.key, required this.price, this.suffix});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: [
        const TextSpan(
          text: '₹',
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: kGreen400),
        ),
        TextSpan(
          text: '$price',
          style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, color: kGreen400),
        ),
        if (suffix != null)
          TextSpan(
            text: ' $suffix',
            style: const TextStyle(fontSize: 13, color: kGray400),
          ),
      ]),
    );
  }
}
