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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Login form is ready. Laravel mobile API connection is the next auth step.',
        ),
      ),
    );
  }

  void _googleSignIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Google sign-in UI is ready. Mobile OAuth will be connected with the Laravel auth API.',
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
        padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BearlyColors.cream200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: BearlyColors.brown900,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back to Bearly',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 36,
                        ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Sign in to continue shopping or delivering with Bearly.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: BearlyColors.muted,
                        ),
                  ),
                  const SizedBox(height: 30),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            hintText: 'you@example.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Enter your email address.';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(text)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Enter your password.'
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Checkbox(
                              value: _remember,
                              activeColor: BearlyColors.brown900,
                              onChanged: (value) => setState(
                                () => _remember = value ?? false,
                              ),
                            ),
                            const Text('Remember me'),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.forgotPassword,
                              ),
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _submit,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Sign In'),
                        ),
                        const SizedBox(height: 22),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 22),
                        OutlinedButton.icon(
                          onPressed: _googleSignIn,
                          icon: Image.asset(
                            'assets/images/auth/google-icon.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 24,
                            ),
                          ),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('New to Bearly?'),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.register,
                              ),
                              child: const Text('Create an account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BearlyColors.cream100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BearlyColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: BearlyColors.brown900,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'One login for Buyer and Rider accounts. Access is based on your approved role.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
