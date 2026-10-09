import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';

class RiderJob {
  const RiderJob({
    required this.id,
    required this.order,
    required this.store,
    required this.pickup,
    required this.dropoff,
    required this.distance,
    required this.payout,
    required this.eta,
    required this.size,
    required this.priority,
  });

  final String id;
  final String order;
  final String store;
  final String pickup;
  final String dropoff;
  final String distance;
  final String payout;
  final String eta;
  final String size;
  final bool priority;
}

const riderJobs = <RiderJob>[
  RiderJob(
    id: 'REQ-4108',
    order: 'ORD-71042',
    store: 'Northstar Watches',
    pickup: 'Cubao, Quezon City',
    dropoff: 'Greenhills, San Juan',
    distance: '5.8 km',
    payout: '₱148',
    eta: '24 min',
    size: 'Small',
    priority: true,
  ),
  RiderJob(
    id: 'REQ-4109',
    order: 'ORD-71043',
    store: 'Daily Finds MNL',
    pickup: 'Mandaluyong City',
    dropoff: 'BGC, Taguig',
    distance: '7.1 km',
    payout: '₱176',
    eta: '31 min',
    size: 'Medium',
    priority: false,
  ),
  RiderJob(
    id: 'REQ-4110',
    order: 'ORD-71044',
    store: 'Homecraft PH',
    pickup: 'Pasig City',
    dropoff: 'Marikina City',
    distance: '6.4 km',
    payout: '₱159',
    eta: '28 min',
    size: 'Medium',
    priority: false,
  ),
  RiderJob(
    id: 'REQ-4111',
    order: 'ORD-71045',
    store: 'Tech Alley',
    pickup: 'Tomas Morato, Quezon City',
    dropoff: 'Katipunan Ave., Quezon City',
    distance: '4.2 km',
    payout: '₱126',
    eta: '19 min',
    size: 'Small',
    priority: true,
  ),
];

class RiderPageScaffold extends StatelessWidget {
  const RiderPageScaffold({
    super.key,
    required this.title,
    required this.module,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String module;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const BearlyLogo(height: 34, width: 102),
        actions: [
          PopupMenuButton<String>(
            onSelected: (route) => Navigator.pushNamed(context, route),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: AppRoutes.rider,
                child: Text('Rider dashboard'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderRegister,
                child: Text('Rider registration'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderPending,
                child: Text('Application pending'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderRequests,
                child: Text('Requests'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderPickup,
                child: Text('Pick up order'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderTransit,
                child: Text('Deliver order'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderComplete,
                child: Text('Complete delivery'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderEarnings,
                child: Text('Earnings'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderHistory,
                child: Text('Delivery history'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderMessages,
                child: Text('Messages'),
              ),
              PopupMenuItem(
                value: AppRoutes.riderAccount,
                child: Text('Account'),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (_) => false,
            ),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            module,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: BearlyColors.gold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }
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

Widget riderContactCard(
  BuildContext context,
  IconData icon,
  String title,
  String address,
) => Card(
  color: Colors.white,
  child: ListTile(
    contentPadding: const EdgeInsets.all(11),
    leading: CircleAvatar(
      backgroundColor: BearlyColors.cream200,
      foregroundColor: BearlyColors.brown700,
      child: Icon(icon),
    ),
    title: Text(title),
    subtitle: Text(address),
    trailing: IconButton(
      onPressed: () => riderMessage(context, 'Calling $title...'),
      icon: const Icon(Icons.phone_outlined),
    ),
  ),
);

Widget riderNotice(
  BuildContext context,
  String title,
  String body,
  IconData icon,
) => Container(
  padding: const EdgeInsets.all(13),
  decoration: BoxDecoration(
    color: BearlyColors.cream100,
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: BearlyColors.brown700),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(body),
          ],
        ),
      ),
    ],
  ),
);

void riderMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
