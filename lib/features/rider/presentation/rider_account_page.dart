import 'package:flutter/material.dart';

import 'rider_shared.dart';

class RiderAccountPage extends StatelessWidget {
  const RiderAccountPage({super.key});

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: 'Rider Account',
    module: 'MODULE 10',
    subtitle: 'Manage your profile, vehicle, documents, and base areas.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: const ListTile(
            contentPadding: EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 24,
              child: Icon(Icons.delivery_dining_rounded),
            ),
            title: Text('Adrian Cruz'),
            subtitle: Text('adrian.courier@bearly.test'),
          ),
        ),
        const SizedBox(height: 12),
        _info(
          context,
          'Vehicle',
          'Motorcycle • Honda Click 160\nPlate NCR 4821',
          Icons.two_wheeler_outlined,
        ),
        _info(
          context,
          'Documents',
          'OR / CR verified • Driver license verified',
          Icons.verified_user_outlined,
        ),
        _info(
          context,
          'Base locations',
          'Cubao, Quezon City\nMandaluyong City on weekends',
          Icons.location_on_outlined,
        ),
        _info(
          context,
          'Preferences',
          'Notifications, availability, and support',
          Icons.tune_rounded,
        ),
      ],
    ),
  );

  Widget _info(
    BuildContext context,
    String title,
    String body,
    IconData icon,
  ) => Card(
    color: Colors.white,
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () =>
          riderMessage(context, '$title will be connected to Laravel.'),
    ),
  );
}
