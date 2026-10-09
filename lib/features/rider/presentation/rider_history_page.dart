import 'package:flutter/material.dart';

import 'rider_shared.dart';

class RiderHistoryPage extends StatelessWidget {
  const RiderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: 'Delivery History',
    module: 'MODULE 08',
    subtitle: 'Search completed, cancelled, and returned deliveries.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search order, seller, buyer...',
          ),
        ),
        const SizedBox(height: 14),
        ...[
          [
            'ORD-71021',
            'Daily Finds MNL',
            'Mandaluyong → Taguig',
            '₱142',
            'Completed',
          ],
          [
            'ORD-71018',
            'Homecraft PH',
            'Pasig → Marikina',
            '₱155',
            'Completed',
          ],
          [
            'ORD-70984',
            'Tech Alley',
            'Quezon City → San Juan',
            '₱0',
            'Cancelled',
          ],
          ['ORD-70961', 'Casa Living', 'San Juan → Makati', '₱92', 'Returned'],
        ].map(
          (row) => Card(
            color: Colors.white,
            child: ListTile(
              onTap: () => _showDetail(context, row),
              leading: const CircleAvatar(
                child: Icon(Icons.receipt_long_outlined),
              ),
              title: Text(row[0]),
              subtitle: Text('${row[1]} • ${row[2]}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(row[3], style: Theme.of(context).textTheme.titleMedium),
                  Text(row[4], style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  void _showDetail(BuildContext context, List<String> row) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('${row[0]} receipt'),
      content: Text(
        'Seller: ${row[1]}\nRoute: ${row[2]}\nPayout: ${row[3]}\nStatus: ${row[4]}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
