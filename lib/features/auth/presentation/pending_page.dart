import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/registration_repository.dart';
import '../widgets/auth_scaffold.dart';

class PendingPage extends StatelessWidget {
  const PendingPage({super.key, this.roleLabel, this.outcome});

  final String? roleLabel;
  final RegistrationOutcome? outcome;

  String get _status => outcome?.status ?? 'pending';
  bool get _isActive => _status == 'active';
  bool get _isRejected => _status == 'rejected';
  bool get _isRider =>
      outcome?.role == 'rider' || (roleLabel ?? '').toLowerCase() == 'rider';
  bool get _isCourier => _isRider && outcome?.workType == 'courier';
  String get _accountLabel => outcome?.role == 'buyer'
      ? 'Buyer'
      : outcome?.role == 'logistics'
      ? 'Logistics'
      : _isCourier
      ? 'Courier (Rider account)'
      : roleLabel ?? 'Rider';
  String get _authority => _isActive && outcome?.role == 'buyer'
      ? 'Email verification'
      : outcome?.reviewAuthority ??
            (_isRider
                ? 'Selected Logistics / Sorting Center'
                : 'Bearly Administrator');

  String get _description {
    if (_isActive) {
      return outcome?.role == 'buyer'
          ? 'Your email is verified and your Buyer account is active. Sign in to start using Bearly Mobile.'
          : 'Your application was approved. Sign in to start using Bearly Mobile.';
    }
    if (_isRejected) {
      return outcome?.message.isNotEmpty == true
          ? outcome!.message
          : 'Bearly recorded that this application was not approved.';
    }
    if (_isRider) {
      return _isCourier
          ? 'Your Courier application remains a Rider account. $_authority reviews its documents before access is approved.'
          : 'Your Rider application remains locked until $_authority reviews your credentials.';
    }
    return 'Your Logistics application is pending Bearly Administrator review. Operational access is available only after approval.';
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: BearlyColors.cream200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRejected
                            ? Icons.cancel_outlined
                            : _isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.schedule_send_outlined,
                        color: BearlyColors.brown900,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isActive
                        ? outcome?.role == 'buyer'
                              ? 'Buyer account activated'
                              : 'Application approved'
                        : _isRejected
                        ? 'Application not approved'
                        : 'Application received',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _description,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: BearlyColors.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'Account type', value: _accountLabel),
                        _DetailRow(label: 'Status', value: _statusLabel),
                        _DetailRow(
                          label: _isActive
                              ? 'Verification'
                              : 'Review authority',
                          value: _authority,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: BearlyColors.cream100,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: BearlyColors.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isActive
                              ? 'You are ready'
                              : _isRejected
                              ? 'Application decision'
                              : 'What happens next?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        if (_isActive) ...[
                          _TimelineItem(
                            number: '✓',
                            title: outcome?.role == 'buyer'
                                ? 'Email verified'
                                : 'Application approved',
                            body: outcome?.role == 'buyer'
                                ? 'Laravel activated your Buyer account after successful email verification.'
                                : 'Your application was approved by $_authority.',
                            complete: true,
                          ),
                          const _TimelineItem(
                            number: '2',
                            title: 'Sign in to Bearly Mobile',
                            body:
                                'Use the email and password you just registered.',
                            last: true,
                          ),
                        ] else if (_isRejected) ...[
                          const _TimelineItem(
                            number: '✓',
                            title: 'Application submitted',
                            body:
                                'Your registration and required documents were received.',
                            complete: true,
                          ),
                          _TimelineItem(
                            number: '×',
                            title: 'Application not approved',
                            body: outcome?.message.isNotEmpty == true
                                ? outcome!.message
                                : 'Bearly recorded that this application was not approved.',
                            last: true,
                          ),
                        ] else ...[
                          const _TimelineItem(
                            number: '✓',
                            title: 'Application submitted',
                            body:
                                'Your verified registration details and required documents were sent securely to Bearly.',
                            complete: true,
                          ),
                          _TimelineItem(
                            number: '2',
                            title: _isRider
                                ? 'Logistics review'
                                : 'Admin review',
                            body: _isRider
                                ? '$_authority checks your Rider application and documents.'
                                : 'A Bearly Administrator checks your business details and documents.',
                          ),
                          const _TimelineItem(
                            number: '3',
                            title: 'Decision',
                            body:
                                'Sign in after your application is approved and activated.',
                            last: true,
                          ),
                        ],
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
                            _isActive
                                ? 'Your Buyer account is active now. Sign in with the credentials you just created.'
                                : _isRejected
                                ? 'Review the decision details provided above before taking another step.'
                                : 'You can sign in once your application is approved. Do not submit another application while it is under review.',
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
                      AppRouteNames.login,
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
                      AppRouteNames.login,
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

  String get _statusLabel => switch (_status) {
    'active' => 'Active',
    'pending' => 'Pending review',
    'rejected' => 'Rejected',
    _ => _status,
  };
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
              Container(width: 1, height: 54, color: BearlyColors.line),
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
