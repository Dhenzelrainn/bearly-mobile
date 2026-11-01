import 'dart:async';

import 'package:flutter/material.dart';

import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';
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
  RiderWorkAccess? _access;
  bool _checking = false;
  bool _hasError = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _access = widget.repository.lastKnownWorkAccess;
    _checking =
        widget.repository.hasRiderSession &&
        widget.repository.verifiedWorkAccess == null;
    widget.repository.addSessionListener(_onSessionChanged);
    if (_checking) unawaited(_verifyAccess());
  }

  @override
  void didUpdateWidget(covariant RiderLocalFulfillmentGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeSessionListener(_onSessionChanged);
      widget.repository.addSessionListener(_onSessionChanged);
      _access = widget.repository.lastKnownWorkAccess;
      _checking =
          widget.repository.hasRiderSession &&
          widget.repository.verifiedWorkAccess == null;
      _hasError = false;
      if (_checking) unawaited(_verifyAccess());
    }
  }

  @override
  void dispose() {
    widget.repository.removeSessionListener(_onSessionChanged);
    _requestGeneration++;
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _requestGeneration++;
    setState(() {
      _access = widget.repository.lastKnownWorkAccess;
      _checking =
          widget.repository.hasRiderSession &&
          widget.repository.verifiedWorkAccess == null;
      _hasError = false;
    });
    if (_checking) unawaited(_verifyAccess());
  }

  void _retry() => unawaited(_verifyAccess(forceRefresh: true));

  Future<void> _verifyAccess({bool forceRefresh = false}) async {
    if (!widget.repository.hasRiderSession) {
      if (mounted) {
        setState(() {
          _access = null;
          _checking = false;
          _hasError = false;
        });
      }
      return;
    }

    final cached = widget.repository.verifiedWorkAccess;
    if (!forceRefresh && cached != null) {
      if (mounted) {
        setState(() {
          _access = cached;
          _checking = false;
          _hasError = false;
        });
      }
      return;
    }

    final generation = ++_requestGeneration;
    final accountId = widget.repository.currentAccountId;
    final sessionEpoch = widget.repository.sessionEpoch;
    if (mounted) {
      setState(() {
        // Keep the last known tab layout, while hiding local work controls until
        // this session's capability check has completed.
        _access = widget.repository.lastKnownWorkAccess;
        _checking = true;
        _hasError = false;
      });
    }

    try {
      final access = await widget.repository.workAccess(
        forceRefresh: forceRefresh,
      );
      if (!mounted ||
          generation != _requestGeneration ||
          accountId != widget.repository.currentAccountId ||
          sessionEpoch != widget.repository.sessionEpoch) {
        return;
      }
      setState(() {
        _access = access;
        _checking = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _checking = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifiedAccess = widget.repository.verifiedWorkAccess;
    if (!_checking &&
        !_hasError &&
        verifiedAccess?.supportsLocalFulfillment == true) {
      return widget.child;
    }

    final loading = _checking;
    final isCourier = _access?.workType == 'courier';
    final message = _hasError
        ? 'Could not verify your Rider work type. Retry before opening local assignments.'
        : isCourier
        ? 'Local pickup and delivery assignments are available to Local Riders only.'
        : widget.repository.hasRiderSession
        ? 'The server has not confirmed local Rider access for this account.'
        : 'Sign in with an approved Rider account to access local assignments.';

    return RiderPageScaffold(
      currentRoute: widget.currentRoute,
      title: loading ? 'Checking Rider access' : 'Local work unavailable',
      subtitle: loading
          ? 'Verifying your server-authorized work type.'
          : isCourier
          ? 'This Courier account is not authorized for local Rider fulfillment.'
          : 'Local Rider features stay hidden until access is confirmed.',
      // Keep a previously verified tab layout stable while rechecking, but do
      // not render the protected local screen until fresh access is confirmed.
      supportsLocalFulfillment:
          widget.repository.lastKnownWorkAccess?.supportsLocalFulfillment ==
          true,
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
                  _hasError
                      ? Icons.cloud_off_outlined
                      : Icons.info_outline_rounded,
                ),
                title: Text(message),
                trailing: _hasError
                    ? IconButton(
                        onPressed: _retry,
                        tooltip: 'Retry access check',
                        icon: const Icon(Icons.refresh_rounded),
                      )
                    : null,
              ),
            ),
    );
  }
}
