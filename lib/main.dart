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
      initialRoute: AppRoutes.landing,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}