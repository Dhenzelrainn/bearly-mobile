import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/bearly_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BearlyApp());
}

class BearlyApp extends StatelessWidget {
  const BearlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bearly',
      debugShowCheckedModeBanner: false,
      theme: BearlyTheme.light(),
      // Laravel redirects `/` to `/login`; the mobile shell follows the same
      // entry point so visitors never land on the marketplace anonymously.
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
