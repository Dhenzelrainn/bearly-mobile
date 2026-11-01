import 'package:flutter/material.dart';

import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';
import '../models/rider_account.dart';
import 'rider_assignment_pages.dart';
import 'rider_account_page.dart';
import 'rider_earnings_page.dart';
import 'rider_history_page.dart';
import 'rider_messages_page.dart';
import '../widgets/rider_shared_widgets.dart';

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
      RiderModule.earnings => RiderEarningsPage(repository: repository),
      RiderModule.history => RiderHistoryPage(repository: repository),
      RiderModule.messages => const RiderMessagesPage(),
      RiderModule.account => RiderAccountPage(repository: repository),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Prevents Courier profiles from opening local pickup/delivery screens,
/// including when a route is opened directly instead of through navigation.
/// The Mobile API remains the authorization boundary; this gate keeps local
/// Rider actions out of the Courier UI as well.
class RiderLocalFulfillmentGuard extends StatefulWidget {
  const RiderLocalFulfillmentGuard({
    super.key,
    required this.repository,
    required this.currentRoute,
    required this.child,
  });

  final RiderRepository repository;
  final String? currentRoute;
  final Widget child;

  @override
  State<RiderLocalFulfillmentGuard> createState() =>
      _RiderLocalFulfillmentGuardState();
}

class _RiderLocalFulfillmentGuardState
    extends State<RiderLocalFulfillmentGuard> {
  late Future<RiderAccount> _account;

  @override
  void initState() {
    super.initState();
    _account = widget.repository.account();
  }

  void _retry() => setState(() => _account = widget.repository.account());

  @override
  Widget build(BuildContext context) => FutureBuilder<RiderAccount>(
    future: _account,
    builder: (context, snapshot) {
      if (snapshot.data?.supportsLocalFulfillment == true) {
        return widget.child;
      }

      final loading = snapshot.connectionState == ConnectionState.waiting;
      final isCourier = snapshot.data?.workType == 'courier';
      final message = snapshot.hasError
          ? 'Could not verify your Rider work type. Retry before opening local assignments.'
          : isCourier
          ? 'Local pickup and delivery assignments are available to Local Riders only.'
          : 'The server has not confirmed local Rider access for this account.';

      return RiderPageScaffold(
        currentRoute: widget.currentRoute,
        title: loading ? 'Checking Rider access' : 'Local work unavailable',
        subtitle: loading
            ? 'Verifying your server-authorized work type.'
            : isCourier
            ? 'This Courier account is not authorized for local Rider fulfillment.'
            : 'Local Rider features stay hidden until access is confirmed.',
        supportsLocalFulfillment: false,
        child: loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(
                    snapshot.hasError
                        ? Icons.cloud_off_outlined
                        : Icons.info_outline_rounded,
                  ),
                  title: Text(message),
                  trailing: snapshot.hasError
                      ? IconButton(
                          onPressed: _retry,
                          tooltip: 'Retry access check',
                          icon: const Icon(Icons.refresh_rounded),
                        )
                      : null,
                ),
              ),
      );
    },
  );
}
