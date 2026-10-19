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
  });

  final String title;
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
                value: AppRouteNames.rider,
                child: Text('Rider dashboard'),
              ),
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
              AppRouteNames.login,
              (_) => false,
            ),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
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
