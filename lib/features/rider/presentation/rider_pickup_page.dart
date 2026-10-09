import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import 'rider_shared.dart';

class RiderPickupPage extends StatefulWidget {
  const RiderPickupPage({super.key});

  @override
  State<RiderPickupPage> createState() => _RiderPickupPageState();
}

class _RiderPickupPageState extends State<RiderPickupPage> {
  final _checked = <bool>[false, false, false];

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: 'Pick Up Order',
    module: 'MODULE 04',
    subtitle:
        'Verify the parcel and order information before leaving the seller.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        riderSummary(
          context,
          Icons.inventory_2_rounded,
          'ORD-71042',
          'Pickup window: Today, 4:00–5:00 PM',
        ),
        const SizedBox(height: 14),
        riderContactCard(
          context,
          Icons.storefront_outlined,
          'Northstar Watches',
          'Gateway Tower 2, Cubao, Quezon City',
        ),
        const SizedBox(height: 14),
        Text('Pickup checklist', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _check(
          0,
          'Item matches the order',
          'Classic Steel Watch • Qty 1',
          Icons.inventory_2_outlined,
        ),
        _check(
          1,
          'Package is sealed and labeled',
          'Confirm parcel condition before leaving.',
          Icons.local_shipping_outlined,
        ),
        _check(
          2,
          'Order number matches',
          'Seller parcel matches ORD-71042.',
          Icons.qr_code_scanner_rounded,
        ),
        const SizedBox(height: 14),
        riderNotice(
          context,
          'Seller destination',
          'Gateway Tower 2, Cubao, Quezon City',
          Icons.map_outlined,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.inventory_2_rounded),
          label: const Text('Confirm item pickup'),
        ),
      ],
    ),
  );

  Widget _check(int index, String title, String subtitle, IconData icon) =>
      Card(
        color: Colors.white,
        child: CheckboxListTile(
          value: _checked[index],
          onChanged: (value) =>
              setState(() => _checked[index] = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );

  void _confirm() {
    if (_checked.any((item) => !item)) {
      riderMessage(
        context,
        'Complete every verification item before confirming pickup.',
      );
      return;
    }
    Navigator.pushNamed(context, AppRoutes.riderTransit);
  }
}
