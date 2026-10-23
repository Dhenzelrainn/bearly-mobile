import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_catalog_repository.dart';
import '../models/buyer_catalog_models.dart';

class BuyerProductDetailPage extends StatefulWidget {
  const BuyerProductDetailPage({
    super.key,
    required this.productId,
    required this.repository,
  });

  final int productId;
  final BuyerCatalogRepository repository;

  @override
  State<BuyerProductDetailPage> createState() => _BuyerProductDetailPageState();
}

class _BuyerProductDetailPageState extends State<BuyerProductDetailPage> {
  BuyerCatalogProduct? _product;
  Object? _error;
  int? _selectedVariantId;
  int _selectedImageIndex = 0;
  int _requestSequence = 0;
  bool _loading = true;

  bool get _compact => MediaQuery.sizeOf(context).width < 600;

  BuyerCatalogVariant? get _selectedVariant {
    final product = _product;
    if (product == null || _selectedVariantId == null) return null;
    for (final variant in product.variants) {
      if (variant.id == _selectedVariantId) return variant;
    }
    return null;
  }

  List<String> get _imageUrls {
    final product = _product;
    if (product == null) return const [];
    final gallery = product.images.map((image) => image.url).toList();
    if (gallery.isNotEmpty) return gallery;
    final primary = product.imageUrl;
    return primary == null ? const [] : [primary];
  }

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final sequence = ++_requestSequence;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await widget.repository.getProduct(widget.productId);
      if (!mounted || sequence != _requestSequence) return;
      final selected = _initialVariant(product.variants);
      final primaryImageIndex = product.images.indexWhere(
        (image) => image.url == product.imageUrl,
      );
      setState(() {
        _product = product;
        _selectedVariantId = selected?.id;
        _selectedImageIndex = primaryImageIndex < 0 ? 0 : primaryImageIndex;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || sequence != _requestSequence) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  BuyerCatalogVariant? _initialVariant(List<BuyerCatalogVariant> variants) {
    for (final variant in variants) {
      if (variant.inStock) return variant;
    }
    return variants.isEmpty ? null : variants.first;
  }

  bool _needsSignIn(Object? error) =>
      error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403));

  bool _isUnavailable(Object? error) =>
      error is ApiHttpException && error.statusCode == 404;

  void _signInAgain() => Navigator.pushNamedAndRemoveUntil(
    context,
    AppRouteNames.login,
    (_) => false,
  );

  void _showUnavailableAction(String action) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action will be available in a later phase.')),
      );

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
      body: _loading && _product == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _product == null
          ? _errorState()
          : _product == null
          ? _errorState()
          : _productContent(_product!),
    );
  }

  Widget _errorState() {
    final error = _error;
    final unavailable = _isUnavailable(error);
    final requiresSignIn = _needsSignIn(error);
    final message = unavailable
        ? 'This product is no longer available.'
        : requiresSignIn
        ? 'Your session needs attention. Sign in again to view products.'
        : 'We could not load this product. Check your connection and try again.';
    final action = unavailable
        ? 'Back to marketplace'
        : requiresSignIn
        ? 'Sign in again'
        : 'Retry';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unavailable
                  ? Icons.inventory_2_outlined
                  : Icons.cloud_off_outlined,
              size: 42,
              color: BearlyColors.brown700,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: unavailable
                  ? () => Navigator.pop(context)
                  : requiresSignIn
                  ? _signInAgain
                  : _loadProduct,
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productContent(BuyerCatalogProduct product) {
    final content = [
      _gallery(product),
      _details(product),
      _sellerCard(product),
      _description(product),
      _reviews(product),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
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
    );
  }

  Widget _gallery(BuyerCatalogProduct product) {
    final images = _imageUrls;
    final selectedUrl = images.isEmpty
        ? null
        : images[_selectedImageIndex.clamp(0, images.length - 1).toInt()];
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
          child: _networkImage(selectedUrl, fit: BoxFit.contain, iconSize: 64),
        ),
        if (images.isNotEmpty) ...[
          SizedBox(height: _compact ? 6 : 8),
          SizedBox(
            height: _compact ? 58 : 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => InkWell(
                key: ValueKey('buyer-detail-image-$index'),
                borderRadius: BorderRadius.circular(_compact ? 8 : 10),
                onTap: () => setState(() => _selectedImageIndex = index),
                child: Container(
                  width: _compact ? 58 : 68,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_compact ? 8 : 10),
                    border: Border.all(
                      color: index == _selectedImageIndex
                          ? BearlyColors.gold
                          : BearlyColors.lineSoft,
                      width: index == _selectedImageIndex ? 1.5 : 1,
                    ),
                  ),
                  child: _networkImage(images[index], fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _networkImage(
    String? url, {
    required BoxFit fit,
    double iconSize = 38,
  }) {
    if (url == null) return _imagePlaceholder(iconSize);
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) => _imagePlaceholder(iconSize),
    );
  }

  Widget _imagePlaceholder(double size) => ColoredBox(
    color: BearlyColors.cream200,
    child: Center(
      child: Icon(
        Icons.image_outlined,
        size: size,
        color: BearlyColors.brown500,
      ),
    ),
  );

  Widget _details(BuyerCatalogProduct product) {
    final variant = _selectedVariant;
    final price = variant?.formattedPrice ?? product.formattedPrice;
    final regularPrice =
        variant?.regularPriceMinor ?? product.regularPriceMinor;
    final currentPrice = variant?.priceMinor ?? product.priceMinor;
    final discount = variant?.discountPercent ?? product.discountPercent;
    final inStock = variant?.inStock ?? product.inStock;
    final regularPriceText = variant == null
        ? product.formattedRegularPrice
        : formatPriceMinorUnits(
            variant.regularPriceMinor,
            currency: variant.currency,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.category?.name ?? 'Category not available',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: BearlyColors.gold,
            fontSize: _compact ? 11.5 : null,
          ),
        ),
        SizedBox(height: _compact ? 3 : 5),
        Text(
          product.name,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontSize: _compact ? 25 : null),
        ),
        SizedBox(height: _compact ? 4 : 7),
        _ratingLine(product),
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
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                price,
                key: const ValueKey('buyer-detail-price'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: BearlyColors.brown950,
                  fontSize: _compact ? 24 : null,
                ),
              ),
              if (regularPrice > currentPrice)
                Text(
                  regularPriceText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BearlyColors.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              if (discount > 0)
                Text(
                  '$discount% off',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: BearlyColors.brown700,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: _compact ? 10 : 13),
        _availability(inStock),
        if (product.variants.isNotEmpty) ...[
          Divider(height: _compact ? 20 : 26),
          Text('Options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in product.variants)
                ChoiceChip(
                  key: ValueKey('buyer-variant-${item.id}'),
                  selected: item.id == _selectedVariantId,
                  onSelected: (_) => setState(() {
                    _selectedVariantId = item.id;
                  }),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _variantLabel(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.inStock ? item.formattedPrice : 'Out of stock',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        Divider(height: _compact ? 20 : 26),
        Row(
          children: [
            Expanded(
              child: _detailValue(
                'Store',
                product.store?.name ?? 'Unavailable',
              ),
            ),
            Expanded(
              child: _detailValue(
                'Availability',
                inStock ? 'In stock' : 'Out of stock',
              ),
            ),
          ],
        ),
        SizedBox(height: _compact ? 11 : 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showUnavailableAction('Add to cart'),
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
                onPressed: () => _showUnavailableAction('Buy Now'),
                style: _compact
                    ? FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      )
                    : null,
                child: const Text('Buy Now'),
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
                'Prices and availability come from the marketplace. Cart and checkout are not available yet.',
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

  Widget _ratingLine(BuyerCatalogProduct product) => Row(
    children: [
      for (var index = 1; index <= 5; index++)
        Icon(
          product.ratingSummary.average >= index
              ? Icons.star_rounded
              : product.ratingSummary.average >= index - .5
              ? Icons.star_half_rounded
              : Icons.star_border_rounded,
          color: BearlyColors.orange,
          size: _compact ? 17 : 19,
        ),
      SizedBox(width: _compact ? 5 : 7),
      Text(
        product.ratingSummary.average.toStringAsFixed(1),
        key: const ValueKey('buyer-detail-rating'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      SizedBox(width: _compact ? 8 : 10),
      Text(
        '(${product.ratingSummary.count})',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _availability(bool inStock) => Row(
    children: [
      Icon(
        inStock ? Icons.check_circle_outline : Icons.remove_circle_outline,
        size: 18,
        color: inStock ? Colors.green.shade700 : BearlyColors.muted,
      ),
      const SizedBox(width: 7),
      Text(
        inStock ? 'In stock' : 'Out of stock',
        key: const ValueKey('buyer-detail-availability'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );

  String _variantLabel(BuyerCatalogVariant variant) {
    if (variant.options.isEmpty) return variant.name;
    return variant.options.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
  }

  Widget _detailValue(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );

  Widget _sellerCard(BuyerCatalogProduct product) => Container(
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
          child: const Icon(Icons.storefront_outlined),
        ),
        SizedBox(width: _compact ? 9 : 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sold by', style: Theme.of(context).textTheme.bodySmall),
              Text(
                product.store?.name ?? 'Store details unavailable',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _showUnavailableAction('Contacting the seller'),
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

  Widget _description(BuyerCatalogProduct product) {
    final description = product.descriptionSummary.trim();
    return _section(
      'Product Description',
      Text(
        description.isEmpty ? 'No description provided.' : description,
        key: const ValueKey('buyer-detail-description'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      extra: product.category == null
          ? null
          : _detailValue('Category', product.category!.name),
    );
  }

  Widget _reviews(BuyerCatalogProduct product) => _section(
    'Ratings & Reviews',
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              product.ratingSummary.average.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: BearlyColors.gold,
                fontSize: _compact ? 26 : null,
              ),
            ),
            Text('out of 5', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        SizedBox(width: _compact ? 16 : 22),
        Expanded(
          child: Text(
            '${product.ratingSummary.count} ratings',
            style: Theme.of(context).textTheme.bodyMedium,
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
}
