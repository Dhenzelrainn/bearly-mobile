import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_address_controller.dart';
import '../data/buyer_checkout_placement_controller.dart';
import '../data/buyer_checkout_repository.dart';
import '../data/buyer_checkout_review_controller.dart';
import '../data/buyer_location_repository.dart';
import '../models/buyer_checkout_attempt.dart';
import '../models/buyer_catalog_models.dart';
import '../models/buyer_checkout_models.dart';
import '../models/buyer_order_models.dart';
import '../models/buyer_shopping_models.dart';
import 'buyer_address_form_page.dart';

class BuyerCheckoutReviewPage extends StatefulWidget {
  const BuyerCheckoutReviewPage({
    super.key,
    required this.reviewController,
    required this.placementController,
    required this.addressController,
    required this.locationRepository,
  });

  final BuyerCheckoutReviewController reviewController;
  final BuyerCheckoutPlacementController placementController;
  final BuyerAddressController addressController;
  final BuyerLocationRepository locationRepository;

  @override
  State<BuyerCheckoutReviewPage> createState() =>
      _BuyerCheckoutReviewPageState();
}

class _BuyerCheckoutReviewPageState extends State<BuyerCheckoutReviewPage> {
  BuyerCheckoutReviewController get controller => widget.reviewController;
  BuyerCheckoutPlacementController get placement => widget.placementController;
  bool _reviewInitializationStarted = false;
  int? _observedPlacementSessionGeneration;
  Future<void>? _reviewInitialization;

