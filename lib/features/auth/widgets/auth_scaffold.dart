import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.trailing});
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BearlyColors.cream50,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BearlyColors.lineSoft))),
              child: Row(
                children: [
                  BearlyLogo(
                    height: 42,
                    onTap: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.landing, (route) => false),
                  ),
                  const Spacer(),
                  if (trailing != null) Flexible(child: trailing!),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
