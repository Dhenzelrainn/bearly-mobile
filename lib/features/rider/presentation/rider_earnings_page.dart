import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../data/rider_repository.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderEarningsPage extends StatelessWidget {
  const RiderEarningsPage({super.key, required this.repository});

  final RiderRepository repository;

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    currentRoute: AppRouteNames.riderEarnings,
    title: 'Earnings',
    subtitle: 'Earnings are not available in the Rider app yet.',
    supportsLocalFulfillment:
        repository.lastKnownWorkAccess?.supportsLocalFulfillment == true,
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
