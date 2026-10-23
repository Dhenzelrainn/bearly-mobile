import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_catalog_repository.dart';
import '../models/buyer_catalog_models.dart';

class BuyerShopPage extends StatefulWidget {
  const BuyerShopPage({
    super.key,
    required this.repository,
    required this.onOpenProduct,
    required this.onUnavailableAction,
    required this.onSignInAgain,
  });

  final BuyerCatalogRepository repository;
  final ValueChanged<int> onOpenProduct;
  final ValueChanged<String> onUnavailableAction;
  final VoidCallback onSignInAgain;

  @override
  State<BuyerShopPage> createState() => _BuyerShopPageState();
}

class _BuyerShopPageState extends State<BuyerShopPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<BuyerCatalogProduct> _products = const [];
  List<BuyerCatalogCategory> _categories = const [];
  BuyerCatalogSort _sort = BuyerCatalogSort.featured;
  String? _selectedCategory;
  String _search = '';
  Object? _productError;
  bool _categoriesLoading = true;
  bool _categoriesFailed = false;
  bool _categoriesNeedSignIn = false;
  bool _productsLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 1;
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCategories());
    unawaited(_loadProducts(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesFailed = false;
      _categoriesNeedSignIn = false;
    });
    try {
      final categories = await widget.repository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoriesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoriesLoading = false;
        _categoriesFailed = true;
        _categoriesNeedSignIn = _needsSignIn(error);
      });
    }
  }

  void _onSearchChanged(String value) {
    _search = value;
    _searchDebounce?.cancel();
    _requestSequence++;
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadProducts(reset: true));
    });
  }

  Future<void> _loadProducts({required bool reset}) async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final sequence = ++_requestSequence;
    final page = reset ? 1 : _nextPage;
    setState(() {
      if (reset) {
        _productsLoading = true;
        _loadingMore = false;
        _products = const [];
        _hasMore = false;
      } else {
        _loadingMore = true;
      }
      _productError = null;
    });

    try {
      final result = await widget.repository.getProducts(
        search: _search,
        category: _selectedCategory,
        sort: _sort,
        page: page,
      );
      if (!mounted || sequence != _requestSequence) return;
      setState(() {
        if (reset) {
          _products = result.products;
        } else {
          final knownIds = _products.map((product) => product.id).toSet();
          _products = [
            ..._products,
            ...result.products.where((product) => knownIds.add(product.id)),
          ];
        }
        _nextPage = result.pagination.currentPage + 1;
        _hasMore = result.pagination.hasMore;
        _productsLoading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || sequence != _requestSequence) return;
      setState(() {
        _productError = error;
        _productsLoading = false;
        _loadingMore = false;
      });
    }
  }

  void _selectCategory(String? slug) {
    if (_selectedCategory == slug) return;
    setState(() => _selectedCategory = slug);
    unawaited(_loadProducts(reset: true));
  }

  void _selectSort(BuyerCatalogSort? sort) {
    if (sort == null || sort == _sort) return;
    setState(() => _sort = sort);
    unawaited(_loadProducts(reset: true));
  }

  bool _needsSignIn(Object? error) =>
      error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403));

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 8), trailing],
    ],
  );

  @override
  Widget build(BuildContext context) => ListView(
    controller: _scrollController,
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
        key: const ValueKey('buyer-catalog-search'),
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search products and stores',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 16),
      _promoCard(context),
      const SizedBox(height: 20),
      _sectionTitle(
        context,
        'Browse categories',
        trailing: _categoriesFailed
            ? TextButton(
                key: const ValueKey('buyer-category-retry'),
                onPressed: _categoriesNeedSignIn
                    ? widget.onSignInAgain
                    : _loadCategories,
                child: Text(_categoriesNeedSignIn ? 'Sign in' : 'Retry'),
              )
            : null,
      ),
      const SizedBox(height: 8),
      _categoryList(context),
      const SizedBox(height: 20),
      _sectionTitle(
        context,
        'Marketplace products',
        trailing: IconButton(
          tooltip: 'Refresh products',
          onPressed: () => _loadProducts(reset: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
      const SizedBox(height: 6),
      _sortSelector(context),
      const SizedBox(height: 10),
      _productResults(context),
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
            errorBuilder: (_, _, _) =>
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

  Widget _categoryList(BuildContext context) {
    if (_categoriesLoading && _categories.isEmpty) {
      return const SizedBox(
        height: 84,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_categoriesFailed && _categories.isEmpty) {
      return const SizedBox(
        height: 84,
        child: Center(child: Text('Categories are temporarily unavailable.')),
      );
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = index == 0 ? null : _categories[index - 1];
          final selected = _selectedCategory == category?.slug;
          final label = category?.name ?? 'All';
          return InkWell(
            key: ValueKey('buyer-category-${category?.slug ?? 'all'}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => _selectCategory(category?.slug),
            child: Container(
              width: 88,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? BearlyColors.cream200 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? BearlyColors.gold : BearlyColors.lineSoft,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    category == null
                        ? Icons.apps_rounded
                        : Icons.category_outlined,
                    color: BearlyColors.brown700,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sortSelector(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BearlyColors.lineSoft),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<BuyerCatalogSort>(
        key: const ValueKey('buyer-catalog-sort'),
        value: _sort,
        underline: const SizedBox.shrink(),
        onChanged: _selectSort,
        items: const [
          DropdownMenuItem(
            value: BuyerCatalogSort.featured,
            child: Text('Featured'),
          ),
          DropdownMenuItem(
            value: BuyerCatalogSort.newest,
            child: Text('Newest'),
          ),
          DropdownMenuItem(
            value: BuyerCatalogSort.priceLow,
            child: Text('Price: low to high'),
          ),
          DropdownMenuItem(
            value: BuyerCatalogSort.priceHigh,
            child: Text('Price: high to low'),
          ),
        ],
      ),
    ),
  );

  Widget _productResults(BuildContext context) {
    if (_productsLoading && _products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_productError != null && _products.isEmpty) {
      final requiresSignIn = _needsSignIn(_productError);
      return _messageCard(
        context,
        requiresSignIn
            ? 'Your session needs attention. Sign in again to browse products.'
            : 'We could not load products. Check your connection and try again.',
        actionLabel: requiresSignIn ? 'Sign in again' : 'Retry',
        onPressed: requiresSignIn
            ? widget.onSignInAgain
            : () => _loadProducts(reset: true),
      );
    }
    if (_products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            _search.trim().isNotEmpty || _selectedCategory != null
                ? 'No products match your filters.'
                : 'No products are available right now.',
          ),
        ),
      );
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _products.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            mainAxisExtent: 276,
          ),
          itemBuilder: (context, index) =>
              _productCard(context, _products[index]),
        ),
        if (_productError != null)
          _messageCard(
            context,
            _needsSignIn(_productError)
                ? 'Your session needs attention. Sign in again to continue.'
                : 'We could not load more products.',
            actionLabel: _needsSignIn(_productError)
                ? 'Sign in again'
                : 'Retry',
            onPressed: _needsSignIn(_productError)
                ? widget.onSignInAgain
                : () => _loadProducts(reset: false),
          ),
        if (_hasMore && _productError == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              key: const ValueKey('buyer-load-more'),
              onPressed: _loadingMore
                  ? null
                  : () => _loadProducts(reset: false),
              child: _loadingMore
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more'),
            ),
          ),
      ],
    );
  }

  Widget _messageCard(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onPressed,
  }) => Container(
    margin: const EdgeInsets.symmetric(vertical: 20),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: BearlyColors.lineSoft),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, color: BearlyColors.brown700),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    ),
  );

  Widget _productCard(BuildContext context, BuyerCatalogProduct product) {
    final categoryName = product.category?.name ?? 'Marketplace';
    final storeName = product.store?.name ?? 'Store details unavailable';
    return GestureDetector(
      key: ValueKey('buyer-product-${product.id}'),
      onTap: () => widget.onOpenProduct(product.id),
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
                  child: _catalogImage(product.imageUrl),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filledTonal(
                    key: ValueKey('buyer-save-${product.id}'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        widget.onUnavailableAction('Saving products'),
                    icon: const Icon(Icons.favorite_border_rounded, size: 19),
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
                    categoryName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.formattedPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: BearlyColors.brown700),
                        ),
                      ),
                      IconButton.filled(
                        key: ValueKey('buyer-add-cart-${product.id}'),
                        tooltip: 'Choose options and add to cart',
                        onPressed: () => widget.onOpenProduct(product.id),
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

  Widget _catalogImage(String? url) {
    if (url == null) return _imagePlaceholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() => const ColoredBox(
    color: BearlyColors.cream200,
    child: Center(
      child: Icon(Icons.image_outlined, color: BearlyColors.brown500, size: 38),
    ),
  );
}
