import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_wishlist_controller.dart';
import '../models/buyer_catalog_models.dart';
import 'buyer_wishlist_heart_button.dart';

class BuyerSavedPage extends StatefulWidget {
  const BuyerSavedPage({
    super.key,
    required this.controller,
    required this.isActive,
    required this.onOpenProduct,
    required this.onWishlistError,
    required this.onSignInAgain,
  });

  final BuyerWishlistController controller;
  final bool isActive;
  final ValueChanged<int> onOpenProduct;
  final ValueChanged<Object> onWishlistError;
  final VoidCallback onSignInAgain;

  @override
  State<BuyerSavedPage> createState() => _BuyerSavedPageState();
}

class _BuyerSavedPageState extends State<BuyerSavedPage> {
  @override
  void initState() {
    super.initState();
    if (widget.isActive) _refreshAfterBuild();
  }

  @override
  void didUpdateWidget(covariant BuyerSavedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _refreshAfterBuild(force: true);
    }
  }

  void _refreshAfterBuild({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) {
        unawaited(widget.controller.refresh(force: force));
      }
    });
  }

  Future<void> _refresh() => widget.controller.refresh(force: true);

  Future<void> _remove(BuyerCatalogProduct product) async {
    try {
      await widget.controller.setSaved(product.id, false, product: product);
    } catch (error) {
      widget.onWishlistError(error);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final products = controller.products;
      final initialLoading = controller.isLoading && products.isEmpty;
      final failedWithoutProducts =
          controller.loadError != null && products.isEmpty;

      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              'Saved products',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Keep the things you want to come back to.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
            ),
            const SizedBox(height: 14),
            if (controller.isLoading && products.isNotEmpty)
              const LinearProgressIndicator(
                key: ValueKey('buyer-wishlist-refreshing'),
              ),
            if (controller.loadError != null && products.isNotEmpty)
              _inlineError(context, controller.loadError!),
            if (initialLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (failedWithoutProducts)
              _retryState(context, controller.loadError!)
            else if (!controller.isLoading &&
                controller.loadError == null &&
                controller.membershipLoaded &&
                products.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 42,
                        color: BearlyColors.muted,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No saved products yet.',
                        key: ValueKey('buyer-wishlist-empty'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              for (final product in products)
                _savedProductCard(context, product),
              if (controller.hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 18),
                  child: OutlinedButton.icon(
                    key: const ValueKey('buyer-wishlist-load-more'),
                    onPressed: controller.isLoading
                        ? null
                        : controller.loadMore,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                      'Load more (${controller.visiblePage}/${controller.totalPages})',
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );

  Widget _savedProductCard(
    BuildContext context,
    BuyerCatalogProduct product,
  ) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(9),
      child: Row(
        children: [
          _productImage(product),
          const SizedBox(width: 11),
          Expanded(
            child: InkWell(
              key: ValueKey('buyer-saved-open-${product.id}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onOpenProduct(product.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.store?.name ?? 'Store details unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BearlyColors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.formattedPrice,
                      key: ValueKey('buyer-saved-price-${product.id}'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: BearlyColors.brown700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.inStock ? 'In stock' : 'Out of stock',
                      key: ValueKey('buyer-saved-availability-${product.id}'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: product.inStock
                            ? Colors.green.shade700
                            : BearlyColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          BuyerWishlistHeartButton(
            key: ValueKey('buyer-saved-remove-${product.id}'),
            controller: widget.controller,
            productId: product.id,
            onPressed: () => unawaited(_remove(product)),
            iconSize: 20,
          ),
        ],
      ),
    ),
  );

  Widget _productImage(BuyerCatalogProduct product) {
    final url = product.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 76,
        height: 76,
        child: url == null || Uri.tryParse(url)?.scheme != 'https'
            ? _imageFallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imageFallback(),
              ),
      ),
    );
  }

  Widget _imageFallback() => Container(
    color: BearlyColors.cream200,
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, color: BearlyColors.muted),
  );

  Widget _retryState(BuildContext context, Object error) {
    final needsSignIn =
        error is AuthException ||
        (error is ApiHttpException &&
            (error.statusCode == 401 || error.statusCode == 403));
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 10),
            Text(
              buyerWishlistErrorMessage(error),
              key: const ValueKey('buyer-wishlist-error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('buyer-wishlist-retry'),
              onPressed: needsSignIn
                  ? widget.onSignInAgain
                  : () => unawaited(_refresh()),
              icon: Icon(
                needsSignIn ? Icons.login_rounded : Icons.refresh_rounded,
              ),
              label: Text(needsSignIn ? 'Sign in again' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineError(BuildContext context, Object error) => Container(
    key: const ValueKey('buyer-wishlist-inline-error'),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: BearlyColors.cream200,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            buyerWishlistErrorMessage(error),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(
          onPressed: () => unawaited(_refresh()),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
