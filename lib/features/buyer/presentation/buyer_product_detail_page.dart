import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_cart_controller.dart';
import '../data/buyer_catalog_repository.dart';
import '../data/buyer_wishlist_controller.dart';
import '../models/buyer_catalog_models.dart';
import 'buyer_wishlist_heart_button.dart';

class BuyerProductDetailPage extends StatefulWidget {
  const BuyerProductDetailPage({
    super.key,
    required this.productId,
    required this.repository,
    required this.cartController,
    required this.wishlistController,
  });

  final int productId;
  final BuyerCatalogRepository repository;
  final BuyerCartController cartController;
  final BuyerWishlistController wishlistController;

  @override
  State<BuyerProductDetailPage> createState() => _BuyerProductDetailPageState();
}

class _BuyerProductDetailPageState extends State<BuyerProductDetailPage> {
  BuyerCatalogProduct? _product;
  Object? _error;
  int? _selectedVariantId;
  Map<String, Object?> _selectedOptions = const {};
  int _selectedImageIndex = 0;
  int _requestSequence = 0;
  int _quantity = 1;
  bool _loading = true;
  bool _addingToCart = false;

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
    widget.cartController.synchronizeSession();
    widget.wishlistController.synchronizeSession();
    if (!widget.wishlistController.membershipLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.wishlistController.membershipLoaded) {
          unawaited(widget.wishlistController.refresh());
        }
      });
    }
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
      final variantImageIndex = selected == null
          ? -1
          : product.images.indexWhere(
              (image) => image.variantId == selected.id,
            );
      setState(() {
        _product = product;
        _selectedVariantId = selected?.id;
        _selectedOptions = Map.unmodifiable(selected?.options ?? const {});
        _selectedImageIndex = variantImageIndex >= 0
            ? variantImageIndex
            : primaryImageIndex < 0
            ? 0
            : primaryImageIndex;
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

  List<_VariantOptionGroup>? _structuredOptionGroups(
    List<BuyerCatalogVariant> variants,
  ) {
    if (variants.isEmpty || variants.first.options.isEmpty) return null;
    final keys = variants.first.options.keys.toList(growable: false);
    if (keys.any((key) => key.trim().isEmpty)) return null;

    bool isScalar(Object? value) =>
        value is String || value is num || value is bool;

    for (final variant in variants) {
      if (variant.options.length != keys.length ||
          !keys.every(
            (key) => variant.options.keys.any(
              (candidate) => _sameOptionKeyKey(key, candidate),
            ),
          ) ||
          !variant.options.values.every(isScalar)) {
        return null;
      }
    }

    return [
      for (final key in keys)
        _VariantOptionGroup(
          key: key,
          label: key,
          values: [
            for (final variant in variants)
              if (!_valueAlreadyAdded(
                variants,
                key,
                _optionValue(variant.options, key),
                beforeVariant: variant,
              ))
                _optionValue(variant.options, key)!,
          ],
        ),
    ];
  }

  bool _sameOptionKeyKey(String key, String candidate) =>
      key.toLowerCase() == candidate.toLowerCase();

  bool _valueAlreadyAdded(
    List<BuyerCatalogVariant> variants,
    String key,
    Object? value, {
    required BuyerCatalogVariant beforeVariant,
  }) {
    for (final variant in variants) {
      if (identical(variant, beforeVariant)) return false;
      final candidate = _optionValue(variant.options, key);
      if (candidate.runtimeType == value.runtimeType && candidate == value) {
        return true;
      }
    }
    return false;
  }

  Object? _optionValue(Map<String, Object?> options, String key) {
    for (final entry in options.entries) {
      if (_sameOptionKeyKey(key, entry.key)) return entry.value;
    }
    return null;
  }

  BuyerCatalogVariant? _resolveVariant(
    List<BuyerCatalogVariant> variants,
    Map<String, Object?> options,
  ) {
    if (options.isEmpty) return null;
    final matches = variants
        .where((variant) {
          if (variant.options.length != options.length) return false;
          return options.entries.every((selection) {
            final value = _optionValue(variant.options, selection.key);
            return value != null &&
                value.runtimeType == selection.value.runtimeType &&
                value == selection.value;
          });
        })
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  void _selectOption(String key, Object value, BuyerCatalogProduct product) {
    final nextOptions = Map<String, Object?>.of(_selectedOptions)
      ..[key] = value;
    final variant = _resolveVariant(product.variants, nextOptions);
    setState(() {
      _selectedOptions = Map.unmodifiable(nextOptions);
      _selectedVariantId = variant?.id;
      if (variant != null) _selectVariantImage(variant);
    });
  }

  void _selectVariant(BuyerCatalogVariant variant) {
    setState(() {
      _selectedVariantId = variant.id;
      _selectedOptions = Map.unmodifiable(variant.options);
      _selectVariantImage(variant);
    });
  }

  void _selectVariantImage(BuyerCatalogVariant variant) {
    final imageIndex = _product?.images.indexWhere(
      (image) => image.variantId == variant.id,
    );
    if (imageIndex != null && imageIndex >= 0) _selectedImageIndex = imageIndex;
  }

  bool _variantCanBeAdded(BuyerCatalogProduct product) {
    final variant = _selectedVariant;
    return !_addingToCart &&
        !widget.cartController.isMutating &&
        product.variants.isNotEmpty &&
        variant != null &&
        variant.inStock;
  }

  Future<void> _addToCart(BuyerCatalogProduct product) async {
    final variant = _selectedVariant;
    if (variant == null || !variant.inStock || _addingToCart) return;
    setState(() => _addingToCart = true);
    try {
      await widget.cartController.addItem(
        productVariantId: variant.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to your cart.')));
    } catch (error) {
      if (!mounted) return;
      if (_needsSignIn(error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(buyerCartErrorMessage(error)),
            action: SnackBarAction(label: 'Sign in', onPressed: _signInAgain),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(buyerCartErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  Future<void> _toggleWishlist(BuyerCatalogProduct product) async {
    final wasSaved = widget.wishlistController.isSaved(product.id) == true;
    try {
      final saved = await widget.wishlistController.toggleProduct(product);
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved
                ? 'Removed from saved products.'
                : 'Added to saved products.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final needsSignIn = _needsSignIn(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(buyerWishlistErrorMessage(error)),
          action: needsSignIn
              ? SnackBarAction(label: 'Sign in', onPressed: _signInAgain)
              : null,
        ),
      );
    }
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
    final optionGroups = _structuredOptionGroups(product.variants);
    final combinationUnavailable =
        optionGroups != null && _selectedOptions.isNotEmpty && variant == null;
    final price = combinationUnavailable
        ? 'Unavailable'
        : variant?.formattedPrice ?? product.formattedPrice;
    final regularPrice = combinationUnavailable
        ? 0
        : variant?.regularPriceMinor ?? product.regularPriceMinor;
    final currentPrice = combinationUnavailable
        ? 0
        : variant?.priceMinor ?? product.priceMinor;
    final discount = combinationUnavailable
        ? 0
        : variant?.discountPercent ?? product.discountPercent;
    final inStock =
        !combinationUnavailable && (variant?.inStock ?? product.inStock);
    final regularPriceText = variant == null || combinationUnavailable
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                product.name,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: _compact ? 25 : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            BuyerWishlistHeartButton(
              key: ValueKey('buyer-detail-save-${product.id}'),
              controller: widget.wishlistController,
              productId: product.id,
              onPressed: () => unawaited(_toggleWishlist(product)),
            ),
          ],
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
        if (combinationUnavailable)
          const Row(
            key: ValueKey('buyer-detail-combination-unavailable'),
            children: [
              Icon(
                Icons.remove_circle_outline,
                size: 18,
                color: BearlyColors.muted,
              ),
              SizedBox(width: 7),
              Expanded(child: Text('This combination is unavailable.')),
            ],
          )
        else
          _availability(inStock),
        if (product.variants.isNotEmpty) ...[
          Divider(height: _compact ? 20 : 26),
          if (optionGroups != null)
            for (final group in optionGroups) ...[
              Text(group.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 5),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  for (final value in group.values)
                    _optionChoice(product, group, value),
                ],
              ),
              const SizedBox(height: 9),
            ]
          else if (product.variants.length > 1) ...[
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
                    onSelected: (_) => _selectVariant(item),
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
        _quantitySelector(),
        SizedBox(height: _compact ? 8 : 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('buyer-detail-add-to-cart'),
                onPressed: _variantCanBeAdded(product)
                    ? () => _addToCart(product)
                    : null,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(_addingToCart ? 'Adding…' : 'Add to Cart'),
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
                'Price and availability come from the marketplace. Checkout will be available in a later phase.',
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

  Widget _optionChoice(
    BuyerCatalogProduct product,
    _VariantOptionGroup group,
    Object value,
  ) {
    final status = _optionStatus(product, group.key, value);
    final selectedValue = _optionValue(_selectedOptions, group.key);
    final selected =
        selectedValue?.runtimeType == value.runtimeType &&
        selectedValue == value;
    final label = _displayOption(value);
    return ChoiceChip(
      key: ValueKey(
        'buyer-option-${_optionKeyPart(group.label)}-${_optionKeyPart(label)}',
      ),
      selected: selected,
      onSelected: (_) => _selectOption(group.key, value, product),
      label: Text(status == null ? label : '$label · $status'),
      labelStyle: status == null
          ? null
          : const TextStyle(color: BearlyColors.muted),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String? _optionStatus(
    BuyerCatalogProduct product,
    String optionKey,
    Object value,
  ) {
    final compatible = product.variants
        .where((variant) {
          final optionValue = _optionValue(variant.options, optionKey);
          if (optionValue?.runtimeType != value.runtimeType ||
              optionValue != value) {
            return false;
          }
          return _selectedOptions.entries
              .where(
                (selection) => !_sameOptionKeyKey(selection.key, optionKey),
              )
              .every((selection) {
                final candidate = _optionValue(variant.options, selection.key);
                return candidate?.runtimeType == selection.value.runtimeType &&
                    candidate == selection.value;
              });
        })
        .toList(growable: false);

    if (compatible.isEmpty) return 'Unavailable';
    if (compatible.every((variant) => !variant.inStock)) return 'Out of stock';
    return null;
  }

  String _displayOption(Object value) =>
      value is bool ? (value ? 'Yes' : 'No') : value.toString();

  String _optionKeyPart(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');

  Widget _quantitySelector() => Row(
    children: [
      Expanded(
        child: Text('Quantity', style: Theme.of(context).textTheme.titleSmall),
      ),
      IconButton(
        key: const ValueKey('buyer-detail-quantity-minus'),
        tooltip: 'Decrease quantity',
        visualDensity: VisualDensity.compact,
        onPressed: _quantity <= 1 ? null : () => setState(() => _quantity--),
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      SizedBox(
        width: 34,
        child: Text(
          '$_quantity',
          key: const ValueKey('buyer-detail-quantity'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        key: const ValueKey('buyer-detail-quantity-plus'),
        tooltip: 'Increase quantity',
        visualDensity: VisualDensity.compact,
        onPressed: _quantity >= 2147483647
            ? null
            : () => setState(() => _quantity++),
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
    ],
  );

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
            '${product.ratingSummary.count} ${product.ratingSummary.count == 1 ? 'rating' : 'ratings'}',
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

class _VariantOptionGroup {
  const _VariantOptionGroup({
    required this.key,
    required this.label,
    required this.values,
  });

  final String key;
  final String label;
  final List<Object> values;
}
