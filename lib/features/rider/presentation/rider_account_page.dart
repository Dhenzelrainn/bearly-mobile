import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../data/rider_repository.dart';
import '../models/rider_account.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderAccountPage extends StatefulWidget {
  const RiderAccountPage({super.key, required this.repository});

  final RiderRepository repository;

  @override
  State<RiderAccountPage> createState() => _RiderAccountPageState();
}

class _RiderAccountPageState extends State<RiderAccountPage> {
  late Future<RiderAccount> _account;

  @override
  void initState() {
    super.initState();
    _account = widget.repository.account();
  }

  void _retry() => setState(() => _account = widget.repository.account());

  @override
  Widget build(BuildContext context) => FutureBuilder<RiderAccount>(
    future: _account,
    builder: (context, snapshot) => RiderPageScaffold(
      currentRoute: AppRouteNames.riderAccount,
      title: 'Rider Account',
      subtitle: 'Your approved profile and registered Rider details.',
      supportsLocalFulfillment:
          snapshot.data?.supportsLocalFulfillment ??
          widget.repository.lastKnownWorkAccess?.supportsLocalFulfillment ==
              true,
      child: _accountContent(context, snapshot),
    ),
  );

  Widget _accountContent(
    BuildContext context,
    AsyncSnapshot<RiderAccount> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (snapshot.hasError) {
      return _message(
        context,
        'Could not load your Rider account. Check your connection and retry.',
        onRetry: _retry,
      );
    }

    final account = snapshot.data;
    if (account == null) {
      return _message(context, 'Rider account details are unavailable.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const CircleAvatar(
              radius: 24,
              child: Icon(Icons.delivery_dining_rounded),
            ),
            title: Text(account.name),
            subtitle: Text(account.email),
          ),
        ),
        _section(context, 'Account', Icons.verified_user_outlined, [
          _line('Account status', _label(account.accountStatus)),
          _line('Rider approval', _label(account.verificationStatus)),
          _line('Availability', _label(account.availabilityStatus)),
          _line('Work type', _workTypeLabel(account.workType)),
          _line(
            'Local pickup and delivery',
            account.supportsLocalFulfillment
                ? 'Available'
                : 'Not available on Mobile',
          ),
        ]),
        _section(context, 'Vehicle', Icons.two_wheeler_outlined, [
          _line('Type', _value(account.vehicleType)),
          _line('Model', _value(account.vehicleModel)),
          _line('Plate number', _value(account.plateNumber)),
          _line(
            'Parcel capacity',
            account.parcelCapacity?.toString() ?? 'Not provided',
          ),
        ]),
        _section(context, 'Logistics provider', Icons.local_shipping_outlined, [
          _line('Provider', _value(account.logisticsProvider)),
          _line('Home sorting center', _value(account.homeSortingCenter)),
          _line('Current zone', _value(account.currentZone)),
          _line('Zone sorting center', _value(account.currentZoneCenter)),
        ]),
        _section(context, 'Documents', Icons.folder_shared_outlined, [
          _line('Valid ID', _document(account.documents['valid_id'])),
          _line('OR / CR', _document(account.documents['or_cr'])),
          _line(
            'Driver license',
            _document(account.documents['driver_license']),
          ),
        ]),
        _section(
          context,
          'Registered addresses',
          Icons.location_on_outlined,
          account.addresses.isEmpty
              ? [_line('Address', 'No address on file')]
              : account.addresses
                    .map(
                      (address) =>
                          _line(_value(address.label), _value(address.address)),
                    )
                    .toList(growable: false),
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> lines,
  ) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          ...lines,
        ],
      ),
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 142, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _message(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
        ],
      ),
    ),
  );

  String _value(String value) => value.trim().isEmpty ? 'Not provided' : value;

  String _label(String value) =>
      value.trim().isEmpty ? 'Unavailable' : value.replaceAll('_', ' ');

  String _workTypeLabel(String value) => switch (value) {
    'courier' => 'Courier',
    'local' => 'Local Rider',
    _ => _label(value),
  };

  String _document(String? value) => switch (value) {
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    'pending' => 'Pending review',
    'status_unavailable' => 'On file; status unavailable',
    _ => 'Not provided',
  };
}
