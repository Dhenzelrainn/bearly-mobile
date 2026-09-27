import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      trailing: TextButton(
        onPressed: () => Navigator.pushReplacementNamed(
          context,
          AppRoutes.login,
        ),
        child: const Text('Sign in'),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: BearlyColors.brown900,
                    size: 42,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Reset your password',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Enter your Bearly email. If an account exists, we’ll send password reset instructions.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BearlyColors.muted,
                        ),
                  ),
                  const SizedBox(height: 28),
                  if (_sent)
                    Container(
                      padding: const EdgeInsets.all(15),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: BearlyColors.cream100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BearlyColors.lineSoft),
                      ),
                      child: Text(
                        'If a Bearly account exists for that email, a password reset link will be sent once the mobile auth API is connected.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Enter your email address.';
                            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(text)
                                ? null
                                : 'Enter a valid email address.';
                          },
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _submit,
                          child: const Text('Send reset link'),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.login,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back to Sign In'),
                        ),
                      ],
                    ),
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
