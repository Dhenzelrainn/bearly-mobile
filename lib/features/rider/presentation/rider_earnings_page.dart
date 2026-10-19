import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderEarningsPage extends StatelessWidget {
  const RiderEarningsPage({super.key});

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: 'Earnings',
    subtitle: 'Review your courier payout summary and daily ledger.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BearlyColors.brown900,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current week',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                '₱1,248',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                '8 deliveries • ₱178 incentives • ₱130 tips',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Daily earnings ledger',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ...[
          ['Aug 25, 2026', '8 deliveries', '₱1,248'],
          ['Aug 24, 2026', '7 deliveries', '₱1,062'],
          ['Aug 23, 2026', '9 deliveries', '₱1,409'],
          ['Aug 22, 2026', '6 deliveries', '₱911'],
        ].map(
          (row) => Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(row[0]),
              subtitle: Text(row[1]),
              trailing: Text(
                row[2],
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: BearlyColors.brown700),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
