import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_product.dart';

class BuyerSavedPage extends StatelessWidget {
  const BuyerSavedPage({
    super.key,
    required this.products,
    required this.onAddToCart,
  });

  final List<BuyerProduct> products;
  final ValueChanged<BuyerProduct> onAddToCart;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      Text('Saved products', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      Text(
        'Keep the things you want to come back to.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
      ),
      const SizedBox(height: 14),
      if (products.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: Text('No saved products yet.')),
        )
      else
        ...products.map(
          (product) => Card(
            color: Colors.white,
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  product.image,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(product.name),
              subtitle: Text('${product.store} • ${product.price}'),
              trailing: IconButton(
                onPressed: () => onAddToCart(product),
                icon: const Icon(Icons.add_shopping_cart_rounded),
              ),
            ),
          ),
        ),
    ],
  );
}
