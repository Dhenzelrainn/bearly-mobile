import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_address_controller.dart';
import '../data/buyer_checkout_review_controller.dart';
import '../data/buyer_location_repository.dart';
import '../models/buyer_catalog_models.dart';
import '../models/buyer_checkout_models.dart';
import '../models/buyer_shopping_models.dart';
import 'buyer_address_form_page.dart';

class BuyerCheckoutReviewPage extends StatefulWidget {
  const BuyerCheckoutReviewPage({
    super.key,
    required this.reviewController,
    required this.addressController,
    required this.locationRepository,
  });

  final BuyerCheckoutReviewController reviewController;
  final BuyerAddressController addressController;
  final BuyerLocationRepository locationRepository;

  @override
  State<BuyerCheckoutReviewPage> createState() =>
      _BuyerCheckoutReviewPageState();
}

class _BuyerCheckoutReviewPageState extends State<BuyerCheckoutReviewPage> {
  BuyerCheckoutReviewController get controller => widget.reviewController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.initialize());
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const ValueKey('buyer-checkout-review-back'),
        tooltip: 'Back to cart',
        onPressed: _returnToCart,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Checkout Review'),
    ),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _body(),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _bottomAction(),
      ),
    ),
  );

  Widget _body() {
    final cart = controller.cartController.cart;
    if (cart == null && controller.isInitializing) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('buyer-checkout-review-loading'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refreshInputs,
      child: ListView(
        key: const ValueKey('buyer-checkout-review-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Text(
            'Review your checkout',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            'Bearly confirms current prices, delivery fees, and promotions when it calculates your quote.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
          ),
          const SizedBox(height: 16),
          _addressSection(),
          const SizedBox(height: 14),
          _selectionSection(),
          const SizedBox(height: 14),
          if (controller.isQuoting) ...[
            const LinearProgressIndicator(
              key: ValueKey('buyer-checkout-quote-progress'),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('Requesting your current checkout quote…'),
            ),
            const SizedBox(height: 12),
          ],
          if (controller.localError != null)
            _notice(
              key: const ValueKey('buyer-checkout-local-error'),
              message: controller.localError!,
            ),
          if (controller.quoteError case final error?) ...[
            _notice(
              key: const ValueKey('buyer-checkout-quote-error'),
              message: controller.quoteErrorMessage(error),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('buyer-checkout-quote-retry'),
                onPressed: controller.canRequestQuote
                    ? controller.requestQuote
                    : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry quote'),
              ),
            ),
            if (controller.quoteNeedsSignIn)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('buyer-checkout-sign-in'),
                  onPressed: _signInAgain,
                  child: const Text('Sign in again'),
                ),
              ),
          ],
          if (controller.isQuoteExpired)
            _notice(
              key: const ValueKey('buyer-checkout-quote-expired'),
              message:
                  'The previous quote expired. Request a fresh quote to see current totals.',
            ),
          if (controller.quote case final quote?) ...[
            const SizedBox(height: 14),
            _quoteContent(quote),
          ],
          if (controller.addressLoadError != null &&
              controller.addresses == null) ...[
            const SizedBox(height: 12),
            _notice(
              key: const ValueKey('buyer-checkout-address-error'),
              message: buyerAddressErrorMessage(controller.addressLoadError!),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('buyer-checkout-address-retry'),
                onPressed: controller.refreshAddresses,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry addresses'),
              ),
            ),
            if (_isSessionError(controller.addressLoadError))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('buyer-checkout-address-sign-in'),
                  onPressed: _signInAgain,
                  child: const Text('Sign in again'),
                ),
              ),
          ],
          if (controller.cartController.loadError != null && cart == null)
            _notice(
              key: const ValueKey('buyer-checkout-cart-error'),
              message:
                  'Your Cart could not be loaded. Return to Cart and refresh before checkout.',
            ),
        ],
      ),
    );
  }

  Widget _addressSection() {
    final addresses = controller.addresses;
    final selected = controller.selectedAddress;
    return _sectionCard(
      title: 'Delivery address',
      trailing: addresses != null && addresses.isNotEmpty
          ? TextButton(
              key: const ValueKey('buyer-checkout-change-address'),
              onPressed: controller.isLoadingAddresses ? null : _chooseAddress,
              child: Text(selected == null ? 'Choose' : 'Change'),
            )
          : null,
      child: controller.isLoadingAddresses && addresses == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            )
          : addresses == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.addressLoadError != null
                      ? 'Saved addresses are unavailable.'
                      : controller.hasBuyerSession
                      ? 'Saved addresses are not available yet.'
                      : 'Sign in with a Buyer account to review checkout.',
                ),
                if (!controller.hasBuyerSession &&
                    controller.addressLoadError == null)
                  TextButton(
                    key: const ValueKey('buyer-checkout-address-sign-in'),
                    onPressed: _signInAgain,
                    child: const Text('Sign in again'),
                  ),
              ],
            )
          : addresses.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No saved delivery addresses.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('buyer-checkout-add-address'),
                  onPressed: _addAddress,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add address'),
                ),
              ],
            )
          : selected == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose a saved address to request a quote.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('buyer-checkout-choose-address'),
                  onPressed: _chooseAddress,
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Choose address'),
                ),
              ],
            )
          : _addressContent(
              name: selected.name,
              phone: selected.phone,
              label: selected.label,
              street: selected.street,
              barangay: selected.barangay,
              city: selected.city,
              province: selected.province,
              postal: selected.postal,
              isDefault: selected.isDefault,
            ),
    );
  }

  Widget _selectionSection() {
    final cart = controller.cartController.cart;
    final selectedItems = controller.cartController.selectedItems;
    if (selectedItems.isEmpty) {
      return _sectionCard(
        title: 'Selected products',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cart == null || cart.items.isEmpty
                  ? 'Your Cart has no items yet.'
                  : 'No Cart items are selected for this checkout.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('buyer-checkout-change-items'),
              onPressed: _returnToCart,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Change selected items'),
            ),
          ],
        ),
      );
    }
    return _sectionCard(
      title: 'Selected products',
      trailing: TextButton(
        key: const ValueKey('buyer-checkout-change-items'),
        onPressed: _returnToCart,
        child: const Text('Change items'),
      ),
      child: Text(
        '${controller.cartController.selectedCount} selected Cart ${controller.cartController.selectedCount == 1 ? 'item' : 'items'} · ${controller.cartController.selectedQuantityCount} ${controller.cartController.selectedQuantityCount == 1 ? 'unit' : 'units'}',
        key: const ValueKey('buyer-checkout-selected-count'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _quoteContent(BuyerCheckoutQuote quote) {
    final cartItems = {
      for (final item in controller.cartController.selectedItems) item.id: item,
    };
    final groupsByName = <String, List<BuyerCheckoutSellerGroup>>{};
    for (final group in quote.sellerOrders) {
      groupsByName
          .putIfAbsent(_normalize(group.storeName), () => [])
          .add(group);
    }

    final itemsByStore = <int, List<BuyerCheckoutQuoteItem>>{};
    final unassigned = <BuyerCheckoutQuoteItem>[];
    for (final item in quote.items) {
      final cartItem = cartItems[item.cartItemId];
      final matchingGroups = cartItem?.storeName == null
          ? null
          : groupsByName[_normalize(cartItem!.storeName!)];
      if (matchingGroups != null && matchingGroups.length == 1) {
        itemsByStore
            .putIfAbsent(matchingGroups.single.storeId, () => [])
            .add(item);
      } else {
        unassigned.add(item);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Seller orders',
          child: Column(
            children: [
              for (
                var index = 0;
                index < quote.sellerOrders.length;
                index++
              ) ...[
                if (index > 0) const Divider(height: 22),
                _sellerGroup(
                  quote.sellerOrders[index],
                  itemsByStore[quote.sellerOrders[index].storeId] ?? const [],
                  cartItems,
                  quote.currency,
                ),
              ],
              if (unassigned.isNotEmpty) ...[
                if (quote.sellerOrders.isNotEmpty) const Divider(height: 22),
                _unassignedItems(unassigned, cartItems, quote.currency),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Shipping and promotions',
          child: Column(
            children: [
              _amountRow(
                'Items subtotal',
                quote.subtotalMinor,
                quote.currency,
                key: const ValueKey('buyer-checkout-subtotal'),
              ),
              _amountRow(
                'Seller discounts',
                quote.sellerDiscountMinor,
                quote.currency,
                key: const ValueKey('buyer-checkout-seller-discount'),
              ),
              _amountRow(
                'Platform discounts',
                quote.platformDiscountMinor,
                quote.currency,
                key: const ValueKey('buyer-checkout-platform-discount'),
              ),
              _amountRow(
                'Shipping fees',
                quote.shippingFeeMinor,
                quote.currency,
                key: const ValueKey('buyer-checkout-shipping'),
              ),
              _amountRow(
                'Shipping discounts',
                quote.shippingDiscountMinor,
                quote.currency,
                key: const ValueKey('buyer-checkout-shipping-discount'),
              ),
              _amountRow(
                'Total discounts',
                quote.totalDiscountMinor,
                quote.currency,
                key: const ValueKey('buyer-checkout-total-discount'),
              ),
              if (quote.appliedPromotions.isNotEmpty) ...[
                const Divider(height: 20),
                for (final promotion in quote.appliedPromotions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.local_offer_outlined),
                    title: Text(promotion.name),
                    subtitle: Text(
                      promotion.source == 'platform'
                          ? 'Bearly promotion'
                          : 'Seller promotion',
                    ),
                    trailing: Text(
                      formatPriceMinorUnits(
                        promotion.discountMinor +
                            promotion.shippingDiscountMinor,
                        currency: quote.currency,
                      ),
                    ),
                  ),
              ],
              const Divider(height: 22),
              _amountRow(
                'Total payable',
                quote.totalMinor,
                quote.currency,
                key: const ValueKey('buyer-checkout-total'),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Payment method',
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, color: BearlyColors.brown700),
              const SizedBox(width: 10),
              const Expanded(child: Text('Cash on Delivery (COD)')),
              if (quote.paymentMethod == 'cod')
                const Icon(Icons.check_circle, color: BearlyColors.success),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Delivery summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _addressContent(
                name: quote.deliveryAddress.name,
                phone: quote.deliveryAddress.phone,
                label: 'Quoted address',
                street: quote.deliveryAddress.street,
                barangay: quote.deliveryAddress.barangay,
                city: quote.deliveryAddress.city,
                province: quote.deliveryAddress.province,
                postal: quote.deliveryAddress.postal ?? '',
                isDefault: quote.deliveryAddress.isDefault,
              ),
              const SizedBox(height: 10),
              Text(
                '${quote.items.length} selected ${quote.items.length == 1 ? 'Cart item' : 'Cart items'} · Cash on Delivery',
                key: const ValueKey('buyer-checkout-final-summary'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This quote is for review only. Order placement is not available yet.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
        ),
      ],
    );
  }

  Widget _sellerGroup(
    BuyerCheckoutSellerGroup group,
    List<BuyerCheckoutQuoteItem> items,
    Map<int, BuyerCartItem> cartItems,
    String currency,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.storefront_outlined, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              group.storeName,
              key: ValueKey('buyer-checkout-seller-${group.storeId}'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text('${group.itemCount} ${group.itemCount == 1 ? 'item' : 'items'}'),
        ],
      ),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Product-to-Seller detail is unavailable for this response.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )
      else
        for (final item in items)
          _quoteItem(item, cartItems[item.cartItemId], currency),
      const SizedBox(height: 8),
      _amountRow('Seller item subtotal', group.subtotalMinor, currency),
      _amountRow('Seller discounts', group.sellerDiscountMinor, currency),
      _amountRow('Platform discounts', group.platformDiscountMinor, currency),
      _amountRow('Shipping fee', group.shippingFeeMinor, currency),
      _amountRow('Shipping discount', group.shippingDiscountMinor, currency),
      _amountRow('Seller total', group.totalMinor, currency, emphasize: true),
    ],
  );

  Widget _unassignedItems(
    List<BuyerCheckoutQuoteItem> items,
    Map<int, BuyerCartItem> cartItems,
    String currency,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Selected products', style: Theme.of(context).textTheme.titleMedium),
      const Padding(
        padding: EdgeInsets.only(top: 5),
        child: Text(
          'The quote did not provide an unambiguous Seller match for these Cart lines. Server totals below remain authoritative.',
        ),
      ),
      for (final item in items)
        _quoteItem(item, cartItems[item.cartItemId], currency),
    ],
  );

  Widget _quoteItem(
    BuyerCheckoutQuoteItem item,
    BuyerCartItem? cartItem,
    String currency,
  ) {
    final options = item.options.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
    final variant = options.isNotEmpty ? options : item.variantName;
    final imageUrl = cartItem?.imageUrl?.trim().isNotEmpty == true
        ? cartItem!.imageUrl
        : cartItem?.image.trim().isNotEmpty == true
        ? cartItem!.image
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl == null
                ? Container(
                    width: 58,
                    height: 58,
                    color: BearlyColors.cream200,
                    child: const Icon(Icons.image_outlined),
                  )
                : Image.network(
                    imageUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 58,
                      height: 58,
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
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (variant.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    variant,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 3),
                Text('Qty ${item.quantity}'),
                Text(
                  'Unit ${formatPriceMinorUnits(item.unitPriceMinor, currency: currency)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPriceMinorUnits(item.totalMinor, currency: currency),
                key: ValueKey('buyer-checkout-line-total-${item.cartItemId}'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (item.totalDiscountMinor > 0)
                Text(
                  '−${formatPriceMinorUnits(item.totalDiscountMinor, currency: currency)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BearlyColors.success),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addressContent({
    required String name,
    required String phone,
    required String label,
    required String street,
    required String barangay,
    required String city,
    required String province,
    required String postal,
    required bool isDefault,
  }) {
    final locality = [
      barangay,
      city,
      province,
      postal,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleSmall),
            if (label.isNotEmpty)
              Chip(
                label: Text(label),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            if (isDefault)
              const Chip(
                label: Text('Default'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        if (phone.trim().isNotEmpty) Text(phone),
        if (street.trim().isNotEmpty) Text(street),
        if (locality.isNotEmpty)
          Text(locality, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) => Card(
    color: Colors.white,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );

  Widget _amountRow(
    String label,
    int amount,
    String currency, {
    Key? key,
    bool emphasize = false,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasize ? Theme.of(context).textTheme.titleMedium : null,
          ),
        ),
        Text(
          formatPriceMinorUnits(amount, currency: currency),
          style: emphasize
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BearlyColors.brown700,
                  fontWeight: FontWeight.bold,
                )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );

  Widget _notice({required Key key, required String message}) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: BearlyColors.cream100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: BearlyColors.cream300),
    ),
    child: Text(message),
  );

  Widget _bottomAction() {
    final quote = controller.quote;
    final canRequest = controller.canRequestQuote;
    final label = controller.isQuoting
        ? 'Calculating quote…'
        : quote == null
        ? 'Request checkout quote'
        : 'Refresh checkout quote';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Server quoted total payable')),
                  Text(
                    formatPriceMinorUnits(
                      quote.totalMinor,
                      currency: quote.currency,
                    ),
                    key: const ValueKey('buyer-checkout-bottom-total'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BearlyColors.brown700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            key: const ValueKey('buyer-checkout-request-quote'),
            onPressed: canRequest ? controller.requestQuote : null,
            icon: controller.isQuoting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long_outlined),
            label: Text(label),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('buyer-checkout-return-to-cart'),
            onPressed: _returnToCart,
            child: const Text('Return to Cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseAddress() async {
    final addresses = controller.addresses ?? const <BuyerAddress>[];
    final selectedId = controller.selectedAddressId;
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose delivery address',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final address in addresses)
                      ListTile(
                        key: ValueKey(
                          'buyer-checkout-address-option-${address.id}',
                        ),
                        onTap: () => Navigator.pop(sheetContext, address.id),
                        title: Text(address.name),
                        subtitle: Text(
                          [
                            address.street,
                            address.barangay,
                            address.city,
                            address.province,
                            address.postal,
                          ].where((part) => part.trim().isNotEmpty).join(', '),
                        ),
                        leading: Icon(
                          address.id == selectedId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: address.id == selectedId
                              ? BearlyColors.brown700
                              : BearlyColors.muted,
                        ),
                        trailing: address.isDefault
                            ? const Icon(Icons.star_outline_rounded)
                            : null,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: OutlinedButton.icon(
                        key: const ValueKey('buyer-checkout-add-address'),
                        onPressed: () => Navigator.pop(sheetContext, -1),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add address'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == -1) {
      await _addAddress();
    } else {
      controller.selectAddress(result);
    }
  }

  Future<void> _addAddress() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BuyerAddressFormPage(
          controller: widget.addressController,
          locationRepository: widget.locationRepository,
        ),
      ),
    );
    if (!mounted) return;
    await controller.refreshAddresses();
  }

  void _returnToCart() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRouteNames.buyerCart);
    }
  }

  void _signInAgain() => Navigator.pushNamedAndRemoveUntil(
    context,
    AppRouteNames.login,
    (_) => false,
  );

  bool _isSessionError(Object? error) =>
      error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403));

  String _normalize(String value) => value.trim().toLowerCase();
}
