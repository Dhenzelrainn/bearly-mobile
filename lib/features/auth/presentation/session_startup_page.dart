import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../data/auth_service.dart';
import '../models/account_role.dart';
import 'login_page.dart';

class SessionStartupPage extends StatefulWidget {
  const SessionStartupPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SessionStartupPage> createState() => _SessionStartupPageState();
}

class _SessionStartupPageState extends State<SessionStartupPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.authService.restoreSession();
      if (!mounted) return;
      if (session != null) {
        final route = session.role == AccountRole.buyer
            ? AppRouteNames.buyer
            : AppRouteNames.rider;
        Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Bearly could not verify your saved session. Check your connection and retry.';
      });
      return;
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) {
      return LoginPage(authService: widget.authService);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    _loading
                        ? 'Checking your Bearly session…'
                        : 'Session check paused',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 10),
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _restoreSession,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRouteNames.login),
                      child: const Text('Sign in with another account'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