  @override
  void initState() {
    super.initState();
    placement.addListener(_onPlacementChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initializeCheckout());
    });
  }

  Future<void> _initializeCheckout() async {
    await placement.initialize();
    if (mounted) await _initializeReviewIfReady();
  }

  void _onPlacementChanged() {
    if (mounted && placement.canShowCheckoutReview) {
      unawaited(_initializeReviewIfReady());
    }
  }

  Future<void> _initializeReviewIfReady() async {
    final generation = placement.sessionGeneration;
    if (_observedPlacementSessionGeneration != generation) {
      _observedPlacementSessionGeneration = generation;
      _reviewInitializationStarted = false;
      _reviewInitialization = null;
    }
    if (_reviewInitializationStarted || !placement.canShowCheckoutReview) {
      await _reviewInitialization;
      return;
    }
    _reviewInitializationStarted = true;
    _reviewInitialization = controller.initialize();
    await _reviewInitialization;
  }

  @override
  void dispose() {
    placement.removeListener(_onPlacementChanged);
    placement.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, placement]),
    builder: (context, _) {
      final order = placement.confirmedOrder;
      if (order != null) {
        return BuyerOrderConfirmationPage(
          order: order,
          isRefreshingCart: placement.isRefreshingCart,
          cartRefreshFailed: placement.cartRefreshFailed,
          onRefreshCart: placement.refreshCart,
          onContinueShopping: _continueShopping,
        );
      }
      if (placement.isInitializing ||
          !placement.attemptCheckComplete ||
          placement.attemptLoadError != null) {
        return _attemptCheckPage();
      }
      final attempt = placement.attempt;
      if (attempt != null &&
          !(placement.isSubmitting &&
              attempt.status == BuyerCheckoutAttemptStatus.ready)) {
        return _recoveryPage(attempt);
      }
      return _reviewPage();
    },
  );

  Widget _reviewPage() => PopScope(
    canPop: !placement.isSubmitting,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('buyer-checkout-review-back'),
          tooltip: 'Back to cart',
          onPressed: placement.isSubmitting ? null : _returnToCart,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Checkout Review'),
      ),
      body: _body(),
      bottomNavigationBar: SafeArea(top: false, child: _bottomAction()),
    ),
  );

  Widget _attemptCheckPage() {
    final error = placement.attemptLoadError;
    final isSessionError =
        error is BuyerCheckoutException &&
        error.category == BuyerCheckoutFailureCategory.noBuyerSession;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout Recovery')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (placement.isInitializing || error == null)
                  const CircularProgressIndicator(
                    key: ValueKey('buyer-checkout-recovery-checking'),
                  )
                else
                  const Icon(
                    Icons.lock_clock_outlined,
                    size: 52,
                    color: BearlyColors.brown700,
                  ),
                const SizedBox(height: 18),
                Text(
                  placement.isInitializing
                      ? 'Checking secure checkout state'
                      : 'Checkout recovery needs attention',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  placement.isInitializing
                      ? 'Your saved order attempt is checked before a new quote can be requested.'
                      : error is BuyerCheckoutException
                      ? placement.messageFor(error)
                      : 'Bearly could not read the saved checkout state. Another order is blocked until recovery can be checked.',
                  textAlign: TextAlign.center,
                ),
                if (isSessionError) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('buyer-checkout-recovery-sign-in'),
                    onPressed: _signInAgain,
                    child: const Text('Sign in again'),
                  ),
                ] else if (error != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('buyer-checkout-recovery-retry'),
                    onPressed: placement.isInitializing
                        ? null
                        : _retryAttemptCheck,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry recovery check'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recoveryPage(BuyerCheckoutAttempt attempt) {
    final isSubmitting = placement.isSubmitting;
    final conflict = placement.hasUnresolvedConflict;
    final unsubmitted = attempt.status == BuyerCheckoutAttemptStatus.ready;
    final definitivelyRejected = placement.canStartFreshCheckoutAfterRejection;
    final error = placement.actionError;
    final message = error != null
        ? placement.messageFor(error)
        : attempt.failureCategory == null
        ? null
        : _messageForAttempt(attempt);
    return PopScope(
      canPop: !isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Return to Cart',
            onPressed: isSubmitting ? null : _returnToCart,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Checkout Recovery'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                conflict
                    ? Icons.report_gmailerrorred_outlined
                    : unsubmitted
                    ? Icons.receipt_long_outlined
                    : attempt.status == BuyerCheckoutAttemptStatus.rejected
                    ? Icons.error_outline_rounded
                    : Icons.cloud_sync_outlined,
                size: 50,
                color: conflict || definitivelyRejected
                    ? BearlyColors.error
                    : BearlyColors.brown700,
              ),
              const SizedBox(height: 14),
              Text(
                isSubmitting
                    ? 'Checking the original order request'
                    : conflict
                    ? 'Checkout request conflict'
                    : unsubmitted
                    ? 'A fresh quote is needed'
                    : definitivelyRejected
                    ? 'This placement was rejected'
                    : 'Order status needs verification',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message ??
                    (unsubmitted
                        ? 'This request was saved before the placement POST began, so no order was sent. Request a fresh quote before placing it.'
                        : 'The order may already have been created. Bearly can safely reconcile it by retrying the exact saved request.'),
                textAlign: TextAlign.center,
              ),
              if (isSubmitting) ...[
                const SizedBox(height: 18),
                const Center(
                  child: CircularProgressIndicator(
                    key: ValueKey('buyer-checkout-placement-progress'),
                  ),
                ),
              ],
              if (attempt.validationErrors.isNotEmpty && error == null) ...[
                const SizedBox(height: 14),
                for (final validation
                    in attempt.validationErrors.values
                        .expand((items) => items)
                        .take(3))
                  _notice(
                    key: ValueKey('buyer-checkout-validation-$validation'),
                    message: validation,
                  ),
              ],
              const SizedBox(height: 20),
              if (!isSubmitting && placement.canRetryOriginalRequest)
                FilledButton.icon(
                  key: const ValueKey('buyer-checkout-retry-original'),
                  onPressed: placement.retryOriginalRequest,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Original Request'),
                ),
              if (!isSubmitting && unsubmitted)
                FilledButton.icon(
                  key: const ValueKey('buyer-checkout-refresh-unsubmitted'),
                  onPressed: _refreshUnsubmittedQuote,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Request a Fresh Quote'),
                ),
              if (!isSubmitting && definitivelyRejected)
                FilledButton.icon(
                  key: const ValueKey('buyer-checkout-requote-after-rejection'),
                  onPressed: _refreshAfterRejection,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Review Cart and Refresh Quote'),
                ),
              const SizedBox(height: 8),
              if (!isSubmitting)
                OutlinedButton(
                  key: const ValueKey('buyer-checkout-recovery-return-cart'),
                  onPressed: _returnToCart,
                  child: const Text('Return to Cart'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _messageForAttempt(BuyerCheckoutAttempt attempt) {
    if (attempt.failureCategory == BuyerCheckoutFailureCategory.conflict.name ||
        attempt.serverErrorCode == 'checkout_request_conflict') {
      return placement.messageFor(
        const BuyerCheckoutException(BuyerCheckoutFailureCategory.conflict),
      );
    }
    final category = BuyerCheckoutFailureCategory.values
        .where((value) => value.name == attempt.failureCategory)
        .firstOrNull;
    if (category == null) {
      return 'Bearly could not confirm this attempt. Keep it saved and contact support before placing another order.';
    }
    return placement.messageFor(
      BuyerCheckoutException(
        category,
        serverErrorCode: attempt.serverErrorCode,
        validationErrors: attempt.validationErrors,
      ),
    );
  }

  Future<void> _retryAttemptCheck() async {
    await placement.initialize(force: true);
    if (mounted) await _initializeReviewIfReady();
  }

  Future<void> _refreshUnsubmittedQuote() async {
    final saved = placement.attempt;
    if (saved == null) return;
    final wasInitialized = controller.isInitialized;
    await placement.discardUnsubmittedAttempt();
    if (!mounted || placement.attempt != null) return;
    await _initializeReviewIfReady();
    await _restoreSelectionAndRequestFreshQuote(saved, wasInitialized);
  }

  Future<void> _refreshAfterRejection() async {
    final saved = placement.attempt;
    if (saved == null) return;
    final wasInitialized = controller.isInitialized;
    await placement.clearDefinitiveRejection();
    if (!mounted || placement.attempt != null) return;
    await _initializeReviewIfReady();
    await _restoreSelectionAndRequestFreshQuote(saved, wasInitialized);
  }

  Future<void> _restoreSelectionAndRequestFreshQuote(
    BuyerCheckoutAttempt saved,
    bool wasInitialized,
  ) async {
    for (final id in saved.request.cartItemIds) {
      controller.cartController.setItemSelected(id, true);
    }
    controller.selectAddress(saved.request.addressId);
    final quote = controller.quote;
    final selection = quote?.sourceRequest;
    final alreadyFreshForSavedSelection =
        selection != null &&
        selection.addressId == saved.request.addressId &&
        selection.cartItemIds.join(',') == saved.request.cartItemIds.join(',');
    if (wasInitialized || !alreadyFreshForSavedSelection) {
      await controller.requestQuote();
    }
  }

  Future<void> _continueShopping() async {
    if (!await placement.acknowledgeSuccess() || !mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouteNames.buyerHome, (_) => false);
  }

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
      onRefresh: placement.isSubmitting
          ? () async {}
          : controller.refreshInputs,
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
          if (placement.actionError != null && placement.attempt == null)
            _notice(
              key: const ValueKey('buyer-checkout-placement-error'),
              message: placement.messageFor(placement.actionError!),
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
              onPressed: controller.isLoadingAddresses || placement.isSubmitting
                  ? null
                  : _chooseAddress,
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
              onPressed: placement.isSubmitting ? null : _returnToCart,
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
        onPressed: placement.isSubmitting ? null : _returnToCart,
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
          if (placement.isSubmitting) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Placing your COD order…'),
                  ],
                ),
              ),
            ),
          ],
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
          if (quote != null && controller.canPlaceOrder)
            FilledButton.icon(
              key: const ValueKey('buyer-checkout-place-order'),
              onPressed: placement.canPlaceOrder(quote)
                  ? () => unawaited(_confirmAndPlaceOrder(quote))
                  : null,
              icon: placement.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: const Text('Place Order · Cash on Delivery'),
            )
          else
            FilledButton.icon(
              key: const ValueKey('buyer-checkout-request-quote'),
              onPressed: canRequest && !placement.isSubmitting
                  ? controller.requestQuote
                  : null,
              icon: controller.isQuoting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_outlined),
              label: Text(label),
            ),
          if (quote != null && controller.canPlaceOrder)
            TextButton.icon(
              key: const ValueKey('buyer-checkout-refresh-quote'),
              onPressed: canRequest && !placement.isSubmitting
                  ? controller.requestQuote
                  : null,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh quoted total'),
            ),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('buyer-checkout-return-to-cart'),
            onPressed: placement.isSubmitting ? null : _returnToCart,
            child: const Text('Return to Cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndPlaceOrder(BuyerCheckoutQuote quote) async {
    if (!controller.canPlaceOrder || !placement.canPlaceOrder(quote)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Place this COD order?'),
        content: Text(
          'You are placing this order with Cash on Delivery. '
          'The server quoted ${formatPriceMinorUnits(quote.totalMinor, currency: quote.currency)} payable.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('buyer-checkout-cancel-placement'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review again'),
          ),
          FilledButton(
            key: const ValueKey('buyer-checkout-confirm-placement'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Place Order'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await placement.placeOrder(quote);
    }
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

class BuyerOrderConfirmationPage extends StatelessWidget {
  const BuyerOrderConfirmationPage({
    super.key,
    required this.order,
    required this.isRefreshingCart,
    required this.cartRefreshFailed,
    required this.onRefreshCart,
    required this.onContinueShopping,
  });

  final BuyerPlacedOrder order;
  final bool isRefreshingCart;
  final bool cartRefreshFailed;
  final Future<void> Function() onRefreshCart;
  final Future<void> Function() onContinueShopping;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Order Confirmation'),
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('buyer-order-confirmation-list'),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              key: ValueKey('buyer-order-confirmed-icon'),
              size: 62,
              color: BearlyColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              'Order placed',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Bearly confirmed your order. Keep this reference for your records.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _confirmationCard(
              context,
              title: 'Order details',
              children: [
                _detailRow('Order reference', order.reference),
                _detailRow('Created', _createdAt(context, order.createdAt)),
                _detailRow('Payment method', 'Cash on Delivery (COD)'),
                _detailRow(
                  'Payment status',
                  '${_readableStatus(order.paymentStatus)} · ${_readableStatus(order.initialPaymentState)}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'The order is not marked paid by placement. COD collection follows the existing delivery process.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _confirmationCard(
              context,
              title: 'Seller orders',
              children: order.sellerOrders.isEmpty
                  ? const [Text('No Seller order summary was returned.')]
                  : [
                      for (final sellerOrder in order.sellerOrders) ...[
                        if (sellerOrder != order.sellerOrders.first)
                          const Divider(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.storefront_outlined, size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sellerOrder.storeName.trim().isEmpty
                                        ? 'Seller order'
                                        : sellerOrder.storeName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  Text(
                                    sellerOrder.reference,
                                    key: ValueKey(
                                      'buyer-order-seller-reference-${sellerOrder.id}',
                                    ),
                                  ),
                                  Text(
                                    '${sellerOrder.itemCount} ${sellerOrder.itemCount == 1 ? 'item' : 'items'}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
            ),
            const SizedBox(height: 12),
            _confirmationCard(
              context,
              title: 'Amount payable',
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('COD total payable')),
                    Text(
                      formatPriceMinorUnits(
                        order.totalMinor,
                        currency: order.currency,
                      ),
                      key: const ValueKey('buyer-order-confirmation-total'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: BearlyColors.brown700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (cartRefreshFailed) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('buyer-order-cart-refresh-warning'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BearlyColors.cream100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BearlyColors.cream300),
                ),
                child: const Text(
                  'Your order is confirmed, but the Cart could not be refreshed. Refresh it before shopping again.',
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                key: const ValueKey('buyer-order-refresh-cart'),
                onPressed: isRefreshingCart ? null : onRefreshCart,
                icon: isRefreshingCart
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Refresh Cart'),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey('buyer-order-continue-shopping'),
            onPressed: onContinueShopping,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Continue Shopping'),
          ),
        ),
      ),
    ),
  );

  static Widget _confirmationCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) => Card(
    color: Colors.white,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  static Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Text(label)),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  static String _createdAt(BuildContext context, DateTime? value) {
    if (value == null) return 'Not provided';
    final local = value.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final time = TimeOfDay.fromDateTime(local);
    return '${localizations.formatMediumDate(local)} · ${localizations.formatTimeOfDay(time)}';
  }

  static String _readableStatus(String value) => value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
