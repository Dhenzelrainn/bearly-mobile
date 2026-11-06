import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../../notifications/data/mobile_notifications_data_source.dart';
import '../../messaging/data/mobile_messaging_data_source.dart';
import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({
    super.key,
    required this.repository,
    this.notificationsRepository,
    this.messagesRepository,
  });

  final RiderRepository repository;
  final MobileNotificationsDataSource? notificationsRepository;
  final MobileMessagingDataSource? messagesRepository;

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  late Future<RiderDashboard> _dashboard;
  int _notificationUnreadCount = 0;
  Future<int>? _notificationCountRequest;
  int _messageUnreadCount = 0;
  Future<int>? _messageCountRequest;

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

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
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
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BearlyColors.brown900,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Availability: ${dashboard.availabilityStatus.replaceAll('_', ' ')}',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    Text(
                      'Work type: ${_workTypeLabel(dashboard.workType)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      [
                        dashboard.vehicleType,
                        dashboard.vehicleModel,
                        dashboard.plateNumber,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        ] else ...[
          const SizedBox(height: 18),
          const Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(Icons.local_shipping_outlined),
              title: Text('Courier assignments'),
              subtitle: Text(
                'Courier assignment, manifest, scanning, departure, arrival, and handoff actions are not available in Mobile yet. Use your Logistics provider\'s approved Courier Web workflow until Courier Mobile support is ready.',
              ),
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

  String _workTypeLabel(String workType) => switch (workType) {
    'courier' => 'Courier',
    'local' => 'Local Rider',
    _ => 'Unavailable',
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
