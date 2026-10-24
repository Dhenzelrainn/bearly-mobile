import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_checkout_repository.dart';
import '../data/buyer_orders_controller.dart';
import '../models/buyer_order_models.dart';
import 'buyer_order_display.dart';

class BuyerOrdersPage extends StatefulWidget {
  const BuyerOrdersPage({
    super.key,
    required this.authService,
    required this.checkoutRepository,
    required this.onSignInAgain,
    this.isActive = true,
  });

  final AuthService authService;
  final BuyerCheckoutRepository checkoutRepository;
  final VoidCallback onSignInAgain;
  final bool isActive;

  @override
  State<BuyerOrdersPage> createState() => _BuyerOrdersPageState();
}

class _BuyerOrdersPageState extends State<BuyerOrdersPage> {
  late final BuyerOrdersController _controller = BuyerOrdersController(
    authService: widget.authService,
    checkoutRepository: widget.checkoutRepository,
  );

  @override
  void initState() {
    super.initState();
    _controller.setActive(widget.isActive);
  }

  @override
  void didUpdateWidget(covariant BuyerOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _controller.setActive(widget.isActive);
      if (widget.isActive && _controller.hasLoaded) {
        unawaited(_controller.refresh());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (!_controller.hasBuyerSession) return _signedOut(context);
      if (_controller.isLoading && !_controller.hasLoaded) {
        return const Center(
          child: CircularProgressIndicator(
            key: ValueKey('buyer-orders-loading'),
          ),
        );
      }

      final localizations = MaterialLocalizations.of(context);
      return RefreshIndicator(
        key: const ValueKey('buyer-orders-refresh'),
        onRefresh: _controller.refresh,
        child: ListView(
          key: const ValueKey('buyer-orders-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Text(
              'My orders',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Your purchases and Seller order updates.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
            ),
            if (_controller.pagination case final pagination?) ...[
              const SizedBox(height: 6),
              Text(
                'Showing ${_controller.orders.length} of ${pagination.total} orders',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_controller.isLoading && _controller.hasLoaded) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                key: ValueKey('buyer-orders-refresh-progress'),
              ),
            ],
            if (_controller.error != null && _controller.orders.isNotEmpty)
              _inlineError(
                context,
                _controller.error!,
                onRetry: _controller.refresh,
              ),
            if (_controller.orders.isEmpty && _controller.error != null)
              _emptyFailure(context, _controller.error!),
            if (_controller.orders.isEmpty &&
                _controller.error == null &&
                !_controller.isLoading)
              _empty(context),
            for (final order in _controller.orders)
              _orderCard(context, order, localizations),
            if (_controller.loadMoreError != null)
              _inlineError(
                context,
                _controller.loadMoreError!,
                onRetry: _controller.loadNextPage,
              ),
            if (_controller.hasMore) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                key: const ValueKey('buyer-orders-load-more'),
                onPressed: _controller.isLoadingMore
                    ? null
                    : _controller.loadNextPage,
                icon: _controller.isLoadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  _controller.isLoadingMore ? 'Loading orders' : 'Load more',
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _signedOut(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline_rounded, size: 46),
          const SizedBox(height: 12),
          Text(
            'Sign in to view your orders',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Orders are private to the signed-in Buyer account.'),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('buyer-orders-sign-in'),
            onPressed: widget.onSignInAgain,
            child: const Text('Sign in'),
          ),
        ],
      ),
    ),
  );

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 62, horizontal: 22),
    child: Column(
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 48,
          color: BearlyColors.brown700,
        ),
        const SizedBox(height: 14),
        Text('No orders yet', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Completed purchases will appear here.'),
      ],
    ),
  );

  Widget _emptyFailure(BuildContext context, Object error) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 22),
    child: Column(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 44,
          color: BearlyColors.error,
        ),
        const SizedBox(height: 12),
        Text(buyerOrderReadErrorMessage(error), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('buyer-orders-retry'),
          onPressed: _controller.isLoading ? null : _controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _inlineError(
    BuildContext context,
    Object error, {
    required Future<void> Function() onRetry,
  }) => Card(
    color: BearlyColors.cream100,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(buyerOrderReadErrorMessage(error))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _orderCard(
    BuildContext context,
    BuyerOrderSummary order,
    MaterialLocalizations localizations,
  ) => Card(
    key: ValueKey('buyer-order-${order.id}'),
    color: Colors.white,
    margin: const EdgeInsets.only(top: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _openOrderDetails(context, order.id),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: BearlyColors.cream200,
                  child: Icon(Icons.receipt_long_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.reference,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        buyerOrderDateTime(
                          order.placedAt ?? order.createdAt,
                          localizations,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _statusChip('Order · ${buyerOrderStatusLabel(order.status)}'),
                _statusChip(
                  'Payment · ${buyerOrderStatusLabel(order.paymentStatus)}',
                ),
                if (order.codPayment != null)
                  _statusChip(
                    'COD · ${buyerOrderStatusLabel(order.codPayment!.status)}',
                  )
                else
                  _statusChip(
                    'Payment · ${buyerOrderStatusLabel(order.paymentStatus)}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  buyerOrderAmount(order.totalMinor, currency: order.currency),
                  key: ValueKey('buyer-order-total-${order.id}'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BearlyColors.brown900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (order.sellerOrders.isNotEmpty) ...[
              const Divider(height: 22),
              for (final seller in order.sellerOrders)
                Padding(
                  key: ValueKey('buyer-order-seller-${seller.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seller.storeName?.trim().isNotEmpty == true
                                  ? seller.storeName!
                                  : 'Seller order',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${seller.reference} · ${buyerOrderStatusLabel(seller.status)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buyerOrderAmount(
                          seller.totalMinor,
                          currency: order.currency,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _openOrderDetails(BuildContext context, int orderId) async {
    await Navigator.of(
      context,
    ).pushNamed<Object?>(AppRouteNames.buyerOrderDetails, arguments: orderId);
    if (!mounted) return;
    // Re-fetch page one whenever Order Details returns. Receipt confirmation
    // changes the parent status shown in Buyer history.
    await _controller.refresh();
  }

  Widget _statusChip(String label) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
  );
}
