import 'package:flutter/material.dart';

import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';
import 'rider_assignment_pages.dart';
import 'rider_account_page.dart';
import 'rider_earnings_page.dart';
import 'rider_history_page.dart';
import 'rider_messages_page.dart';

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
  const RiderModulePage({
    super.key,
    required this.module,
    required this.repository,
  });

  final RiderModule module;
  final RiderRepository repository;

  @override
  Widget build(BuildContext context) {
    final kind = switch (module) {
      RiderModule.requests || RiderModule.pickup => RiderAssignmentKind.pickup,
      RiderModule.transit ||
      RiderModule.complete => RiderAssignmentKind.delivery,
      _ => null,
    };

    if (kind != null) {
      return RiderAssignmentListPage(repository: repository, kind: kind);
    }

    return switch (module) {
      RiderModule.earnings => const RiderEarningsPage(),
      RiderModule.history => RiderHistoryPage(repository: repository),
      RiderModule.messages => const RiderMessagesPage(),
      RiderModule.account => RiderAccountPage(repository: repository),
      _ => const SizedBox.shrink(),
    };
  }
}
