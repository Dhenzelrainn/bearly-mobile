import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';

class RiderPageScaffold extends StatelessWidget {
  const RiderPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.currentRoute,
    this.showBottomNavigationBar = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? currentRoute;
  final bool showBottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => _returnToDashboard(context),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const BearlyLogo(height: 34, width: 102),
        actions: [RiderSecondaryMenuButton(currentRoute: currentRoute)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
      bottomNavigationBar: showBottomNavigationBar
          ? RiderBottomNavigationBar(currentRoute: currentRoute)
          : null,
    );
  }

  void _returnToDashboard(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else if (currentRoute != AppRouteNames.rider) {
      navigator.pushReplacementNamed(AppRouteNames.rider);
    }
  }
}

/// The five primary Rider destinations, shared by every operational screen.
class RiderBottomNavigationBar extends StatelessWidget {
  const RiderBottomNavigationBar({
    super.key,
    required this.currentRoute,
    this.onNavigate,
  });

  final String? currentRoute;
  final Future<void> Function(String route)? onNavigate;

  static const _routes = <String>[
    AppRouteNames.rider,
    AppRouteNames.riderRequests,
    AppRouteNames.riderTransit,
    AppRouteNames.riderEarnings,
    AppRouteNames.riderAccount,
  ];

  static const _destinations = <NavigationDestination>[
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
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveRoute = currentRoute == AppRouteNames.riderHistory
        ? AppRouteNames.riderTransit
        : currentRoute;
    final selectedIndex = _routes.indexOf(effectiveRoute ?? '');
    return NavigationBar(
      height: 72,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) async {
        final route = _routes[index];
        if (route == currentRoute) return;
        if (onNavigate case final navigate?) {
          await navigate(route);
        } else {
          _navigateToPrimaryDestination(context, route);
        }
      },
      destinations: _destinations,
    );
  }

  void _navigateToPrimaryDestination(BuildContext context, String route) {
    final navigator = Navigator.of(context);
    var dashboardIsInStack = false;
    navigator.popUntil((entry) {
      if (entry.settings.name == AppRouteNames.rider) {
        dashboardIsInStack = true;
        return true;
      }
      return entry.isFirst;
    });

    if (route == AppRouteNames.rider) {
      if (dashboardIsInStack) return;
      if (currentRoute != AppRouteNames.rider) {
        navigator.pushReplacementNamed(AppRouteNames.rider);
      }
      return;
    }

    if (dashboardIsInStack) {
      // The dashboard is the single root beneath whichever tab is open.
      navigator.pushNamed(route);
    } else if (currentRoute == AppRouteNames.rider) {
      // Supports embedded/test roots whose route name is not `/rider`.
      navigator.pushNamedAndRemoveUntil(route, (entry) => entry.isFirst);
    } else {
      // A deep-linked secondary screen has no dashboard beneath it, so replace
      // its stack instead of leaving an unrelated page behind a selected tab.
      navigator.pushNamedAndRemoveUntil(route, (_) => false);
    }
  }
}

/// Secondary destinations are deliberately limited to history and sign-out.
/// Primary tabs and unfinished messaging/onboarding shortcuts do not belong here.
class RiderSecondaryMenuButton extends StatelessWidget {
  const RiderSecondaryMenuButton({super.key, this.currentRoute});

  final String? currentRoute;

  static const _items = <(String, String)>[
    (AppRouteNames.riderHistory, 'Delivery history'),
    (AppRouteNames.logout, 'Sign out'),
  ];

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'More Rider options',
    onSelected: (route) {
      if (route == currentRoute) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    },
    itemBuilder: (_) => [
      for (final (route, label) in _items)
        PopupMenuItem(value: route, child: Text(label)),
    ],
  );
}

Widget riderSummary(
  BuildContext context,
  IconData icon,
  String value,
  String label,
) => Container(
  padding: const EdgeInsets.all(13),
  decoration: BoxDecoration(
    color: BearlyColors.cream100,
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    children: [
      CircleAvatar(
        backgroundColor: BearlyColors.cream200,
        foregroundColor: BearlyColors.brown700,
        child: Icon(icon),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ],
  ),
);

Widget riderRouteRow(
  BuildContext context,
  IconData icon,
  String label,
  String value,
) => Row(
  children: [
    Icon(icon, size: 19, color: BearlyColors.brown700),
    const SizedBox(width: 8),
    Text('$label  ', style: Theme.of(context).textTheme.bodySmall),
    Expanded(
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  ],
);
