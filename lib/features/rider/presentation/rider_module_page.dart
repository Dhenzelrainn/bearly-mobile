import 'package:flutter/material.dart';

import 'rider_account_page.dart';
import 'rider_complete_page.dart';
import 'rider_earnings_page.dart';
import 'rider_history_page.dart';
import 'rider_messages_page.dart';
import 'rider_pickup_page.dart';
import 'rider_requests_page.dart';
import 'rider_transit_page.dart';

enum RiderModule {
  requests,
  pickup,
  transit,
  complete,
  earnings,
  history,
  messages,
  account,
}

/// Route adapter: each Rider module owns its UI in a separate file.
class RiderModulePage extends StatelessWidget {
  const RiderModulePage({super.key, required this.module});

  final RiderModule module;

  @override
  Widget build(BuildContext context) => switch (module) {
    RiderModule.requests => const RiderRequestsPage(),
    RiderModule.pickup => const RiderPickupPage(),
    RiderModule.transit => const RiderTransitPage(),
    RiderModule.complete => const RiderCompletePage(),
    RiderModule.earnings => const RiderEarningsPage(),
    RiderModule.history => const RiderHistoryPage(),
    RiderModule.messages => const RiderMessagesPage(),
    RiderModule.account => const RiderAccountPage(),
  };
}
