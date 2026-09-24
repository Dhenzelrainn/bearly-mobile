import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../widgets/auth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _remember = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Login UI is working. Laravel authentication API will be connected in the backend integration part.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      trailing: TextButton.icon(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.landing,
          (route) => false,
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back to shop'),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Text(
                    'Welcome back to Bearly',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 38),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'One secure sign-in for shopping, selling, and delivering.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: BearlyColors.muted),
                  ),
                  const SizedBox(height: 34),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Enter your email address.';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'Hide password' : 'Show password',
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(
                                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value ?? '').isEmpty ? 'Enter your password.' : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _remember,
                              onChanged: (value) => setState(() => _remember = value ?? false),
                              activeColor: BearlyColors.brown900,
                            ),
                            const Text('Remember me'),
                            const Spacer(),
                            TextButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Forgot-password backend flow is not connected in the current Laravel branch yet.',
                                  ),
                                ),
                              ),
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(onPressed: _submit, child: const Text('Sign In')),
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Google sign-in is ready for OAuth integration later.')),
                            ),
                            icon: Image.asset(
                              'assets/images/auth/google-icon.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, size: 24),
                            ),
                            label: const Text('Continue with Google'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('New to Bearly?'),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                              child: const Text('Create an account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Image.asset(
                    'assets/images/auth/bearly-auth-scene.png',
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BearlyColors.cream100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BearlyColors.lineSoft),
                      ),
                      child: const Icon(Icons.local_mall_outlined, size: 54, color: BearlyColors.brown500),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _TrustRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.person_outline_rounded, 'One account'),
      (Icons.account_tree_outlined, 'Role-aware access'),
      (Icons.shield_outlined, 'Secure sign-in'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: BearlyColors.lineSoft),
          bottom: BorderSide(color: BearlyColors.lineSoft),
        ),
      ),
      child: Row(
        children: items.map((item) => Expanded(
          child: Column(
            children: [
              Icon(item.$1, color: BearlyColors.brown900),
              const SizedBox(height: 8),
              Text(
                item.$2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
