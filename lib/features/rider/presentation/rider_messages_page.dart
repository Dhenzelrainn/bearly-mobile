import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../messaging/data/mobile_messaging_data_source.dart';
import '../../messaging/presentation/mobile_messages_page.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderMessagesPage extends StatelessWidget {
  const RiderMessagesPage({super.key, this.repository});

  final MobileMessagingDataSource? repository;

  @override
  Widget build(BuildContext context) {
    final source = repository;
    if (source == null) {
      return RiderPageScaffold(
        currentRoute: AppRouteNames.riderMessages,
        showBottomNavigationBar: false,
        title: 'Messages',
        subtitle: 'Messages are unavailable in this session.',
        child: const Card(
          color: Colors.white,
          child: ListTile(
            leading: Icon(Icons.chat_bubble_outline_rounded),
            title: Text('Messages could not be opened'),
            subtitle: Text('Return to the Rider dashboard and try again.'),
          ),
        ),
      );
    }

    return MobileMessagesPage(repository: source, title: 'Messages');
  }
}
