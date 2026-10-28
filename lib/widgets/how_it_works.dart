import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/business_info.dart';

class HowItWorksSteps extends StatelessWidget {
  const HowItWorksSteps({super.key});

  static const steps = [
    ('Pick a service & car size', 'See the exact price before you book.'),
    ('Choose a date and time', '$kHoursLabel, $kDaysLabel.'),
    (
      'Send the booking on WhatsApp',
      'We confirm your slot within $kConfirmWithin.'
    ),
    (
      'We clean your car at your door',
      'Pay the team once you\'re happy with the result.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.ink, shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style:
                        AppText.smallStrong.copyWith(color: AppColors.brand)),
              ),
              if (i < steps.length - 1)
                Expanded(child: Container(width: 2, color: AppColors.border)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    top: 4, bottom: i < steps.length - 1 ? 20 : 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$1, style: AppText.bodyStrong),
                      const SizedBox(height: 2),
                      Text(steps[i].$2, style: AppText.small),
                    ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
