import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../../auth/data/auth_service.dart';
import '../../notifications/data/mobile_notifications_data_source.dart';
import '../data/logistics_repository.dart';
import '../data/logistics_messages_repository.dart';
import '../models/logistics_dashboard.dart';
import 'logistics_dispatch_page.dart';
import 'logistics_delivery_monitoring_page.dart';
import 'logistics_incoming_parcels_page.dart';
import 'logistics_city_handoffs_page.dart';
import 'logistics_sorting_center_page.dart';
import 'logistics_sorting_queue_page.dart';
import 'logistics_waybill_lookup_page.dart';

class LogisticsHomePage extends StatefulWidget {
  const LogisticsHomePage({
    super.key,
    required this.authService,
    required this.repository,
    this.notificationsRepository,
    this.messagesRepository,
  });

  final AuthService authService;
  final LogisticsRepository repository;
  final MobileNotificationsDataSource? notificationsRepository;
  final LogisticsMessagesRepository? messagesRepository;

  @override
  State<LogisticsHomePage> createState() => _LogisticsHomePageState();
}

class _LogisticsHomePageState extends State<LogisticsHomePage> {
  late Future<LogisticsDashboard> _dashboard;
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

  Future<void> _refresh() async {
    final next = widget.repository.dashboard();
    setState(() {
      _dashboard = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder presents the request failure and keeps Retry available.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(
      context,
      AppRouteNames.logisticsNotifications,
      arguments: _notificationUnreadCount,
    );
    if (!mounted) return;
    await _refresh();
    await _refreshNotificationCount(force: true);
  }

  Future<void> _openMessages() async {
    await Navigator.pushNamed(context, AppRouteNames.logisticsMessages);
    if (!mounted) return;
    await _refresh();
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
      // Keep Logistics operations available if notifications are offline.
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
      // Keep Logistics operations available if messaging is offline.
    } finally {
      if (identical(_messageCountRequest, request)) _messageCountRequest = null;
    }
  }

  void _openLogin() => Navigator.pushNamedAndRemoveUntil(
    context,
    AppRouteNames.login,
    (_) => false,
  );

  void _openWaybillLookup() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => LogisticsWaybillLookupPage(repository: widget.repository),
    ),
  );

  Future<void> _openIncomingReceipt() => _openOperationalPage(
    LogisticsIncomingParcelsPage(repository: widget.repository),
  );

  Future<void> _openIncomingParcels() => _openOperationalPage(
    LogisticsIncomingParcelsPage(repository: widget.repository),
  );

  Future<void> _openIncomingHandoff() => _openOperationalPage(
    LogisticsWaybillLookupPage(
      repository: widget.repository,
      handoffEnabled: true,
    ),
  );

  Future<void> _openCityHandoffs() => _openOperationalPage(
    LogisticsCityHandoffsWorkspacePage(repository: widget.repository),
  );

  Future<void> _openSortingQueue() => _openOperationalPage(
    LogisticsSortingQueuePage(repository: widget.repository),
  );

  Future<void> _openSortingCenter() => _openOperationalPage(
    LogisticsSortingCenterPage(
      repository: widget.repository,
      onOpenSortingQueue: _openSortingQueue,
      onOpenDispatchBoard: _openDispatchBoard,
    ),
  );

  Future<void> _openDispatchBoard() => _openOperationalPage(
    LogisticsDispatchPage(repository: widget.repository),
  );

  Future<void> _openRiderManagement() async {
    await Navigator.of(context).pushNamed(AppRouteNames.logisticsRiders);
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openPickupRequests() async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouteNames.logisticsPickupRequests);
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openCashCustody() async {
    await Navigator.of(context).pushNamed(AppRouteNames.logisticsCashCustody);
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openOperationalPage(Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    await _refresh();
  }

  void _openDeliveryMonitoring() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) =>
          LogisticsDeliveryMonitoringPage(repository: widget.repository),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
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
        if (widget.messagesRepository != null)
          IconButton(
            key: const ValueKey('logistics-open-messages'),
            onPressed: _openMessages,
            tooltip: 'Messages',
            icon: Badge(
              isLabelVisible: _messageUnreadCount > 0,
              label: Text(
                _messageUnreadCount > 99 ? '99+' : '$_messageUnreadCount',
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh dashboard',
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouteNames.logout,
            (_) => false,
          ),
          tooltip: 'Log out',
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsDashboard>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final unauthorized =
              snapshot.error is ApiHttpException &&
              ((snapshot.error! as ApiHttpException).statusCode == 401 ||
                  (snapshot.error! as ApiHttpException).statusCode == 403);
          return _problem(
            unauthorized
                ? 'Your Logistics session is no longer authorized. Sign in again.'
                : 'Could not load your Logistics dashboard. Check your connection and retry.',
            unauthorized: unauthorized,
          );
        }

        final dashboard = snapshot.data;
        if (dashboard == null) {
          return _problem('The Logistics dashboard is unavailable.');
        }
        return _dashboardBody(dashboard);
      },
    ),
  );

  Widget _problem(String message, {bool unauthorized = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unauthorized
                ? Icons.lock_outline_rounded
                : Icons.cloud_off_outlined,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: unauthorized ? _openLogin : _refresh,
            icon: Icon(
              unauthorized ? Icons.login_rounded : Icons.refresh_rounded,
            ),
            label: Text(unauthorized ? 'Sign in again' : 'Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _dashboardBody(LogisticsDashboard dashboard) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Text(
          'Logistics dashboard',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Welcome, ${widget.authService.currentSession?.name ?? dashboard.providerName}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Read-only overview for ${dashboard.providerName}.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
        ),
        const SizedBox(height: 16),
        _providerCard(dashboard),
        const SizedBox(height: 12),
        _centerCard(dashboard),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-open-waybill-lookup'),
            onPressed: _openWaybillLookup,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan Waybill'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-open-incoming-parcels'),
            onPressed: _openIncomingParcels,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Incoming Parcels'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('logistics-open-incoming-receipt'),
            onPressed: _openIncomingReceipt,
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: const Text('Incoming Parcel Intake'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const ValueKey('logistics-open-incoming-handoff'),
            onPressed: _openIncomingHandoff,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Incoming City Handoff'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-open-city-handoffs-workspace'),
            onPressed: _openCityHandoffs,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('City Handoffs & Courier Runs'),
          ),
        ),
        const SizedBox(height: 18),
        Text('Operations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(
                  cardWidth,
                  'Received today',
                  dashboard.metrics.receivedToday,
                ),
                _metric(
                  cardWidth,
                  'Awaiting sorting',
                  dashboard.metrics.awaitingSorting,
                ),
                _metric(
                  cardWidth,
                  'Sorted and ready',
                  dashboard.metrics.sortedReady,
                ),
                _metric(
                  cardWidth,
                  'Dispatched shipments',
                  dashboard.metrics.dispatchedShipments,
                ),
                _metric(
                  cardWidth,
                  'Active routes',
                  dashboard.metrics.activeRoutes,
                ),
                _metric(
                  cardWidth,
                  'Sorting exceptions',
                  dashboard.metrics.sortingExceptions,
                ),
                _metric(
                  cardWidth,
                  'Pickup requests',
                  dashboard.metrics.pendingPickupRequests,
                ),
                _metric(
                  cardWidth,
                  'Incoming handoffs',
                  dashboard.metrics.incomingHandoffs,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('logistics-open-pickup-requests'),
            onPressed: _openPickupRequests,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Pickup Requests'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-open-cash-custody'),
            onPressed: _openCashCustody,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Cash Custody'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-open-rider-management'),
            onPressed: _openRiderManagement,
            icon: const Icon(Icons.groups_2_outlined),
            label: const Text('Rider Management'),
          ),
        ),
        const SizedBox(height: 8),
        _handoffsSection(dashboard.incomingHandoffs),
        const SizedBox(height: 14),
        _parcelsSection(dashboard.incomingParcels),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-open-sorting-center'),
            onPressed: _openSortingCenter,
            icon: const Icon(Icons.warehouse_outlined),
            label: const Text('Sorting Center'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('logistics-open-sorting-queue'),
            onPressed: _openSortingQueue,
            icon: const Icon(Icons.sort_rounded),
            label: const Text('Sorting Queue'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const ValueKey('logistics-open-delivery-dispatch'),
            onPressed: _openDispatchBoard,
            icon: const Icon(Icons.outbox_outlined),
            label: const Text('Delivery Dispatch'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-open-delivery-monitoring'),
            onPressed: _openDeliveryMonitoring,
            icon: const Icon(Icons.route_outlined),
            label: const Text('Delivery Monitoring'),
          ),
        ),
      ],
    ),
  );

  Widget _providerCard(LogisticsDashboard dashboard) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
      title: Text(dashboard.providerName),
      subtitle: const Text('Logistics provider'),
      trailing: _status(dashboard.providerStatus),
    ),
  );

  Widget _centerCard(LogisticsDashboard dashboard) {
    final center = dashboard.sortingCenter;
    if (center == null || dashboard.setupRequired) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.warehouse_outlined),
          title: const Text('Sorting center setup required'),
          subtitle: const Text(
            'No active sorting center is assigned to this provider.',
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.warehouse_outlined),
        title: Text(center.name),
        subtitle: Text(
          [
            center.code,
            center.address,
          ].where((value) => value.isNotEmpty).join(' · '),
        ),
        trailing: _status(center.status),
      ),
    );
  }

  Widget _status(String value) => Chip(
    label: Text(value.isEmpty ? 'Unknown' : value),
    visualDensity: VisualDensity.compact,
  );

  Widget _metric(double width, String label, int value) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: BearlyColors.brown900,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );

  Widget _handoffsSection(List<LogisticsIncomingHandoff> handoffs) =>
      _summarySection(
        title: 'Incoming handoffs',
        empty: 'No incoming handoffs are waiting.',
        children: handoffs
            .map(
              (handoff) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.move_to_inbox_outlined),
                title: Text(handoff.waybill),
                subtitle: Text(
                  '${handoff.fromProvider} · ${handoff.parcelCount} parcel(s)',
                ),
              ),
            )
            .toList(growable: false),
      );

  Widget _parcelsSection(
    List<LogisticsIncomingParcel> parcels,
  ) => _summarySection(
    title: 'Parcel records at this center',
    description:
        'Current parcel statuses are shown below. Center intake records are historical.',
    empty: 'No parcel records are currently listed at your center.',
    children: parcels
        .map(
          (parcel) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(parcel.waybill),
            subtitle: Text(_incomingParcelSummary(parcel)),
          ),
        )
        .toList(growable: false),
  );

  Widget _summarySection({
    required String title,
    required String empty,
    required List<Widget> children,
    String? description,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 6),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(empty, style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...children,
        ],
      ),
    ),
  );

  String _incomingParcelSummary(LogisticsIncomingParcel parcel) {
    final statuses = parcel.parcelStatuses.isEmpty
        ? 'Unknown'
        : parcel.parcelStatuses.map(_statusLabel).join(', ');
    final summary = '$statuses · ${parcel.parcelCount} parcel(s)';
    return parcel.intakeRecorded
        ? '$summary · center intake recorded previously'
        : summary;
  }

  String _statusLabel(String value) => value
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
