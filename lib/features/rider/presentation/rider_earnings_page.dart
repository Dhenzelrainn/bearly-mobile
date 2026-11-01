import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderEarningsPage extends StatelessWidget {
  const RiderEarningsPage({super.key});

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    currentRoute: AppRouteNames.riderEarnings,
    title: 'Earnings',
    subtitle: 'Earnings are not available in the Rider app yet.',
    child: const Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(Icons.payments_outlined),
        title: Text('Earnings unavailable in this version'),
        subtitle: Text('Earnings information will appear here when available.'),
      ),
    ),
  );
}
