import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderMessagesPage extends StatelessWidget {
  const RiderMessagesPage({super.key});

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    currentRoute: AppRouteNames.riderMessages,
    showBottomNavigationBar: false,
    title: 'Chat / Messaging',
    subtitle: 'Rider messaging is not connected to the mobile API yet.',
    child: const Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(Icons.chat_bubble_outline_rounded),
        title: Text('Messages unavailable in this version'),
        subtitle: Text(
          'Messaging information will appear here when available.',
        ),
      ),
    ),
  );
}
