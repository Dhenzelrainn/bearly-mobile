import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';

class BuyerAccountPage extends StatelessWidget {
  const BuyerAccountPage({
    super.key,
    required this.onLogout,
    required this.onMessage,
    required this.onManageAddresses,
  });

  final VoidCallback onLogout;
  final ValueChanged<String> onMessage;
  final VoidCallback onManageAddresses;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      Text('Buyer account', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 14),
      Card(
        color: Colors.white,
        child: const ListTile(
          contentPadding: EdgeInsets.all(12),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: BearlyColors.cream200,
            child: Icon(Icons.person_rounded, color: BearlyColors.brown700),
          ),
          title: Text('Buyer account'),
          subtitle: Text('Manage your profile, addresses, and payments.'),
        ),
      ),
      const SizedBox(height: 14),
      _action(
        Icons.location_on_outlined,
        'Delivery addresses',
        'Home and saved drop-off locations',
        onTap: onManageAddresses,
      ),
      _action(
        Icons.credit_card_outlined,
        'Payment methods',
        'Manage your preferred payment option',
      ),
      _action(
        Icons.support_agent_rounded,
        'Help and support',
        'Get help with an order',
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
      ),
    ],
  );

  Widget _action(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) => Card(
    color: Colors.white,
    child: ListTile(
      leading: Icon(icon, color: BearlyColors.brown700),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap ?? () => onMessage('$title will be connected to Laravel.'),
    ),
  );
}
