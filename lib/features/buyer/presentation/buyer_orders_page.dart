import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';

class BuyerOrdersPage extends StatelessWidget {
  const BuyerOrdersPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      Text('My orders', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      Text(
        'Track purchases and delivery updates in one place.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
      ),
      const SizedBox(height: 14),
      _order(
        context,
        'ORD-50192',
        'Classic Linen Shirt',
        'Out for delivery',
        Icons.local_shipping_outlined,
        BearlyColors.gold,
      ),
      _order(
        context,
        'ORD-50171',
        'Portable Power Bank',
        'Delivered',
        Icons.check_circle_outline_rounded,
        BearlyColors.success,
      ),
      _order(
        context,
        'ORD-50154',
        'Soft Home Organizer',
        'Preparing order',
        Icons.inventory_2_outlined,
        BearlyColors.brown700,
      ),
    ],
  );

  Widget _order(
    BuildContext context,
    String id,
    String item,
    String status,
    IconData icon,
    Color color,
  ) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(11),
      onTap: () => _details(context, id, item, status),
      leading: CircleAvatar(
        backgroundColor: BearlyColors.cream200,
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(item),
      subtitle: Text('$id • $status'),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );

  void _details(BuildContext context, String id, String item, String status) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                Text(
                  id,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: BearlyColors.gold),
                ),
                const SizedBox(height: 4),
                Text(item, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Status: $status'),
                const SizedBox(height: 18),
                const LinearProgressIndicator(value: .68),
                const SizedBox(height: 8),
                const Text(
                  'Order placed  •  Packed  •  In transit  •  Delivered',
                ),
              ],
            ),
          ),
        ),
      );
}
