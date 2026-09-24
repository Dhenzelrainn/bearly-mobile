import 'package:flutter/material.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/pending_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/landing/presentation/landing_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const landing = '/';
  static const login = '/login';
  static const register = '/register';
  static const pending = '/application/pending';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case landing:
        return MaterialPageRoute(builder: (_) => const LandingPage(), settings: settings);
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage(), settings: settings);
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage(), settings: settings);
      case pending:
        return MaterialPageRoute(
          builder: (_) => PendingPage(roleLabel: settings.arguments as String?),
          settings: settings,
        );
      default:
        return MaterialPageRoute(builder: (_) => const LandingPage(), settings: settings);
    }
  }
}
