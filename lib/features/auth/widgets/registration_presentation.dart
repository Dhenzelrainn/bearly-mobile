import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';

class RegistrationStepHeading extends StatelessWidget {
  const RegistrationStepHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
        ),
      ],
    );
  }
}

class RegistrationInfoCallout extends StatelessWidget {
  const RegistrationInfoCallout({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BearlyColors.cream100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BearlyColors.lineSoft),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$title ',
              style: const TextStyle(
                color: BearlyColors.brown900,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}
