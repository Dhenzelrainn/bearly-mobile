import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';

class BuyerCartPage extends StatefulWidget {
  const BuyerCartPage({super.key});

  @override
  State<BuyerCartPage> createState() => _BuyerCartPageState();
}

class _BuyerCartPageState extends State<BuyerCartPage> {
  final _items = <_CartItem>[
    _CartItem(
      'Classic Linen Shirt',
      "Juan's Clothing Shop",
      '₱899',
      'assets/images/landing/fashion.webp',
    ),
    _CartItem(
      'Portable Power Bank',
      'TechVault PH',
      '₱1,299',
      'assets/images/landing/tech.webp',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const BearlyLogo(height: 34, width: 102),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        children: [
          Text('Your cart', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          Text(
            '${_items.length} items ready for checkout.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
          ),
          const SizedBox(height: 14),
          if (_items.isEmpty)
            _emptyState()
          else
            ..._items.asMap().entries.map(_itemTile),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 14),
            _summary(),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _checkout,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Continue to checkout'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouteNames.buyer,
                (_) => false,
              ),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Continue shopping'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemTile(MapEntry<int, _CartItem> entry) {
    final item = entry.value;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                item.image,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: BearlyColors.cream200,
                  child: const Icon(Icons.image_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.store,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.price,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BearlyColors.brown700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _items.removeAt(entry.key)),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BearlyColors.cream100,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        _row('Subtotal', '₱2,198'),
        _row('Delivery fee', '₱80'),
        const Divider(height: 22),
        _row('Total', '₱2,278', strong: true),
      ],
    ),
  );

  Widget _row(String label, String value, {bool strong = false}) => Row(
    children: [
      Text(
        label,
        style: strong ? Theme.of(context).textTheme.titleMedium : null,
      ),
      const Spacer(),
      Text(
        value,
        style: strong
            ? Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: BearlyColors.brown700)
            : null,
      ),
    ],
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.only(top: 100),
    child: Column(
      children: [
        const Icon(
          Icons.shopping_cart_outlined,
          size: 54,
          color: BearlyColors.brown500,
        ),
        const SizedBox(height: 14),
        Text(
          'Your cart is empty',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        const Text('Add products from the marketplace to get started.'),
      ],
    ),
  );

  void _checkout() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Checkout will connect to Laravel payment and order APIs.'),
    ),
  );
}

class _CartItem {
  const _CartItem(this.name, this.store, this.price, this.image);
  final String name;
  final String store;
  final String price;
  final String image;
}
