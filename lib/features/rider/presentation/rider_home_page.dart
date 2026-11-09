import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../../notifications/data/mobile_notifications_data_source.dart';
import '../../messaging/data/mobile_messaging_data_source.dart';
import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';
import '../models/rider_operational_status.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({
    super.key,
    required this.repository,
    this.notificationsRepository,
    this.messagesRepository,
    this.onOpenLiveLocation,
    this.onOpenCashCustody,
    this.onOpenCourierRuns,
  });

  final RiderRepository repository;
  final MobileNotificationsDataSource? notificationsRepository;
  final MobileMessagingDataSource? messagesRepository;
  final Future<void> Function()? onOpenLiveLocation;
  final Future<void> Function()? onOpenCashCustody;
  final Future<void> Function()? onOpenCourierRuns;

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  late Future<RiderDashboard> _dashboard;
  int _notificationUnreadCount = 0;
  Future<int>? _notificationCountRequest;
  int _messageUnreadCount = 0;
  Future<int>? _messageCountRequest;
  bool _availabilityUpdating = false;

  @override
  void initState() {
    super.initState();
    _dashboard = widget.repository.dashboard();
    unawaited(_refreshNotificationCount());
    unawaited(_refreshMessageCount());
  }

  void _refresh() {
    final dashboard = widget.repository.dashboard();
    setState(() {
      _dashboard = dashboard;
    });
  }

  Future<void> _changeAvailability(String target) async {
    if (_availabilityUpdating) return;
    setState(() => _availabilityUpdating = true);
    try {
      final status = await widget.repository.updateAvailability(target);
      final dashboard = await _dashboard;
      if (!mounted) return;
      setState(() {
        _dashboard = Future.value(
          dashboard.copyWith(operationalStatus: status),
        );
      });
      _showStatusMessage(
        target == 'available'
            ? 'You are online and may receive eligible assignments.'
            : 'You are offline. Existing work remains assigned to you.',
      );
    } catch (error) {
      if (mounted) _showStatusMessage(_statusError(error));
    } finally {
      if (mounted) setState(() => _availabilityUpdating = false);
    }
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusError(Object error) {
    if (error is ApiHttpException && error.responseData is Map) {
      final response = Map<String, Object?>.from(error.responseData as Map);
      final message = response['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      final errors = response['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty && value.first is String) {
            return value.first as String;
          }
          if (value is String && value.isNotEmpty) return value;
        }
      }
    }
    return 'Could not update your status. Please retry.';
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) _refresh();
  }

  Future<void> _openCourierRuns() async {
    await widget.onOpenCourierRuns?.call();
    if (mounted) _refresh();
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(
      context,
      AppRouteNames.riderNotifications,
      arguments: _notificationUnreadCount,
    );
    if (!mounted) return;
    _refresh();
    await _refreshNotificationCount(force: true);
  }

  Future<void> _openMessages() async {
    await Navigator.pushNamed(context, AppRouteNames.riderMessages);
    if (!mounted) return;
    _refresh();
    await _refreshMessageCount(force: true);
  }

  Future<void> _refreshNotificationCount({bool force = false}) async {
    final notifications = widget.notificationsRepository;
    if (notifications == null) return;

    final pending = _notificationCountRequest;
    if (pending != null) {
      await pending.catchError((_) => _notificationUnreadCount);
      if (!force) return;
    }

    final request = notifications.getUnreadCount();
    _notificationCountRequest = request;
    try {
      final count = await request;
      if (mounted) setState(() => _notificationUnreadCount = count);
    } catch (_) {
      // Keep the dashboard usable if notifications are temporarily offline.
    } finally {
      if (identical(_notificationCountRequest, request)) {
        _notificationCountRequest = null;
      }
    }
  }

  Future<void> _refreshMessageCount({bool force = false}) async {
    final messages = widget.messagesRepository;
    if (messages == null) return;

    final pending = _messageCountRequest;
    if (pending != null) {
      await pending.catchError((_) => _messageUnreadCount);
      if (!force) return;
    }

    final request = messages.getUnreadCount();
    _messageCountRequest = request;
    try {
      final count = await request;
      if (mounted) setState(() => _messageUnreadCount = count);
    } catch (_) {
      // Keep the dashboard available while messaging is offline.
    } finally {
      if (identical(_messageCountRequest, request)) _messageCountRequest = null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RiderDashboard>(
    future: _dashboard,
    builder: (context, snapshot) {
      final dashboard = snapshot.data;
      final supportsLocalFulfillment =
          dashboard?.supportsLocalFulfillment == true;

      return Scaffold(
        appBar: AppBar(
          title: const BearlyLogo(height: 34, width: 102),
          actions: [
            if (widget.notificationsRepository != null)
              IconButton(
                onPressed: _openNotifications,
                tooltip: 'Notifications',
                icon: Badge(
                  isLabelVisible: _notificationUnreadCount > 0,
                  label: Text(
                    _notificationUnreadCount > 99
                        ? '99+'
                        : '$_notificationUnreadCount',
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh dashboard',
              icon: const Icon(Icons.refresh_rounded),
            ),
            RiderSecondaryMenuButton(
              currentRoute: AppRouteNames.rider,
              showDeliveryHistory: supportsLocalFulfillment,
            ),
          ],
        ),
        body: _dashboardContent(snapshot),
        bottomNavigationBar: dashboard != null
            ? RiderBottomNavigationBar(
                currentRoute: AppRouteNames.rider,
                onNavigate: _open,
                supportsLocalFulfillment: supportsLocalFulfillment,
              )
            : null,
      );
    },
  );

  Widget _dashboardContent(AsyncSnapshot<RiderDashboard> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 10),
              const Text(
                'Could not load your Rider dashboard. Check your connection and retry.',
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final dashboard = snapshot.data;
    if (dashboard == null) {
      return const Center(child: Text('Rider dashboard is unavailable.'));
    }
    return _dashboardBody(dashboard);
  }

  Widget _dashboardBody(RiderDashboard dashboard) => RefreshIndicator(
    onRefresh: () async => _refresh(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Welcome, ${dashboard.name}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        Text(
          'Your assigned Bearly work at a glance.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
        ),
        const SizedBox(height: 14),
        if (widget.onOpenLiveLocation != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Live GPS & Map'),
              subtitle: const Text(
                'Share your location with your assigned Logistics provider and view verified destinations.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenLiveLocation,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BearlyColors.brown900,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    dashboard.availabilityStatus == 'available'
                        ? Icons.wifi_tethering_rounded
                        : Icons.wifi_tethering_off_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dashboard.availabilityStatus == 'available'
                              ? 'Online'
                              : 'Offline',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        Text(
                          'Work type: ${_workTypeLabel(dashboard.workType)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (dashboard.operationalStatus case final operational?) ...[
                const SizedBox(height: 10),
                _availabilityControls(operational),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          [
            dashboard.vehicleType,
            dashboard.vehicleModel,
            dashboard.plateNumber,
          ].where((value) => value.isNotEmpty).join(' · '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
        ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('Logistics provider'),
                subtitle: Text(
                  dashboard.logisticsProvider.isEmpty
                      ? 'Not assigned'
                      : dashboard.logisticsProvider,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.warehouse_outlined),
                title: const Text('Home sorting center'),
                subtitle: Text(
                  dashboard.homeSortingCenter.isEmpty
                      ? 'Not assigned'
                      : dashboard.homeSortingCenter,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Current zone'),
                subtitle: Text(
                  dashboard.currentZone.isEmpty
                      ? 'Not assigned'
                      : [
                          dashboard.currentZone,
                          dashboard.currentZoneCenter,
                        ].where((value) => value.isNotEmpty).join(' · '),
                ),
              ),
            ],
          ),
        ),
        if (dashboard.supportsLocalFulfillment) ...[
          if (widget.onOpenCashCustody != null) ...[
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Cash Custody'),
                subtitle: const Text(
                  'View recorded COD collections and refund cash assignments.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onOpenCashCustody,
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _stat(
                  '${dashboard.assignedPickups}',
                  'Assigned pickups',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  '${dashboard.assignedDeliveries}',
                  'Assigned deliveries',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _section(
            title: 'Pickup assignments',
            count: dashboard.assignedPickups,
            route: AppRouteNames.riderRequests,
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Delivery assignments',
            count: dashboard.assignedDeliveries,
            route: AppRouteNames.riderTransit,
          ),
          if (dashboard.assignedPickups == 0 &&
              dashboard.assignedDeliveries == 0) ...[
            const SizedBox(height: 14),
            const Card(
              child: ListTile(
                leading: Icon(Icons.inbox_outlined),
                title: Text('No assigned jobs right now'),
                subtitle: Text(
                  'New assignments from Logistics will appear here.',
                ),
              ),
            ),
          ],
        ] else if (dashboard.workType == 'courier') ...[
          const SizedBox(height: 18),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Courier Runs'),
              subtitle: const Text(
                'View assigned line-haul manifests, run progress and next steps.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenCourierRuns == null ? null : _openCourierRuns,
            ),
          ),
        ],
        if (widget.messagesRepository != null) ...[
          const SizedBox(height: 14),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Messages'),
              subtitle: const Text('Contact Bearly Support or Logistics.'),
              trailing: _messageUnreadCount > 0
                  ? Badge(
                      label: Text(
                        _messageUnreadCount > 99
                            ? '99+'
                            : '$_messageUnreadCount',
                      ),
                      child: const Icon(Icons.mark_chat_unread_rounded),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _openMessages,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _section({
    required String title,
    required int count,
    required String route,
  }) => Card(
    color: Colors.white,
    child: ListTile(
      leading: const Icon(Icons.local_shipping_outlined),
      title: Text(title),
      subtitle: Text('$count assigned'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _open(route),
    ),
  );

  Widget _availabilityControls(RiderOperationalStatus status) {
    final activeWorkLabel = status.workType == 'courier'
        ? '${status.activeCourierRuns} active line-haul runs'
              '${status.activeCourierRunsInProgress > 0 ? ' · ${status.activeCourierRunsInProgress} in progress' : ''}'
        : '${status.activePickups} pickups · ${status.activeDeliveries} deliveries'
              '${status.activePickupsInProgress + status.activeDeliveriesInProgress > 0 ? ' · ${status.activePickupsInProgress + status.activeDeliveriesInProgress} in progress' : ''}';
    final checkedInAt = status.checkedInAt?.toLocal();
    final checkedInTime = checkedInAt == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(checkedInAt));
    final checkedInDate = checkedInAt == null
        ? null
        : '${checkedInAt.month}/${checkedInAt.day}/${checkedInAt.year}';
    final isOnline = status.availabilityStatus == 'available';
    final changing = _availabilityUpdating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status.activeWorkCount == 0
              ? 'No active assignments'
              : '${_operationalStateLabel(status.operationalState)}: $activeWorkLabel',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 3),
        Text(
          status.availabilityNote,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 3),
        Text(
          status.assignmentRulesNote,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (isOnline && status.canGoOffline)
              OutlinedButton.icon(
                onPressed: changing
                    ? null
                    : () => _changeAvailability('offline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: _availabilityUpdating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering_off_rounded),
                label: const Text('Go Offline'),
              )
            else if (!isOnline && status.canGoOnline)
              FilledButton.icon(
                onPressed: changing
                    ? null
                    : () => _changeAvailability('available'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: BearlyColors.brown900,
                ),
                icon: _availabilityUpdating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded),
                label: const Text('Go Online'),
              ),
            OutlinedButton.icon(
              onPressed: changing
                  ? null
                  : () => _open(AppRouteNames.riderAttendanceScan),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan attendance QR'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          status.hasActiveShift
              ? 'Shift started ${checkedInDate ?? ''} at ${checkedInTime ?? ''}'
              : 'No active shift',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          status.shiftNote,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  String _workTypeLabel(String workType) => switch (workType) {
    'courier' => 'Courier',
    'local' => 'Local Rider',
    _ => 'Unavailable',
  };

  String _operationalStateLabel(String value) => switch (value) {
    'in_progress' => 'In progress',
    'assigned' => 'Assigned',
    'available' => 'Online',
    'offline' => 'Offline',
    _ => 'Work status',
  };

  Widget _stat(String value, String label) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BearlyColors.cream100,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: BearlyColors.lineSoft),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: BearlyColors.brown700),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
