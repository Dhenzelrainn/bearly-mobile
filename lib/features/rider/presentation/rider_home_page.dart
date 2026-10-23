import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../data/rider_demo_data.dart';
import '../models/rider_job.dart';

/// Rider dashboard. Other rider modules live in their own page files and are
/// opened from the bottom navigation or the dashboard menu.
class RiderHomePage extends StatefulWidget {
  const RiderHomePage({super.key});

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  bool _online = true;

  void _open(String route) => Navigator.pushNamed(context, route);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BearlyLogo(height: 34, width: 102),
        actions: [
          IconButton(
            onPressed: () => _open(AppRouteNames.riderMessages),
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: _open,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: AppRouteNames.riderRegister,
                child: Text('Rider registration'),
              ),
              PopupMenuItem(
                value: AppRouteNames.riderPending,
                child: Text('Application pending'),
              ),
              PopupMenuItem(
                value: AppRouteNames.riderRequests,
                child: Text('Requests'),
              ),
              PopupMenuItem(
                value: AppRouteNames.riderPickup,
                child: Text('Pick up order'),
              ),
              PopupMenuItem(
                value: AppRouteNames.riderTransit,
                child: Text('Deliver order'),
              ),
              PopupMenuItem(
                value: AppRouteNames.riderComplete,
                child: Text('Complete delivery'),
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
      body: _dashboard(),
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
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.navigation_outlined),
            selectedIcon: Icon(Icons.navigation_rounded),
            label: 'Active',
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
  }

  Widget _dashboard() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, Adrian',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready for your next delivery?',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: _online,
            activeThumbColor: BearlyColors.success,
            onChanged: (value) => setState(() => _online = value),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _online ? BearlyColors.brown900 : BearlyColors.cream200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              _online
                  ? Icons.wifi_tethering_rounded
                  : Icons.pause_circle_outline_rounded,
              color: _online ? Colors.white : BearlyColors.brown900,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _online ? 'You are online' : 'You are offline',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _online ? Colors.white : BearlyColors.brown900,
                    ),
                  ),
                  Text(
                    _online
                        ? 'You can receive delivery requests nearby.'
                        : 'Go online when you are ready to deliver.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _online ? Colors.white70 : BearlyColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          _stat('₱1,248', 'This week'),
          const SizedBox(width: 10),
          _stat('8', 'Deliveries'),
          const SizedBox(width: 10),
          _stat('4.9', 'Rating'),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Text(
            'Active delivery',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _open(AppRouteNames.riderTransit),
            child: const Text('Open'),
          ),
        ],
      ),
      _activeCard(),
      const SizedBox(height: 18),
      Row(
        children: [
          Text(
            'Nearby requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _open(AppRouteNames.riderRequests),
            child: const Text('View all'),
          ),
        ],
      ),
      ...riderJobs.take(2).map((job) => _requestPreview(job)),
      const SizedBox(height: 8),
      Card(
        color: BearlyColors.cream100,
        child: ListTile(
          leading: const Icon(
            Icons.info_outline_rounded,
            color: BearlyColors.brown700,
          ),
          title: const Text('Keep customers updated'),
          subtitle: const Text(
            'Use messages to coordinate arrival and handoff details.',
          ),
          trailing: IconButton(
            onPressed: () => _open(AppRouteNames.riderMessages),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ),
    ],
  );

  Widget _stat(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
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
    ),
  );

  Widget _activeCard() => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: BearlyColors.cream200,
                foregroundColor: BearlyColors.brown700,
                child: Icon(Icons.navigation_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORD-71042',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('Northstar Watches → Mika Reyes'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2E6),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('In Transit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _routeColumn(
                  Icons.storefront_outlined,
                  'Pickup',
                  'Cubao, Quezon City',
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: BearlyColors.line),
              Expanded(
                child: _routeColumn(
                  Icons.home_outlined,
                  'Drop-off',
                  'Greenhills, San Juan',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _routeColumn(IconData icon, String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: BearlyColors.brown700),
      const SizedBox(height: 5),
      Text(title, style: Theme.of(context).textTheme.labelMedium),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _requestPreview(RiderJob job) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          backgroundColor: BearlyColors.cream200,
          child: Icon(
            Icons.local_shipping_outlined,
            color: BearlyColors.brown700,
          ),
        ),
        title: Text('${job.order} • ${job.store}'),
        subtitle: Text('${job.pickup} → ${job.dropoff}'),
        trailing: Text(
          job.payout,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: BearlyColors.brown700),
        ),
      ),
    );
  }
}
