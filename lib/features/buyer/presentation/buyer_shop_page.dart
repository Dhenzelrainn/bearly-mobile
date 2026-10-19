import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_demo_data.dart';
import '../models/buyer_product.dart';



class BuyerShopPage extends StatelessWidget {
  const BuyerShopPage({
    super.key,
    required this.query,
    required this.saved,
    required this.onQueryChanged,
    required this.onToggleSaved,
    required this.onAddToCart,
    required this.onMessage,
  });

  final String query;
  final Set<String> saved;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<BuyerProduct> onToggleSaved;
  final ValueChanged<BuyerProduct> onAddToCart;
  final ValueChanged<String> onMessage;

  List<BuyerProduct> get filteredProducts {
    final search = query.trim().toLowerCase();
    if (search.isEmpty) return buyerProducts;
    return buyerProducts
        .where(
          (product) => '${product.name} ${product.store} ${product.category}'
              .toLowerCase()
              .contains(search),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
    children: [
      Text(
        'Good morning, shopper',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 4),
      Text(
        'Find something you will love today.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
      ),
      const SizedBox(height: 14),
      TextField(
        onChanged: onQueryChanged,
        decoration: const InputDecoration(
          hintText: 'Search products and stores',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 16),
      _promoCard(context),
      const SizedBox(height: 20),
      Row(
        children: [
          Text(
            'Browse categories',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          TextButton(
            onPressed: () => onMessage('All categories are coming next.'),
            child: const Text('See all'),
          ),
        ],
      ),
      _categories(context),
      const SizedBox(height: 20),
      Row(
        children: [
          Text(
            'Recommended for you',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          TextButton(
            onPressed: () => onMessage('Tap a product to see its details.'),
            child: const Text('View all'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (filteredProducts.isEmpty)
        const Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: Text('No products match your search.')),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredProducts.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            mainAxisExtent: 276,
          ),
          itemBuilder: (_, index) =>
              _productCard(context, filteredProducts[index]),
        ),
    ],
  );

  Widget _promoCard(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/landing/hero.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: BearlyColors.brown800),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xDD2C1A14)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BEARLY MARKETPLACE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Shopping made easy.',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trusted finds from local sellers.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _categories(BuildContext context) {
    const labels = ['Fashion', 'Tech', 'Home', 'Beauty', 'Books'];
    const icons = [
      Icons.checkroom_rounded,
      Icons.devices_rounded,
      Icons.home_work_outlined,
      Icons.spa_outlined,
      Icons.menu_book_outlined,
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => Container(
          width: 78,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BearlyColors.lineSoft),
          ),
          child: Column(
            children: [
              Icon(icons[index], color: BearlyColors.brown700),
              const SizedBox(height: 4),
              Text(
                labels[index],
                style: Theme.of(context).textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productCard(BuildContext context, BuyerProduct product) {
    final isSaved = saved.contains(product.name);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRouteNames.buyerProduct,
        arguments: product,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: BearlyColors.lineSoft),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.35,
                  child: Image.asset(
                    product.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: BearlyColors.cream200,
                      child: Icon(Icons.image_outlined),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onToggleSaved(product),
                    icon: Icon(
                      isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: BearlyColors.gold,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.store,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        product.price,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: BearlyColors.brown700),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        onPressed: () => onAddToCart(product),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_rounded, size: 19),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
