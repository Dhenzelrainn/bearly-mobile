import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../data/auth_service.dart';

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  @override
  void initState() {
    super.initState();
    _logout();
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouteNames.login,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Signing out…'),
        ],
      ),
    ),
  );
}
