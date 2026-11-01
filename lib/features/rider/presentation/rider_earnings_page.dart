import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../data/rider_repository.dart';
import '../models/rider_account.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderEarningsPage extends StatefulWidget {
  const RiderEarningsPage({super.key, required this.repository});

  final RiderRepository repository;

  @override
  State<RiderEarningsPage> createState() => _RiderEarningsPageState();
}

class _RiderEarningsPageState extends State<RiderEarningsPage> {
  late final Future<RiderAccount> _account = widget.repository.account();

  @override
  Widget build(BuildContext context) => FutureBuilder<RiderAccount>(
    future: _account,
    builder: (context, snapshot) => RiderPageScaffold(
      currentRoute: AppRouteNames.riderEarnings,
      title: 'Earnings',
      subtitle: 'Earnings are not available in the Rider app yet.',
      supportsLocalFulfillment: snapshot.data?.supportsLocalFulfillment == true,
      child: const Card(
        color: Colors.white,
        child: ListTile(
          leading: Icon(Icons.payments_outlined),
          title: Text('Earnings unavailable in this version'),
          subtitle: Text(
            'Earnings information will appear here when available.',
          ),
        ),
      ),
    ),
  );
}
