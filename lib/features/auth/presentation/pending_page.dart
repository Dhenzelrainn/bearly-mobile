import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../widgets/auth_scaffold.dart';

class PendingPage extends StatelessWidget {
  const PendingPage({super.key, this.roleLabel});

  final String? roleLabel;

  bool get _isRider => (roleLabel ?? '').toLowerCase() == 'rider';

  @override
  Widget build(BuildContext context) {
    final authority = _isRider
        ? 'Selected Logistics / Sorting Center'
        : 'Bearly Administrator';

    return AuthScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: BearlyColors.cream200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.schedule_send_outlined,
                        color: BearlyColors.brown900,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Application received',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRider
                        ? 'Your Rider account remains locked until your selected Logistics / Sorting Center reviews your credentials.'
                        : 'Your Buyer application remains pending until a Bearly administrator reviews your details and ID.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BearlyColors.muted,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: BearlyColors.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'Account type', value: roleLabel ?? 'Bearly'),
                        _DetailRow(label: 'Status', value: 'Pending review'),
                        _DetailRow(label: 'Review authority', value: authority),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: BearlyColors.cream100,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: BearlyColors.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What happens next?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        const _TimelineItem(
                          number: '✓',
                          title: 'Application prepared',
                          body: 'Your registration details and required documents are ready for review.',
                          complete: true,
                        ),
                        _TimelineItem(
                          number: '2',
                          title: _isRider ? 'Logistics review' : 'Admin review',
                          body: _isRider
                              ? 'Your selected Logistics / Sorting Center checks your identity, vehicle, OR/CR, and license or valid ID.'
                              : 'A Bearly administrator checks your application details and valid government ID.',
                        ),
                        const _TimelineItem(
                          number: '3',
                          title: 'Decision',
                          body: 'You can sign in after your account is approved and activated.',
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BearlyColors.cream50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BearlyColors.lineSoft),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: BearlyColors.brown700,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'You can sign in once your application is approved. You do not need to submit another application while it is under review.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Return to Sign In'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.landing,
                      (route) => false,
                    ),
                    child: const Text('Back to Bearly'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BearlyColors.text,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.number,
    required this.title,
    required this.body,
    this.complete = false,
    this.last = false,
  });

  final String number;
  final String title;
  final String body;
  final bool complete;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: complete ? BearlyColors.success : BearlyColors.cream300,
              ),
              child: Text(
                number,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: complete ? Colors.white : BearlyColors.brown900,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (!last)
              Container(
                width: 1,
                height: 54,
                color: BearlyColors.line,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
