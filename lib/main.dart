import 'package:flutter/material.dart';

import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/session_startup_page.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/bearly_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BearlyApp());
}

class BearlyApp extends StatelessWidget {
  BearlyApp({super.key, AuthService? authService})
    : authService = authService ?? AuthService();

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bearly',
      debugShowCheckedModeBanner: false,
      theme: BearlyTheme.light(),
      home: SessionStartupPage(authService: authService),
      onGenerateRoute: (settings) =>
          AppRoutes.onGenerateRoute(settings, authService: authService),
    );
  }
}
