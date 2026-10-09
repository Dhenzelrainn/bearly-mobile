import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import 'rider_shared.dart';

class RiderTransitPage extends StatefulWidget {
  const RiderTransitPage({super.key});

  @override
  State<RiderTransitPage> createState() => _RiderTransitPageState();
}

class _RiderTransitPageState extends State<RiderTransitPage> {
  int _step = 2;

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: 'Deliver Order',
    module: 'MODULE 05',
    subtitle: 'Navigate to the customer and keep the delivery status updated.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        riderSummary(
          context,
          Icons.navigation_rounded,
          '24 min',
          '5.8 km remaining',
        ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORD-71042 route',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text('Northstar Watches → Mika Reyes'),
                const SizedBox(height: 16),
                riderRouteRow(
                  context,
                  Icons.storefront_outlined,
                  'Seller',
                  'Cubao, Quezon City',
                ),
                const SizedBox(height: 8),
                riderRouteRow(
                  context,
                  Icons.home_outlined,
                  'Customer',
                  'Greenhills Shopping Center, San Juan',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Delivery progress',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ...['Accepted', 'Picked up', 'In transit', 'Arrived']
            .asMap()
            .entries
            .map((entry) => _timeline(context, entry.key, entry.value)),
        const SizedBox(height: 12),
        riderNotice(
          context,
          'Customer note',
          'Please call when you reach the lobby.',
          Icons.message_outlined,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _arrive,
          icon: const Icon(Icons.location_on_rounded),
          label: const Text('Arrived at location'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.riderComplete),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Proceed to completion'),
        ),
      ],
    ),
  );

  Widget _timeline(BuildContext context, int index, String title) {
    final done = index < _step;
    final current = index == _step;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done || current
                    ? BearlyColors.brown900
                    : BearlyColors.cream200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.circle_outlined,
                color: done || current ? Colors.white : BearlyColors.muted,
                size: 16,
              ),
            ),
            if (index < 3)
              Container(
                width: 2,
                height: 28,
                color: done ? BearlyColors.brown900 : BearlyColors.cream300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: current ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }

  void _arrive() {
    setState(() => _step = 3);
    riderMessage(context, 'Customer marked as arrived.');
  }
}
