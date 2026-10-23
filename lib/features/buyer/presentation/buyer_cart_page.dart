import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_cart_controller.dart';
import '../models/buyer_catalog_models.dart';
import '../models/buyer_shopping_models.dart';

class BuyerCartPage extends StatefulWidget {
  const BuyerCartPage({super.key, required this.cartController});

  final BuyerCartController cartController;

  @override
  State<BuyerCartPage> createState() => _BuyerCartPageState();
}

class _BuyerCartPageState extends State<BuyerCartPage> {
  @override
  void initState() {
    super.initState();
    widget.cartController.synchronizeSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.cartController.refresh(force: true));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const BearlyLogo(height: 34, width: 102),
    ),
    body: AnimatedBuilder(
      animation: widget.cartController,
      builder: (context, _) => _body(),
    ),
  );

  Widget _body() {
    final controller = widget.cartController;
    final cart = controller.cart;
    if (cart == null) {
      if (controller.isLoading) {
        return const Center(
          child: CircularProgressIndicator(key: ValueKey('buyer-cart-loading')),
        );
      }
      return _loadErrorState(controller.loadError);
    }

    return RefreshIndicator(
      onRefresh: () => controller.refresh(force: true),
      child: ListView(
        key: const ValueKey('buyer-cart-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        children: [
          Text('Your cart', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          Text(
            '${cart.cartCount} ${cart.cartCount == 1 ? 'item' : 'items'} in your cart',
            key: const ValueKey('buyer-cart-count'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
          ),
          if (controller.loadError != null) ...[
            const SizedBox(height: 10),
            _inlineError(controller.loadError!),
          ],
          const SizedBox(height: 14),
          if (cart.items.isEmpty)
            _emptyState()
          else ...[
            for (final item in cart.items) _itemCard(item, cart.currency),
            const SizedBox(height: 4),
            _subtotal(cart),
            const SizedBox(height: 9),
            Text(
              'This is the item subtotal from Bearly. Shipping and checkout are available in a later phase.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('buyer-cart-checkout-unavailable'),
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Checkout available later'),
            ),
            OutlinedButton.icon(
              onPressed: _continueShopping,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Continue shopping'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(BuyerCartItem item, String currency) {
    final controller = widget.cartController;
    final isPending =
        controller.isMutating && controller.pendingCartItemId == item.id;
    final isDisabled = controller.isMutating;
    final options = item.options.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
    final variantLabel = options.isNotEmpty
        ? options
        : item.variantName.isNotEmpty
        ? item.variantName
        : item.variant?.name ?? '';

    return Card(
      key: ValueKey('buyer-cart-item-${item.id}'),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 11),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _itemImage(item),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.storeName ?? item.sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (variantLabel.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          variantLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        formatPriceMinorUnits(
                          item.unitPriceMinor,
                          currency: currency,
                        ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: BearlyColors.brown700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('buyer-cart-remove-${item.id}'),
                  tooltip: 'Remove ${item.name}',
                  onPressed: isDisabled ? null : () => _confirmRemove(item),
                  icon: isPending && controller.pendingCartItemId == item.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Text(
                  'Line subtotal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                Text(
                  formatPriceMinorUnits(
                    item.lineSubtotalMinor,
                    currency: currency,
                  ),
                  key: ValueKey('buyer-cart-line-subtotal-${item.id}'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey('buyer-cart-quantity-minus-${item.id}'),
                  tooltip: 'Decrease quantity',
                  visualDensity: VisualDensity.compact,
                  onPressed: isDisabled || item.quantity <= 1
                      ? null
                      : () => _updateQuantity(item, item.quantity - 1),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                SizedBox(
                  width: 28,
                  child: isPending
                      ? const SizedBox(
                          key: ValueKey('buyer-cart-quantity-pending'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '${item.quantity}',
                          key: ValueKey('buyer-cart-quantity-${item.id}'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                ),
                IconButton(
                  key: ValueKey('buyer-cart-quantity-plus-${item.id}'),
                  tooltip: 'Increase quantity',
                  visualDensity: VisualDensity.compact,
                  onPressed: isDisabled || item.quantity >= 2147483647
                      ? null
                      : () => _updateQuantity(item, item.quantity + 1),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            if (!item.isAvailable) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: BearlyColors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.availableStock > 0
                          ? 'Only ${item.availableStock} available. Adjust the quantity before checkout.'
                          : 'This item is currently unavailable.',
                      key: ValueKey('buyer-cart-stock-warning-${item.id}'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BearlyColors.brown700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemImage(BuyerCartItem item) {
    final url = item.imageUrl?.trim().isNotEmpty == true
        ? item.imageUrl
        : item.image.trim().isNotEmpty
        ? item.image
        : null;
    if (url == null) return _imagePlaceholder();
    return Image.network(
      url,
      width: 68,
      height: 68,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() => Container(
    width: 68,
    height: 68,
    color: BearlyColors.cream200,
    child: const Icon(Icons.image_outlined, color: BearlyColors.brown500),
  );

  Widget _subtotal(BuyerCart cart) => Container(
    key: const ValueKey('buyer-cart-subtotal-panel'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BearlyColors.cream100,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Text('Subtotal', style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        Text(
          formatPriceMinorUnits(cart.subtotalMinor, currency: cart.currency),
          key: const ValueKey('buyer-cart-subtotal'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: BearlyColors.brown700),
        ),
      ],
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 88, 12, 42),
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
        const Text(
          'Add products from the marketplace to get started.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('buyer-cart-empty-shop'),
          onPressed: _continueShopping,
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Browse Shop'),
        ),
      ],
    ),
  );

  Widget _loadErrorState(Object? error) {
    final sessionError = _isSessionError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sessionError
                  ? Icons.lock_outline_rounded
                  : Icons.cloud_off_outlined,
              size: 42,
              color: BearlyColors.brown700,
            ),
            const SizedBox(height: 12),
            Text(
              buyerCartErrorMessage(
                error ?? const FormatException('Unknown cart error.'),
              ),
              key: const ValueKey('buyer-cart-load-error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: sessionError ? _signInAgain : _retry,
              child: Text(sessionError ? 'Sign in again' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineError(Object error) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: BearlyColors.cream100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(child: Text(buyerCartErrorMessage(error))),
        TextButton(onPressed: _retry, child: const Text('Retry')),
      ],
    ),
  );

  Future<void> _retry() => widget.cartController.refresh(force: true);

  bool _isSessionError(Object? error) =>
      error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403));

  void _signInAgain() => Navigator.pushNamedAndRemoveUntil(
    context,
    AppRouteNames.login,
    (_) => false,
  );

  Future<void> _updateQuantity(BuyerCartItem item, int quantity) async {
    try {
      await widget.cartController.updateQuantity(
        cartItemId: item.id,
        quantity: quantity,
      );
      if (mounted) _showMessage('Quantity updated.');
    } catch (error) {
      if (mounted) _showMutationError(error);
    }
  }

  Future<void> _confirmRemove(BuyerCartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this item?'),
        content: Text('${item.name} will be removed from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('buyer-cart-confirm-remove'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.cartController.removeItem(item.id);
      if (mounted) _showMessage('Item removed from your cart.');
    } catch (error) {
      if (mounted) _showMutationError(error);
    }
  }

  void _showMutationError(Object error) {
    final sessionError = _isSessionError(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(buyerCartErrorMessage(error)),
        action: sessionError
            ? SnackBarAction(label: 'Sign in', onPressed: _signInAgain)
            : null,
      ),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _continueShopping() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouteNames.buyer,
        (_) => false,
      );
    }
  }
}
