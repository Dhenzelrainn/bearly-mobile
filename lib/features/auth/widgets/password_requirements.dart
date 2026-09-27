import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({
    super.key,
    required this.password,
    required this.confirmPassword,
  });

  final String password;
  final String confirmPassword;

  bool get hasLength => password.length >= 8;
  bool get hasUppercase => RegExp(r'[A-Z]').hasMatch(password);
  bool get hasLowercase => RegExp(r'[a-z]').hasMatch(password);
  bool get hasNumber => RegExp(r'\d').hasMatch(password);
  bool get allMet => hasLength && hasUppercase && hasLowercase && hasNumber;

  @override
  Widget build(BuildContext context) {
    final completed = [hasLength, hasUppercase, hasLowercase, hasNumber]
        .where((item) => item)
        .length;
    final strength = switch (completed) {
      0 => 'Not set',
      1 => 'Weak',
      2 => 'Fair',
      3 => 'Good',
      _ => 'Strong',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BearlyColors.cream100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BearlyColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Password requirements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                strength,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: allMet ? BearlyColors.success : BearlyColors.brown700,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: completed / 4,
              minHeight: 6,
              backgroundColor: BearlyColors.cream300,
              color: allMet ? BearlyColors.success : BearlyColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          _Rule(ok: hasLength, label: 'At least 8 characters'),
          _Rule(ok: hasUppercase, label: 'At least 1 uppercase letter'),
          _Rule(ok: hasLowercase, label: 'At least 1 lowercase letter'),
          _Rule(ok: hasNumber, label: 'At least 1 number'),
          if (confirmPassword.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  confirmPassword == password
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: confirmPassword == password
                      ? BearlyColors.success
                      : BearlyColors.error,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    confirmPassword == password
                        ? 'Passwords match.'
                        : 'Passwords do not match yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: confirmPassword == password
                              ? BearlyColors.success
                              : BearlyColors.error,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 17,
            color: ok ? BearlyColors.success : BearlyColors.muted,
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
