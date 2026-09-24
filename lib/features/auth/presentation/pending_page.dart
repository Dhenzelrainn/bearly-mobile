import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../widgets/auth_scaffold.dart';

class PendingPage extends StatelessWidget {
  const PendingPage({super.key, this.roleLabel});
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: const BoxDecoration(color: BearlyColors.cream200, shape: BoxShape.circle),
                  child: const Icon(Icons.schedule_send_outlined, color: BearlyColors.brown900, size: 42),
                ),
                const SizedBox(height: 22),
                Text(
                  'Application preview complete',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your ${roleLabel ?? 'Bearly'} registration flow reached the review stage. The current bearly-fusion-clean branch does not save registration data yet, so nothing was submitted to the database.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false),
                    child: const Text('Go to Sign In'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.landing, (route) => false),
                  child: const Text('Back to Bearly'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
