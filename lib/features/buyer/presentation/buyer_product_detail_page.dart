import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../models/buyer_product.dart';

class BuyerProductDetailPage extends StatefulWidget {
  const BuyerProductDetailPage({super.key, required this.product});

  final BuyerProduct product;

  @override
  State<BuyerProductDetailPage> createState() => _BuyerProductDetailPageState();
}

class _BuyerProductDetailPageState extends State<BuyerProductDetailPage> {
  int _quantity = 1;

  BuyerProduct get _product => widget.product;

  bool get _compact => MediaQuery.sizeOf(context).width < 600;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: BearlyLogo(
          height: _compact ? 32 : 38,
          width: _compact ? 96 : 112,
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final content = [
            _gallery(),
            _details(),
            _sellerCard(),
            _description(),
            _reviews(),
          ];

          if (wide) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content[0]),
                    const SizedBox(width: 24),
                    Expanded(child: content[1]),
                  ],
                ),
                const SizedBox(height: 18),
                content[2],
                content[3],
                content[4],
              ],
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              _compact ? 10 : 16,
              _compact ? 8 : 12,
              _compact ? 10 : 16,
              _compact ? 20 : 28,
            ),
            children: [...content, const SizedBox(height: 4)],
          );
        },
      ),
    );
  }

  Widget _gallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _compact ? 240 : 320,
          width: double.infinity,
          padding: EdgeInsets.all(_compact ? 12 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_compact ? 14 : 18),
            border: Border.all(color: BearlyColors.lineSoft),
          ),
          child: Image.asset(
            _product.image,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_outlined,
              size: 64,
              color: BearlyColors.brown500,
            ),
          ),
        ),
        SizedBox(height: _compact ? 6 : 8),
        Container(
          height: _compact ? 48 : 58,
          width: _compact ? 48 : 58,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_compact ? 8 : 10),
            border: Border.all(color: BearlyColors.gold, width: 1.5),
          ),
          child: Image.asset(_product.image, fit: BoxFit.cover),
        ),
      ],
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _product.category,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: BearlyColors.gold,
            fontSize: _compact ? 11.5 : null,
          ),
        ),
        SizedBox(height: _compact ? 3 : 5),
        Text(
          _product.name,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontSize: _compact ? 25 : null),
        ),
        SizedBox(height: _compact ? 4 : 7),
        Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: BearlyColors.orange,
              size: _compact ? 17 : 19,
            ),
            Icon(
              Icons.star_rounded,
              color: BearlyColors.orange,
              size: _compact ? 17 : 19,
            ),
            Icon(
              Icons.star_rounded,
              color: BearlyColors.orange,
              size: _compact ? 17 : 19,
            ),
            Icon(
              Icons.star_rounded,
              color: BearlyColors.orange,
              size: _compact ? 17 : 19,
            ),
            Icon(
              Icons.star_half_rounded,
              color: BearlyColors.orange,
              size: _compact ? 17 : 19,
            ),
            SizedBox(width: _compact ? 5 : 7),
            Text('4.4', style: Theme.of(context).textTheme.bodySmall),
            SizedBox(width: _compact ? 8 : 10),
            Text('41 sold', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        SizedBox(height: _compact ? 9 : 14),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: _compact ? 12 : 14,
            vertical: _compact ? 9 : 12,
          ),
          decoration: BoxDecoration(
            color: BearlyColors.cream200,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            _product.price,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BearlyColors.brown950,
              fontSize: _compact ? 24 : null,
            ),
          ),
        ),
        SizedBox(height: _compact ? 7 : 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _infoChip(Icons.local_shipping_outlined, 'Free shipping'),
            _infoChip(Icons.sell_outlined, 'Voucher available'),
          ],
        ),
        Divider(height: _compact ? 20 : 26),
        Row(
          children: [
            Expanded(child: _detailValue('Condition', 'New')),
            Expanded(child: _detailValue('Ships from', 'Laguna')),
          ],
        ),
        Divider(height: _compact ? 20 : 26),
        Row(
          children: [
            Text('Color', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('Yellow', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        SizedBox(height: _compact ? 6 : 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: _compact ? 10 : 12,
            vertical: _compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: BearlyColors.brown900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _compact ? 16 : 18,
                height: _compact ? 16 : 18,
                decoration: const BoxDecoration(
                  color: BearlyColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: _compact ? 6 : 8),
              const Text('Yellow', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        SizedBox(height: _compact ? 11 : 16),
        Row(
          children: [
            Text('Quantity', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '13 pieces available',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        SizedBox(height: _compact ? 6 : 8),
        _quantityControl(),
        SizedBox(height: _compact ? 9 : 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Add to Cart'),
                style: _compact
                    ? OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _buyNow,
                child: const Text('Buy Now'),
                style: _compact
                    ? FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      )
                    : null,
              ),
            ),
          ],
        ),
        SizedBox(height: _compact ? 5 : 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: BearlyColors.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Frontend preview only — checkout and inventory will be connected during backend integration.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: _compact ? 10 : 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: _compact ? 8 : 9,
      vertical: _compact ? 5 : 6,
    ),
    decoration: BoxDecoration(
      border: Border.all(color: BearlyColors.line),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _compact ? 14 : 15, color: BearlyColors.brown700),
        SizedBox(width: _compact ? 4 : 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _detailValue(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );

  Widget _quantityControl() => Container(
    width: _compact ? 108 : 120,
    height: _compact ? 36 : 40,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BearlyColors.line),
      borderRadius: BorderRadius.circular(_compact ? 6 : 7),
    ),
    child: Row(
      children: [
        _quantityButton(
          Icons.remove_rounded,
          _quantity > 1 ? () => setState(() => _quantity--) : null,
        ),
        Expanded(
          child: Center(
            child: Text(
              '$_quantity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        _quantityButton(
          Icons.add_rounded,
          _quantity < 13 ? () => setState(() => _quantity++) : null,
        ),
      ],
    ),
  );

  Widget _quantityButton(IconData icon, VoidCallback? onPressed) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: _compact ? 16 : 18),
    padding: EdgeInsets.zero,
    constraints: BoxConstraints.tightFor(
      width: _compact ? 34 : 38,
      height: _compact ? 34 : 38,
    ),
  );

  Widget _sellerCard() => Container(
    margin: EdgeInsets.only(top: _compact ? 12 : 16),
    padding: EdgeInsets.all(_compact ? 11 : 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_compact ? 12 : 14),
      border: Border.all(color: BearlyColors.lineSoft),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: _compact ? 21 : 24,
          backgroundColor: BearlyColors.gold,
          foregroundColor: BearlyColors.brown950,
          child: Text('B', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        SizedBox(width: _compact ? 9 : 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sold by', style: Theme.of(context).textTheme.bodySmall),
              Text(
                _product.store,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '★ 4.5 seller rating  •  Laguna',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _message('Chat will connect to Laravel.'),
          style: _compact
              ? OutlinedButton.styleFrom(
                  minimumSize: const Size(70, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                )
              : null,
          child: const Text('Chat'),
        ),
      ],
    ),
  );

  Widget _description() => _section(
    'Product Description',
    Text(
      '${_product.name} sample listing for the Bearly marketplace preview. Product details, stock, seller information, and checkout will be connected to the backend later.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    extra: Wrap(
      spacing: 28,
      runSpacing: 12,
      children: [
        _detailValue('Category', _product.category),
        _detailValue('Condition', 'New'),
        _detailValue('Color', 'Yellow'),
        _detailValue('Location', 'Laguna'),
      ],
    ),
  );

  Widget _reviews() => _section(
    'Ratings & Reviews',
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              '4.4',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: BearlyColors.gold,
                fontSize: _compact ? 26 : null,
              ),
            ),
            Text('out of 5', style: Theme.of(context).textTheme.bodySmall),
            const Text(
              '★★★★★',
              style: TextStyle(color: BearlyColors.orange, letterSpacing: 1),
            ),
          ],
        ),
        SizedBox(width: _compact ? 16 : 22),
        Expanded(
          child: Wrap(
            spacing: 14,
            runSpacing: 10,
            children: const [
              Text('All (18)'),
              Text('5 Star (15)'),
              Text('4 Star (2)'),
              Text('3 Star (1)'),
              Text('With Comments (12)'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _section(String title, Widget child, {Widget? extra}) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: EdgeInsets.all(_compact ? 12 : 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_compact ? 12 : 14),
      border: Border.all(color: BearlyColors.lineSoft),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontSize: _compact ? 17 : null),
        ),
        SizedBox(height: _compact ? 7 : 9),
        child,
        if (extra != null) ...[Divider(height: _compact ? 20 : 24), extra],
      ],
    ),
  );

  void _addToCart() {
    riderlessMessage('Added $_quantity ${_product.name} to cart.');
  }

  void _buyNow() {
    riderlessMessage(
      'Buy Now will continue to checkout after the Laravel API is connected.',
    );
  }

  void _message(String message) => riderlessMessage(message);

  void riderlessMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
