import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_checkout_repository.dart';
import '../data/buyer_order_detail_controller.dart';
import '../models/buyer_order_models.dart';
import '../models/buyer_tracking_models.dart';
import 'buyer_order_display.dart';

class BuyerOrderDetailsPage extends StatefulWidget {
  const BuyerOrderDetailsPage({
    super.key,
    required this.authService,
    required this.checkoutRepository,
    required this.orderId,
    required this.onSignInAgain,
  });

  final AuthService authService;
  final BuyerCheckoutRepository checkoutRepository;
  final int orderId;
  final VoidCallback onSignInAgain;

  @override
  State<BuyerOrderDetailsPage> createState() => _BuyerOrderDetailsPageState();
}

class _BuyerOrderDetailsPageState extends State<BuyerOrderDetailsPage> {
  late final BuyerOrderDetailController _controller =
      BuyerOrderDetailController(
        authService: widget.authService,
        checkoutRepository: widget.checkoutRepository,
        orderId: widget.orderId,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
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
      if (_controller.accountChanged) return _accountChangedPage(context);
      if (!_controller.hasBuyerSession) return _signedOutPage(context);
      if (_controller.isLoading && !_controller.hasLoaded) {
        return Scaffold(
          appBar: AppBar(title: const Text('Order details')),
          body: const Center(
            child: CircularProgressIndicator(
              key: ValueKey('buyer-order-details-loading'),
            ),
          ),
        );
      }
      if (_controller.error != null) {
        return _errorPage(context, _controller.error!);
      }
      final detail = _controller.detail;
      final tracking = _controller.tracking;
      if (detail == null || tracking == null) {
        return _errorPage(context, StateError('Order data is unavailable.'));
      }
      final localizations = MaterialLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order details'),
          actions: [
            IconButton(
              tooltip: 'Refresh order details',
              onPressed: _controller.isLoading ? null : _controller.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          key: const ValueKey('buyer-order-details-refresh'),
          onRefresh: _controller.load,
          child: SingleChildScrollView(
            key: const ValueKey('buyer-order-details-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_controller.isLoading)
                  const LinearProgressIndicator(
                    key: ValueKey('buyer-order-details-refresh-progress'),
                  ),
                _orderHeader(context, detail, localizations),
                const SizedBox(height: 14),
                _orderTotals(context, detail),
                const SizedBox(height: 14),
                _deliveryAddress(context, detail.deliveryAddress),
                const SizedBox(height: 14),
                _paymentSummary(context, detail),
                const SizedBox(height: 14),
                _sectionHeading(context, 'Seller orders'),
                const SizedBox(height: 8),
                for (final seller in detail.sellerOrders) ...[
                  _sellerOrderCard(context, detail, seller, localizations),
                  const SizedBox(height: 10),
                ],
                if (detail.sellerOrders.isEmpty)
                  _notice(
                    'No Seller order records were returned for this order.',
                  ),
                const SizedBox(height: 12),
                _sectionHeading(context, 'Shipment tracking'),
                const SizedBox(height: 4),
                Text(
                  'Shipment and Seller order histories are shown separately using saved Bearly records.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _trackingSection(context, detail, tracking, localizations),
                if (detail.buyerActions.receiptConfirmed) ...[
                  const SizedBox(height: 14),
                  _readOnlyReceiptState(
                    context,
                    detail.buyerActions.receiptConfirmedAt,
                    localizations,
                  ),
                ] else if (detail.buyerActions.canConfirmReceipt) ...[
                  const SizedBox(height: 14),
                  _notice(
                    'Bearly reports that receipt confirmation is available.',
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _signedOutPage(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Order details')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 44),
            const SizedBox(height: 12),
            const Text('Sign in with a Buyer account to view this order.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.onSignInAgain,
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _accountChangedPage(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Order details')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Your account changed. This order view was cleared. Return to Orders and open an order for the current Buyer account.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _errorPage(BuildContext context, Object error) => Scaffold(
    appBar: AppBar(title: const Text('Order details')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: BearlyColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              buyerOrderReadErrorMessage(error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('buyer-order-details-retry'),
              onPressed: _controller.isLoading ? null : _controller.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _orderHeader(
    BuildContext context,
    BuyerOrderDetail detail,
    MaterialLocalizations localizations,
  ) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.reference,
            key: const ValueKey('buyer-order-detail-reference'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Order status · ${buyerOrderStatusLabel(detail.status)}',
            key: const ValueKey('buyer-order-parent-status'),
          ),
          const SizedBox(height: 4),
          Text(
            'Placed · ${buyerOrderDateTime(detail.summary.placedAt ?? detail.summary.createdAt, localizations)}',
          ),
          const SizedBox(height: 14),
          Text('Amount payable', style: Theme.of(context).textTheme.labelLarge),
          Text(
            buyerOrderAmount(detail.totalMinor, currency: detail.currency),
            key: const ValueKey('buyer-order-detail-total'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: BearlyColors.brown900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _orderTotals(BuildContext context, BuyerOrderDetail detail) =>
      _sectionCard(
        context,
        title: 'Order total',
        icon: Icons.receipt_outlined,
        children: [
          _amountRow(
            context,
            'Items subtotal',
            detail.summary.subtotalMinor,
            detail.currency,
          ),
          _amountRow(
            context,
            'Shipping',
            detail.summary.shippingFeeMinor,
            detail.currency,
          ),
          _amountRow(
            context,
            'Order discounts',
            detail.summary.discountMinor,
            detail.currency,
          ),
          _amountRow(
            context,
            'Platform discounts',
            detail.platformDiscountMinor + detail.campaignPlatformDiscountMinor,
            detail.currency,
          ),
          _amountRow(
            context,
            'Shipping discount',
            detail.platformShippingDiscountMinor,
            detail.currency,
          ),
          const Divider(height: 20),
          _amountRow(
            context,
            'Final amount payable',
            detail.totalMinor,
            detail.currency,
            strong: true,
          ),
        ],
      );

  Widget _deliveryAddress(
    BuildContext context,
    BuyerOrderDeliveryAddress address,
  ) {
    final locality = [
      address.barangay,
      address.cityMunicipality,
      address.province,
      address.postalCode,
    ].where((part) => part?.trim().isNotEmpty == true).join(', ');
    final lines = <String>[
      if (address.recipientName.trim().isNotEmpty) address.recipientName,
      if (address.recipientPhone.trim().isNotEmpty) address.recipientPhone,
      if (address.addressLine.trim().isNotEmpty) address.addressLine,
      if (locality.isNotEmpty) locality,
    ];
    return _sectionCard(
      context,
      title: 'Delivery address snapshot',
      icon: Icons.location_on_outlined,
      children: [
        for (final line in lines) Text(line),
        if (lines.isEmpty) const Text('No address snapshot was returned.'),
      ],
    );
  }

  Widget _paymentSummary(BuildContext context, BuyerOrderDetail detail) {
    final payments = detail.payments
        .where((payment) => payment.method.toLowerCase() == 'cod')
        .toList(growable: false);
    if (payments.isEmpty && detail.summary.codPayment == null) {
      return _sectionCard(
        context,
        title: 'Payment',
        icon: Icons.payments_outlined,
        children: [
          Text(
            'Order payment status · ${buyerOrderStatusLabel(detail.summary.paymentStatus)}',
          ),
          const Text('No COD payment record was returned.'),
        ],
      );
    }
    final cod = detail.summary.codPayment;
    return _sectionCard(
      context,
      title: 'Cash on Delivery (COD)',
      icon: Icons.payments_outlined,
      children: [
        Text(
          'Order payment status · ${buyerOrderStatusLabel(detail.summary.paymentStatus)}',
        ),
        if (payments.isNotEmpty)
          for (final payment in payments) ...[
            Text(
              'COD payment status · ${buyerOrderStatusLabel(payment.status)}',
            ),
            Text(
              'Payment amount · ${buyerOrderAmount(payment.amountMinor, currency: detail.currency)}',
            ),
            if (payment.paidAt != null)
              Text(
                'Recorded at · ${buyerOrderDateTime(payment.paidAt, MaterialLocalizations.of(context))}',
              ),
          ]
        else ...[
          Text('COD payment status · ${buyerOrderStatusLabel(cod!.status)}'),
          Text(
            'Payment amount · ${buyerOrderAmount(cod.amountMinor, currency: detail.currency)}',
          ),
          if (cod.paidAt != null)
            Text(
              'Recorded at · ${buyerOrderDateTime(cod.paidAt, MaterialLocalizations.of(context))}',
            ),
        ],
        const SizedBox(height: 6),
        const Text('Order placement does not mean COD has been collected.'),
      ],
    );
  }

  Widget _sellerOrderCard(
    BuildContext context,
    BuyerOrderDetail order,
    BuyerSellerOrderDetail seller,
    MaterialLocalizations localizations,
  ) => _sectionCard(
    context,
    title: seller.summary.storeName?.trim().isNotEmpty == true
        ? seller.summary.storeName!
        : 'Seller order',
    icon: Icons.storefront_outlined,
    children: [
      Text(
        'Seller order · ${seller.summary.reference}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        'Seller order status · ${buyerOrderStatusLabel(seller.summary.status)}',
        key: ValueKey('buyer-seller-status-${seller.summary.id}'),
      ),
      const SizedBox(height: 10),
      for (final item in seller.items) ...[
        _itemSnapshot(context, item, order.currency),
        if (item != seller.items.last) const Divider(height: 22),
      ],
      if (seller.items.isEmpty) const Text('No item snapshots were returned.'),
      const Divider(height: 20),
      _amountRow(
        context,
        'Seller subtotal',
        seller.summary.subtotalMinor,
        order.currency,
      ),
      _amountRow(
        context,
        'Seller discounts',
        seller.summary.discountMinor,
        order.currency,
      ),
      _amountRow(
        context,
        'Platform item discounts',
        seller.platformDiscountMinor + seller.campaignPlatformDiscountMinor,
        order.currency,
      ),
      _amountRow(
        context,
        'Shipping',
        seller.summary.shippingFeeMinor,
        order.currency,
      ),
      _amountRow(
        context,
        'Shipping discount',
        seller.platformShippingDiscountMinor,
        order.currency,
      ),
      _amountRow(
        context,
        'Seller order total',
        seller.summary.totalMinor,
        order.currency,
        strong: true,
      ),
      if (seller.returns.isNotEmpty) ...[
        const Divider(height: 24),
        Text(
          'Returns and refunds',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final request in seller.returns) ...[
          const SizedBox(height: 8),
          Text(
            '${request.reference} · ${buyerOrderStatusLabel(request.requestType)}',
          ),
          Text('Return status · ${buyerOrderStatusLabel(request.status)}'),
          if (request.submittedAt != null)
            Text(
              'Submitted · ${buyerOrderDateTime(request.submittedAt, localizations)}',
            ),
          if (request.resolvedAt != null)
            Text(
              'Resolved · ${buyerOrderDateTime(request.resolvedAt, localizations)}',
            ),
          for (final refund in request.refunds)
            Text(
              'Refund · ${buyerOrderStatusLabel(refund.status)} · ${buyerOrderAmount(refund.amountMinor, currency: order.currency)}${refund.completedAt == null ? '' : ' · ${buyerOrderDateTime(refund.completedAt, localizations)}'}',
            ),
        ],
      ],
    ],
  );

  Widget _itemSnapshot(
    BuildContext context,
    BuyerOrderItemSnapshot item,
    String currency,
  ) {
    final options = buyerOrderScalarOptions(item.options);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName.isEmpty
                ? 'Item name unavailable'
                : item.productName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (item.variantName.isNotEmpty)
            Text('Variant · ${item.variantName}'),
          if (options.isNotEmpty) Text(options),
          if (item.sku.isNotEmpty) Text('SKU · ${item.sku}'),
          Text('Quantity · ${item.quantity}'),
          Text(
            'Purchase-time unit price · ${buyerOrderAmount(item.unitPriceMinor, currency: currency)}',
          ),
          Text(
            'Line subtotal · ${buyerOrderAmount(item.subtotalMinor, currency: currency)}',
          ),
          if (item.sellerDiscountMinor +
                  item.platformDiscountMinor +
                  item.campaignPlatformDiscountMinor >
              0)
            Text(
              'Line discounts · ${buyerOrderAmount(item.sellerDiscountMinor + item.platformDiscountMinor + item.campaignPlatformDiscountMinor, currency: currency)}',
            ),
          Text(
            'Line total · ${buyerOrderAmount(item.totalMinor, currency: currency)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _trackingSection(
    BuildContext context,
    BuyerOrderDetail detail,
    BuyerOrderTracking tracking,
    MaterialLocalizations localizations,
  ) {
    final trackedById = {
      for (final seller in tracking.sellerOrders) seller.id: seller,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tracking.shipmentCount == 0)
          _notice(
            'No shipment records have been returned yet. No shipment milestones are inferred.',
            key: const ValueKey('buyer-order-no-shipments'),
          ),
        for (final seller in detail.sellerOrders) ...[
          _sellerTrackingCard(
            context,
            seller.summary.storeName,
            trackedById.remove(seller.summary.id),
            seller.summary.reference,
            localizations,
          ),
          const SizedBox(height: 10),
        ],
        for (final seller in trackedById.values) ...[
          _sellerTrackingCard(
            context,
            null,
            seller,
            seller.reference,
            localizations,
          ),
          const SizedBox(height: 10),
        ],
        if (tracking.shipmentCount > 0 && tracking.sellerOrders.isEmpty)
          _notice('No Seller shipment groups were returned.'),
      ],
    );
  }

  Widget _sellerTrackingCard(
    BuildContext context,
    String? storeName,
    BuyerTrackedSellerOrder? tracked,
    String sellerReference,
    MaterialLocalizations localizations,
  ) {
    final sellerLabel = storeName?.trim().isNotEmpty == true
        ? storeName!
        : 'Seller order';
    if (tracked == null) {
      return _sectionCard(
        context,
        title: sellerLabel,
        icon: Icons.local_shipping_outlined,
        children: [
          Text(sellerReference),
          const Text(
            'No tracking records were returned for this Seller order.',
          ),
        ],
      );
    }
    return _sectionCard(
      context,
      title: sellerLabel,
      icon: Icons.local_shipping_outlined,
      children: [
        Text('Seller order · ${tracked.reference}'),
        Text('Seller order status · ${buyerOrderStatusLabel(tracked.status)}'),
        const SizedBox(height: 8),
        Text(
          'Seller order status history',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (tracked.statusHistory.isEmpty)
          const Text('No Seller order status changes were returned.'),
        for (final change in _orderedStatusChanges(tracked.statusHistory))
          _timelineRow(
            context,
            change.fromStatus == null
                ? 'Status recorded · ${buyerOrderStatusLabel(change.toStatus)}'
                : '${buyerOrderStatusLabel(change.fromStatus!)} → ${buyerOrderStatusLabel(change.toStatus)}',
            buyerOrderDateTime(change.occurredAt, localizations),
            icon: Icons.swap_horiz_rounded,
          ),
        if (tracked.statusHistory.length >= 100)
          _truncationNote('status history', 100),
        const Divider(height: 22),
        if (tracked.shipments.isEmpty)
          const Text(
            'No shipment records were returned for this Seller order.',
          ),
        for (final shipment in tracked.shipments.where(
          (item) => item.purpose == 'outbound',
        )) ...[
          _shipmentCard(context, shipment, localizations),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _shipmentCard(
    BuildContext context,
    BuyerTrackedShipment shipment,
    MaterialLocalizations localizations,
  ) => Card(
    key: ValueKey('buyer-shipment-${shipment.id}'),
    color: BearlyColors.cream100,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shipment · ${shipment.reference}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text('Shipment status · ${buyerOrderStatusLabel(shipment.status)}'),
          if (shipment.waybillReference != null)
            Text('Waybill · ${shipment.waybillReference}'),
          if (shipment.estimatedDeliveryAt != null)
            Text(
              'Estimated delivery · ${buyerOrderDateTime(shipment.estimatedDeliveryAt, localizations)}',
            ),
          if (shipment.deliveredAt != null)
            Text(
              'Recorded delivery · ${buyerOrderDateTime(shipment.deliveredAt, localizations)}',
            ),
          const SizedBox(height: 10),
          Text(
            'Shipment events',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (shipment.events.isEmpty)
            const Text('No shipment events were returned.'),
          for (final event in _orderedShipmentEvents(shipment.events))
            _timelineRow(
              context,
              buyerOrderStatusLabel(event.eventType),
              '${event.scope == 'parcel' ? 'Parcel event' : 'Shipment event'}${event.toStatus == null ? '' : ' · Status ${buyerOrderStatusLabel(event.toStatus!)}'}${event.parcelReference == null ? '' : ' · ${event.parcelReference}'}',
              icon: Icons.fiber_manual_record,
              time: buyerOrderDateTime(event.occurredAt, localizations),
            ),
          if (shipment.events.length >= 100)
            _truncationNote('shipment event list', 100),
          const SizedBox(height: 8),
          Text(
            'Pickup rider activity',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          _pickupActivity(context, shipment, localizations),
          const SizedBox(height: 8),
          Text(
            'Last-mile delivery attempts',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          _deliveryActivity(context, shipment, localizations),
        ],
      ),
    ),
  );

  Widget _pickupActivity(
    BuildContext context,
    BuyerTrackedShipment shipment,
    MaterialLocalizations localizations,
  ) {
    final rows = <({DateTime at, String label})>[];
    for (final assignment in shipment.pickupAssignments) {
      final times = <(DateTime?, String)>[
        (assignment.assignedAt, 'Pickup assigned'),
        (assignment.acceptedAt, 'Pickup accepted'),
        (assignment.arrivedAt, 'Pickup rider arrived'),
        (assignment.pickedUpAt, 'Parcel picked up'),
        (assignment.completedAt, 'Pickup assignment completed'),
      ];
      for (final (time, label) in times) {
        if (time != null) rows.add((at: time, label: label));
      }
    }
    rows.sort((left, right) => left.at.compareTo(right.at));
    if (rows.isEmpty) {
      final hasStatus = shipment.pickupAssignments.any(
        (assignment) => assignment.status.trim().isNotEmpty,
      );
      if (!hasStatus) {
        return const Text('No pickup rider activity was returned.');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final assignment in shipment.pickupAssignments)
            Text(
              'Pickup assignment · ${buyerOrderStatusLabel(assignment.status)}',
            ),
        ],
      );
    }
    return Column(
      children: [
        for (final assignment in shipment.pickupAssignments)
          Text(
            'Pickup assignment status · ${buyerOrderStatusLabel(assignment.status)}',
            textAlign: TextAlign.left,
          ),
        for (final row in rows)
          _timelineRow(
            context,
            row.label,
            'Pickup rider record',
            icon: Icons.inventory_2_outlined,
            time: buyerOrderDateTime(row.at, localizations),
          ),
        if (shipment.pickupAssignments.length >= 50)
          _truncationNote('pickup activity records', 50),
      ],
    );
  }

  Widget _deliveryActivity(
    BuildContext context,
    BuyerTrackedShipment shipment,
    MaterialLocalizations localizations,
  ) {
    if (shipment.deliveryAttempts.isEmpty) {
      return const Text('No last-mile delivery attempts were returned.');
    }
    final attempts = [...shipment.deliveryAttempts]
      ..sort((left, right) => left.attemptedAt.compareTo(right.attemptedAt));
    return Column(
      children: [
        for (final attempt in attempts)
          _timelineRow(
            context,
            'Attempt ${attempt.attemptNumber} · ${buyerOrderStatusLabel(attempt.outcome)}',
            attempt.nextAttemptAt == null
                ? attempt.parcelReference
                : '${attempt.parcelReference} · Next recorded attempt ${buyerOrderDateTime(attempt.nextAttemptAt, localizations)}',
            icon: Icons.delivery_dining_outlined,
            time: buyerOrderDateTime(attempt.attemptedAt, localizations),
          ),
        if (shipment.deliveryAttempts.length >= 50)
          _truncationNote('delivery attempt records', 50),
      ],
    );
  }

  List<BuyerTrackedStatusChange> _orderedStatusChanges(
    List<BuyerTrackedStatusChange> changes,
  ) =>
      [...changes]
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

  List<BuyerTrackedShipmentEvent> _orderedShipmentEvents(
    List<BuyerTrackedShipmentEvent> events,
  ) =>
      [...events]
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

  Widget _sectionHeading(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      color: BearlyColors.brown900,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BearlyColors.brown700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  Widget _amountRow(
    BuildContext context,
    String label,
    int amount,
    String currency, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong
                ? Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          buyerOrderAmount(amount, currency: currency),
          style: strong
              ? Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
              : null,
        ),
      ],
    ),
  );

  Widget _timelineRow(
    BuildContext context,
    String title,
    String subtitle, {
    required IconData icon,
    String? time,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: BearlyColors.brown700),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              if (time != null)
                Text(time, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _truncationNote(String listName, int limit) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      'Bearly returns up to $limit $listName. History at this limit may be incomplete.',
      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
    ),
  );

  Widget _readOnlyReceiptState(
    BuildContext context,
    DateTime? confirmedAt,
    MaterialLocalizations localizations,
  ) => _notice(
    confirmedAt == null
        ? 'Bearly reports that receipt was confirmed.'
        : 'Receipt confirmed · ${buyerOrderDateTime(confirmedAt, localizations)}',
    key: const ValueKey('buyer-order-receipt-state'),
  );

  Widget _notice(String text, {Key? key}) => Card(
    key: key,
    color: BearlyColors.cream100,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
  );
}
