import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({super.key, required this.repository});

  final RiderRepository repository;

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  late Future<RiderDashboard> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = widget.repository.dashboard();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const BearlyLogo(height: 34, width: 102),
      actions: [
        IconButton(
          onPressed: () => _open(AppRouteNames.riderMessages),
          tooltip: 'Messages',
          icon: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh dashboard',
          icon: const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<String>(
          onSelected: _open,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: AppRouteNames.riderRequests,
              child: Text('Assigned pickups'),
            ),
            PopupMenuItem(
              value: AppRouteNames.riderTransit,
              child: Text('Assigned deliveries'),
            ),
            PopupMenuItem(
              value: AppRouteNames.riderEarnings,
              child: Text('Earnings'),
            ),
            PopupMenuItem(
              value: AppRouteNames.riderHistory,
              child: Text('Delivery history'),
            ),
            PopupMenuItem(
              value: AppRouteNames.riderMessages,
              child: Text('Messages'),
            ),
            PopupMenuItem(
              value: AppRouteNames.riderAccount,
              child: Text('Account'),
            ),
          ],
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
    body: FutureBuilder<RiderDashboard>(
      future: _dashboard,
      builder: (context, snapshot) {
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
      },
    ),
    bottomNavigationBar: NavigationBar(
      height: 72,
      selectedIndex: 0,
      onDestinationSelected: (index) {
        const routes = [
          AppRouteNames.rider,
          AppRouteNames.riderRequests,
          AppRouteNames.riderTransit,
          AppRouteNames.riderEarnings,
          AppRouteNames.riderAccount,
        ];
        if (index != 0) _open(routes[index]);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.radar_outlined),
          selectedIcon: Icon(Icons.radar_rounded),
          label: 'Pickups',
        ),
        NavigationDestination(
          icon: Icon(Icons.navigation_outlined),
          selectedIcon: Icon(Icons.navigation_rounded),
          label: 'Deliveries',
        ),
        NavigationDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments_rounded),
          label: 'Earnings',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Account',
        ),
      ],
    ),
  );

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
                        ].where((value) => value.isNotEmpty).join(' Â· '),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _stat('${dashboard.assignedPickups}', 'Assigned pickups'),
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
