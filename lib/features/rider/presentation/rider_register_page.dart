import 'package:flutter/material.dart';

import '../../../features/auth/models/account_role.dart';
import '../../../features/auth/presentation/register_page.dart';

class RiderRegisterPage extends StatelessWidget {
  const RiderRegisterPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const RegisterPage(initialRole: AccountRole.rider);
}
