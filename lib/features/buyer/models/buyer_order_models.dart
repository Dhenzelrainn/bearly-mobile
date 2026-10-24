import 'buyer_checkout_models.dart';

class BuyerOrderHistoryPage {
  BuyerOrderHistoryPage({
    required List<BuyerOrderSummary> orders,
    required this.pagination,
  }) : orders = List.unmodifiable(orders);

  final List<BuyerOrderSummary> orders;
  final BuyerOrderPagination pagination;

  factory BuyerOrderHistoryPage.fromResponse(Object? value) {
    final root = buyerCheckoutMap(value, 'root');
    final orders = buyerCheckoutList(
      root['data'],
      'data',
    ).map(BuyerOrderSummary.fromJson).toList(growable: false);
    return BuyerOrderHistoryPage(
      orders: orders,
      pagination: BuyerOrderPagination.fromJson(root['meta'], root['links']),
    );
  }
}

class BuyerOrderPagination {
  const BuyerOrderPagination({
    required this.currentPage,
    required this.from,
    required this.lastPage,
    required this.perPage,
    required this.to,
    required this.total,
    required this.firstUrl,
    required this.lastUrl,
    required this.previousUrl,
    required this.nextUrl,
  });

  final int currentPage;
  final int? from;
  final int lastPage;
  final int perPage;
  final int? to;
  final int total;
  final String? firstUrl;
  final String? lastUrl;
  final String? previousUrl;
  final String? nextUrl;

  bool get hasMore => nextUrl != null && currentPage < lastPage;

  factory BuyerOrderPagination.fromJson(Object? metaValue, Object? linksValue) {
    final meta = buyerCheckoutMap(metaValue, 'meta');
    final links = buyerCheckoutMap(linksValue, 'links');
    final result = BuyerOrderPagination(
      currentPage: buyerCheckoutInt(meta, 'current_page', 'meta'),
      from: buyerCheckoutOptionalInt(meta, 'from', 'meta'),
      lastPage: buyerCheckoutInt(meta, 'last_page', 'meta'),
      perPage: buyerCheckoutInt(meta, 'per_page', 'meta'),
      to: buyerCheckoutOptionalInt(meta, 'to', 'meta'),
      total: buyerCheckoutInt(meta, 'total', 'meta'),
      firstUrl: buyerCheckoutOptionalString(links, 'first', 'links'),
      lastUrl: buyerCheckoutOptionalString(links, 'last', 'links'),
      previousUrl: buyerCheckoutOptionalString(links, 'prev', 'links'),
      nextUrl: buyerCheckoutOptionalString(links, 'next', 'links'),
    );
    if (result.currentPage < 1 ||
        result.lastPage < 1 ||
        result.perPage < 1 ||
        result.perPage > 50 ||
        result.total < 0 ||
        (result.from != null && result.from! < 1) ||
        (result.to != null && result.to! < 1)) {
      throw const BuyerCheckoutFormatException('meta');
    }
    return result;
  }
}

class BuyerOrderSummary {
  BuyerOrderSummary({
    required this.id,
    required this.reference,
    required this.createdAt,
    required this.placedAt,
    required this.status,
    required this.paymentStatus,
    required this.currency,
    required this.subtotalMinor,
    required this.shippingFeeMinor,
    required this.discountMinor,
    required this.totalMinor,
    required this.itemCount,
    required this.previewImageUrl,
    required this.codPayment,
    required List<BuyerSellerOrderSummary> sellerOrders,
  }) : sellerOrders = List.unmodifiable(sellerOrders);

  final int id;
  final String reference;
  final DateTime? createdAt;
  final DateTime? placedAt;
  final String status;
  final String paymentStatus;
  final String currency;
  final int subtotalMinor;
  final int shippingFeeMinor;
  final int discountMinor;
  final int totalMinor;
  final int itemCount;
  final String? previewImageUrl;
  final BuyerOrderCodPayment? codPayment;
  final List<BuyerSellerOrderSummary> sellerOrders;

  factory BuyerOrderSummary.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'order');
    final rawCodPayment = json['cod_payment'];
    final summary = BuyerOrderSummary(
      id: buyerCheckoutInt(json, 'id', 'order'),
      reference: buyerCheckoutString(json, 'order_reference', 'order'),
      createdAt: buyerCheckoutOptionalDate(json, 'created_at', 'order'),
      placedAt: buyerCheckoutOptionalDate(json, 'placed_at', 'order'),
      status: buyerCheckoutString(json, 'status', 'order'),
      paymentStatus: buyerCheckoutString(json, 'payment_status', 'order'),
      currency: buyerCheckoutString(json, 'currency', 'order'),
      subtotalMinor: buyerCheckoutInt(json, 'subtotal_minor', 'order'),
      shippingFeeMinor: buyerCheckoutInt(json, 'shipping_fee_minor', 'order'),
      discountMinor: buyerCheckoutInt(json, 'discount_minor', 'order'),
      totalMinor: buyerCheckoutInt(json, 'total_minor', 'order'),
      itemCount: buyerCheckoutInt(json, 'item_count', 'order'),
      previewImageUrl: buyerCheckoutOptionalString(
        json,
        'preview_image_url',
        'order',
      ),
      codPayment: rawCodPayment == null
          ? null
          : BuyerOrderCodPayment.fromJson(rawCodPayment),
      sellerOrders: buyerCheckoutList(
        json['seller_orders'],
        'order.seller_orders',
      ).map(BuyerSellerOrderSummary.fromJson).toList(growable: false),
    );
    if (summary.id < 1 ||
        summary.itemCount < 0 ||
        [
          summary.subtotalMinor,
          summary.shippingFeeMinor,
          summary.discountMinor,
          summary.totalMinor,
        ].any((amount) => amount < 0)) {
      throw const BuyerCheckoutFormatException('order');
    }
    return summary;
  }
}

class BuyerOrderCodPayment {
  const BuyerOrderCodPayment({
    required this.status,
    required this.amountMinor,
    required this.paidAt,
  });

  final String status;
  final int amountMinor;
  final DateTime? paidAt;

  factory BuyerOrderCodPayment.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'cod_payment');
    final result = BuyerOrderCodPayment(
      status: buyerCheckoutString(json, 'status', 'cod_payment'),
      amountMinor: buyerCheckoutInt(json, 'amount_minor', 'cod_payment'),
      paidAt: buyerCheckoutOptionalDate(json, 'paid_at', 'cod_payment'),
    );
    if (result.amountMinor < 0) {
      throw const BuyerCheckoutFormatException('cod_payment.amount_minor');
    }
    return result;
  }
}

class BuyerSellerOrderSummary {
  BuyerSellerOrderSummary({
    required this.id,
    required this.reference,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.itemCount,
    required this.lineCount,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.shippingFeeMinor,
    required this.totalMinor,
    required List<BuyerOrderShipmentSummary> shipments,
  }) : shipments = List.unmodifiable(shipments);

  final int id;
  final String reference;
  final int storeId;
  final String? storeName;
  final String status;
  final int itemCount;
  final int lineCount;
  final int subtotalMinor;
  final int discountMinor;
  final int shippingFeeMinor;
  final int totalMinor;
  final List<BuyerOrderShipmentSummary> shipments;

  factory BuyerSellerOrderSummary.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'seller_order');
    final result = BuyerSellerOrderSummary(
      id: buyerCheckoutInt(json, 'id', 'seller_order'),
      reference: buyerCheckoutString(json, 'order_reference', 'seller_order'),
      storeId: buyerCheckoutInt(json, 'store_id', 'seller_order'),
      storeName: buyerCheckoutOptionalString(
        json,
        'store_name',
        'seller_order',
      ),
      status: buyerCheckoutString(json, 'status', 'seller_order'),
      itemCount: buyerCheckoutInt(json, 'item_count', 'seller_order'),
      lineCount: buyerCheckoutInt(json, 'line_count', 'seller_order'),
      subtotalMinor: buyerCheckoutInt(json, 'subtotal_minor', 'seller_order'),
      discountMinor: buyerCheckoutInt(json, 'discount_minor', 'seller_order'),
      shippingFeeMinor: buyerCheckoutInt(
        json,
        'shipping_fee_minor',
        'seller_order',
      ),
      totalMinor: buyerCheckoutInt(json, 'total_minor', 'seller_order'),
      shipments: buyerCheckoutList(
        json['shipments'],
        'seller_order.shipments',
      ).map(BuyerOrderShipmentSummary.fromJson).toList(growable: false),
    );
    if (result.id < 1 ||
        result.storeId < 1 ||
        result.itemCount < 0 ||
        result.lineCount < 0 ||
        [
          result.subtotalMinor,
          result.discountMinor,
          result.shippingFeeMinor,
          result.totalMinor,
        ].any((amount) => amount < 0)) {
      throw const BuyerCheckoutFormatException('seller_order');
    }
    return result;
  }
}

class BuyerOrderShipmentSummary {
  const BuyerOrderShipmentSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.waybillReference,
    required this.estimatedDeliveryAt,
    required this.deliveredAt,
  });

  final int id;
  final String reference;
  final String status;
  final String? waybillReference;
  final DateTime? estimatedDeliveryAt;
  final DateTime? deliveredAt;

  factory BuyerOrderShipmentSummary.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'seller_order.shipments[]');
    final shipment = BuyerOrderShipmentSummary(
      id: buyerCheckoutInt(json, 'id', 'shipment'),
      reference: buyerCheckoutString(json, 'shipment_reference', 'shipment'),
      status: buyerCheckoutString(json, 'status', 'shipment'),
      waybillReference: buyerCheckoutOptionalString(
        json,
        'waybill_reference',
        'shipment',
      ),
      estimatedDeliveryAt: buyerCheckoutOptionalDate(
        json,
        'estimated_delivery_at',
        'shipment',
      ),
      deliveredAt: buyerCheckoutOptionalDate(json, 'delivered_at', 'shipment'),
    );
    if (shipment.id < 1) {
      throw const BuyerCheckoutFormatException('shipment.id');
    }
    return shipment;
  }
}

class BuyerOrderDetail {
  BuyerOrderDetail({
    required this.summary,
    required this.platformDiscountMinor,
    required this.campaignPlatformDiscountMinor,
    required this.platformShippingDiscountMinor,
    required this.deliveryAddress,
    required List<BuyerOrderPayment> payments,
    required List<BuyerOrderPromotion> promotions,
    required List<BuyerSellerOrderDetail> sellerOrders,
    required this.buyerActions,
  }) : payments = List.unmodifiable(payments),
       promotions = List.unmodifiable(promotions),
       sellerOrders = List.unmodifiable(sellerOrders);

  final BuyerOrderSummary summary;
  final int platformDiscountMinor;
  final int campaignPlatformDiscountMinor;
  final int platformShippingDiscountMinor;
  final BuyerOrderDeliveryAddress deliveryAddress;
  final List<BuyerOrderPayment> payments;
  final List<BuyerOrderPromotion> promotions;
  final List<BuyerSellerOrderDetail> sellerOrders;
  final BuyerOrderBuyerActions buyerActions;

  int get id => summary.id;
  String get reference => summary.reference;
  String get status => summary.status;
  String get currency => summary.currency;
  int get totalMinor => summary.totalMinor;

  factory BuyerOrderDetail.fromResponse(Object? value) {
    final root = buyerCheckoutMap(value, 'root');
    final data = buyerCheckoutMap(root['data'], 'data');
    return BuyerOrderDetail(
      summary: BuyerOrderSummary.fromJson(data),
      platformDiscountMinor: buyerCheckoutInt(
        data,
        'platform_discount_minor',
        'data',
      ),
      campaignPlatformDiscountMinor: buyerCheckoutInt(
        data,
        'campaign_platform_discount_minor',
        'data',
      ),
      platformShippingDiscountMinor: buyerCheckoutInt(
        data,
        'platform_shipping_discount_minor',
        'data',
      ),
      deliveryAddress: BuyerOrderDeliveryAddress.fromJson(
        data['delivery_address'],
      ),
      payments: buyerCheckoutList(
        data['payments'],
        'data.payments',
      ).map(BuyerOrderPayment.fromJson).toList(growable: false),
      promotions: buyerCheckoutList(
        data['promotions'],
        'data.promotions',
      ).map(BuyerOrderPromotion.fromJson).toList(growable: false),
      sellerOrders: buyerCheckoutList(
        data['seller_orders'],
        'data.seller_orders',
      ).map(BuyerSellerOrderDetail.fromJson).toList(growable: false),
      buyerActions: BuyerOrderBuyerActions.fromJson(data['buyer_actions']),
    );
  }
}

class BuyerOrderDeliveryAddress {
  const BuyerOrderDeliveryAddress({
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.barangay,
    required this.cityMunicipality,
    required this.province,
    required this.postalCode,
  });

  final String recipientName;
  final String recipientPhone;
  final String addressLine;
  final String barangay;
  final String cityMunicipality;
  final String province;
  final String? postalCode;

  factory BuyerOrderDeliveryAddress.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'data.delivery_address');
    return BuyerOrderDeliveryAddress(
      recipientName: buyerCheckoutString(
        json,
        'recipient_name',
        'delivery_address',
        allowEmpty: true,
      ),
      recipientPhone: buyerCheckoutString(
        json,
        'recipient_phone',
        'delivery_address',
        allowEmpty: true,
      ),
      addressLine: buyerCheckoutString(
        json,
        'address_line',
        'delivery_address',
        allowEmpty: true,
      ),
      barangay: buyerCheckoutString(
        json,
        'barangay',
        'delivery_address',
        allowEmpty: true,
      ),
      cityMunicipality: buyerCheckoutString(
        json,
        'city_municipality',
        'delivery_address',
        allowEmpty: true,
      ),
      province: buyerCheckoutString(
        json,
        'province',
        'delivery_address',
        allowEmpty: true,
      ),
      postalCode: buyerCheckoutOptionalString(
        json,
        'postal_code',
        'delivery_address',
      ),
    );
  }
}

class BuyerOrderPayment {
  const BuyerOrderPayment({
    required this.method,
    required this.status,
    required this.amountMinor,
    required this.paidAt,
  });

  final String method;
  final String status;
  final int amountMinor;
  final DateTime? paidAt;

  factory BuyerOrderPayment.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'payment');
    return BuyerOrderPayment(
      method: buyerCheckoutString(json, 'method', 'payment'),
      status: buyerCheckoutString(json, 'status', 'payment'),
      amountMinor: buyerCheckoutInt(json, 'amount_minor', 'payment'),
      paidAt: buyerCheckoutOptionalDate(json, 'paid_at', 'payment'),
    );
  }
}

class BuyerOrderPromotion {
  BuyerOrderPromotion({
    required this.name,
    required this.kind,
    required this.status,
    required this.discountMinor,
    required this.shippingDiscountMinor,
    required List<BuyerOrderPromotionAllocation> allocations,
  }) : allocations = List.unmodifiable(allocations);

  final String name;
  final String kind;
  final String status;
  final int discountMinor;
  final int shippingDiscountMinor;
  final List<BuyerOrderPromotionAllocation> allocations;

  factory BuyerOrderPromotion.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'promotion');
    return BuyerOrderPromotion(
      name: buyerCheckoutString(json, 'name', 'promotion'),
      kind: buyerCheckoutString(json, 'kind', 'promotion'),
      status: buyerCheckoutString(json, 'status', 'promotion'),
      discountMinor: buyerCheckoutInt(json, 'discount_minor', 'promotion'),
      shippingDiscountMinor: buyerCheckoutInt(
        json,
        'shipping_discount_minor',
        'promotion',
      ),
      allocations: buyerCheckoutList(
        json['allocations'],
        'promotion.allocations',
      ).map(BuyerOrderPromotionAllocation.fromJson).toList(growable: false),
    );
  }
}

class BuyerOrderPromotionAllocation {
  const BuyerOrderPromotionAllocation({
    required this.sellerOrderId,
    required this.amountMinor,
  });

  final int sellerOrderId;
  final int amountMinor;

  factory BuyerOrderPromotionAllocation.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'promotion.allocation');
    return BuyerOrderPromotionAllocation(
      sellerOrderId: buyerCheckoutInt(json, 'seller_order_id', 'allocation'),
      amountMinor: buyerCheckoutInt(json, 'amount_minor', 'allocation'),
    );
  }
}

class BuyerSellerOrderDetail {
  BuyerSellerOrderDetail({
    required this.summary,
    required this.platformDiscountMinor,
    required this.campaignPlatformDiscountMinor,
    required this.platformShippingDiscountMinor,
    required List<BuyerOrderItemSnapshot> items,
    required List<BuyerOrderReturnSummary> returns,
  }) : items = List.unmodifiable(items),
       returns = List.unmodifiable(returns);

  final BuyerSellerOrderSummary summary;
  final int platformDiscountMinor;
  final int campaignPlatformDiscountMinor;
  final int platformShippingDiscountMinor;
  final List<BuyerOrderItemSnapshot> items;
  final List<BuyerOrderReturnSummary> returns;

  factory BuyerSellerOrderDetail.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'seller_order');
    final rawSummary = Map<String, Object?>.from(json)
      ..remove('items')
      ..remove('returns')
      ..remove('platform_discount_minor')
      ..remove('campaign_platform_discount_minor')
      ..remove('platform_shipping_discount_minor');
    return BuyerSellerOrderDetail(
      summary: BuyerSellerOrderSummary.fromJson(rawSummary),
      platformDiscountMinor: buyerCheckoutInt(
        json,
        'platform_discount_minor',
        'seller_order',
      ),
      campaignPlatformDiscountMinor: buyerCheckoutInt(
        json,
        'campaign_platform_discount_minor',
        'seller_order',
      ),
      platformShippingDiscountMinor: buyerCheckoutInt(
        json,
        'platform_shipping_discount_minor',
        'seller_order',
      ),
      items: buyerCheckoutList(
        json['items'],
        'seller_order.items',
      ).map(BuyerOrderItemSnapshot.fromJson).toList(growable: false),
      returns: buyerCheckoutList(
        json['returns'],
        'seller_order.returns',
      ).map(BuyerOrderReturnSummary.fromJson).toList(growable: false),
    );
  }
}

class BuyerOrderItemSnapshot {
  BuyerOrderItemSnapshot({
    required this.id,
    required this.productName,
    required this.variantName,
    required this.sku,
    required Map<String, Object?> options,
    required this.productImageUrl,
    required this.quantity,
    required this.unitPriceMinor,
    required this.subtotalMinor,
    required this.sellerDiscountMinor,
    required this.platformDiscountMinor,
    required this.campaignPlatformDiscountMinor,
    required this.totalMinor,
  }) : options = Map.unmodifiable(options);

  final int id;
  final String productName;
  final String variantName;
  final String sku;
  final Map<String, Object?> options;
  final String? productImageUrl;
  final int quantity;
  final int unitPriceMinor;
  final int subtotalMinor;
  final int sellerDiscountMinor;
  final int platformDiscountMinor;
  final int campaignPlatformDiscountMinor;
  final int totalMinor;

  factory BuyerOrderItemSnapshot.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'order_item');
    return BuyerOrderItemSnapshot(
      id: buyerCheckoutInt(json, 'id', 'order_item'),
      productName: buyerCheckoutString(
        json,
        'product_name',
        'order_item',
        allowEmpty: true,
      ),
      variantName: buyerCheckoutString(
        json,
        'variant_name',
        'order_item',
        allowEmpty: true,
      ),
      sku: buyerCheckoutString(json, 'sku', 'order_item', allowEmpty: true),
      options: buyerCheckoutMap(json['options'], 'order_item.options'),
      productImageUrl: buyerCheckoutOptionalString(
        json,
        'product_image_url',
        'order_item',
      ),
      quantity: buyerCheckoutInt(json, 'quantity', 'order_item'),
      unitPriceMinor: buyerCheckoutInt(json, 'unit_price_minor', 'order_item'),
      subtotalMinor: buyerCheckoutInt(json, 'subtotal_minor', 'order_item'),
      sellerDiscountMinor: buyerCheckoutInt(
        json,
        'seller_discount_minor',
        'order_item',
      ),
      platformDiscountMinor: buyerCheckoutInt(
        json,
        'platform_discount_minor',
        'order_item',
      ),
      campaignPlatformDiscountMinor: buyerCheckoutInt(
        json,
        'campaign_platform_discount_minor',
        'order_item',
      ),
      totalMinor: buyerCheckoutInt(json, 'total_minor', 'order_item'),
    );
  }
}

class BuyerOrderReturnSummary {
  BuyerOrderReturnSummary({
    required this.reference,
    required this.requestType,
    required this.status,
    required this.requestedAmountMinor,
    required this.submittedAt,
    required this.resolvedAt,
    required List<BuyerOrderRefundSummary> refunds,
  }) : refunds = List.unmodifiable(refunds);

  final String reference;
  final String requestType;
  final String status;
  final int requestedAmountMinor;
  final DateTime? submittedAt;
  final DateTime? resolvedAt;
  final List<BuyerOrderRefundSummary> refunds;

  factory BuyerOrderReturnSummary.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'return');
    return BuyerOrderReturnSummary(
      reference: buyerCheckoutString(json, 'return_reference', 'return'),
      requestType: buyerCheckoutString(json, 'request_type', 'return'),
      status: buyerCheckoutString(json, 'status', 'return'),
      requestedAmountMinor: buyerCheckoutInt(
        json,
        'requested_amount_minor',
        'return',
      ),
      submittedAt: buyerCheckoutOptionalDate(json, 'submitted_at', 'return'),
      resolvedAt: buyerCheckoutOptionalDate(json, 'resolved_at', 'return'),
      refunds: buyerCheckoutList(
        json['refunds'],
        'return.refunds',
      ).map(BuyerOrderRefundSummary.fromJson).toList(growable: false),
    );
  }
}

class BuyerOrderRefundSummary {
  const BuyerOrderRefundSummary({
    required this.status,
    required this.amountMinor,
    required this.completedAt,
  });

  final String status;
  final int amountMinor;
  final DateTime? completedAt;

  factory BuyerOrderRefundSummary.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'refund');
    return BuyerOrderRefundSummary(
      status: buyerCheckoutString(json, 'status', 'refund'),
      amountMinor: buyerCheckoutInt(json, 'amount_minor', 'refund'),
      completedAt: buyerCheckoutOptionalDate(json, 'completed_at', 'refund'),
    );
  }
}

class BuyerOrderBuyerActions {
  const BuyerOrderBuyerActions({
    required this.canConfirmReceipt,
    required this.receiptConfirmed,
    required this.receiptConfirmedAt,
  });

  final bool canConfirmReceipt;
  final bool receiptConfirmed;
  final DateTime? receiptConfirmedAt;

  factory BuyerOrderBuyerActions.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'data.buyer_actions');
    return BuyerOrderBuyerActions(
      canConfirmReceipt: buyerCheckoutBool(
        json,
        'can_confirm_receipt',
        'buyer_actions',
      ),
      receiptConfirmed: buyerCheckoutBool(
        json,
        'receipt_confirmed',
        'buyer_actions',
      ),
      receiptConfirmedAt: buyerCheckoutOptionalDate(
        json,
        'receipt_confirmed_at',
        'buyer_actions',
      ),
    );
  }
}

class BuyerPlacedOrder {
  BuyerPlacedOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.initialPaymentState,
    required this.currency,
    required this.subtotalMinor,
    required this.shippingFeeMinor,
    required this.discountMinor,
    required this.platformDiscountMinor,
    required this.campaignPlatformDiscountMinor,
    required this.shippingDiscountMinor,
    required this.totalMinor,
    required this.createdAt,
    required this.placedAt,
    required List<BuyerPlacedSellerOrder> sellerOrders,
  }) : sellerOrders = List.unmodifiable(sellerOrders);

  final int id;
  final String reference;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String initialPaymentState;
  final String currency;
  final int subtotalMinor;
  final int shippingFeeMinor;
  final int discountMinor;
  final int platformDiscountMinor;
  final int campaignPlatformDiscountMinor;
  final int shippingDiscountMinor;
  final int totalMinor;
  final DateTime? createdAt;
  final DateTime? placedAt;
  final List<BuyerPlacedSellerOrder> sellerOrders;

  factory BuyerPlacedOrder.fromResponse(Object? value) {
    final root = buyerCheckoutMap(value, 'root');
    return BuyerPlacedOrder.fromJson(root['data']);
  }

  factory BuyerPlacedOrder.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'order');
    final result = BuyerPlacedOrder(
      id: buyerCheckoutInt(json, 'id', 'order'),
      reference: buyerCheckoutString(json, 'order_reference', 'order'),
      status: buyerCheckoutString(json, 'status', 'order'),
      paymentMethod: buyerCheckoutString(json, 'payment_method', 'order'),
      paymentStatus: buyerCheckoutString(json, 'payment_status', 'order'),
      initialPaymentState: buyerCheckoutString(
        json,
        'initial_payment_state',
        'order',
      ),
      currency: buyerCheckoutString(json, 'currency', 'order'),
      subtotalMinor: buyerCheckoutInt(json, 'subtotal_minor', 'order'),
      shippingFeeMinor: buyerCheckoutInt(json, 'shipping_fee_minor', 'order'),
      discountMinor: buyerCheckoutInt(json, 'discount_minor', 'order'),
      platformDiscountMinor: buyerCheckoutInt(
        json,
        'platform_discount_minor',
        'order',
      ),
      campaignPlatformDiscountMinor: buyerCheckoutInt(
        json,
        'campaign_platform_discount_minor',
        'order',
      ),
      shippingDiscountMinor: buyerCheckoutInt(
        json,
        'shipping_discount_minor',
        'order',
      ),
      totalMinor: buyerCheckoutInt(json, 'total_minor', 'order'),
      createdAt: buyerCheckoutOptionalDate(json, 'created_at', 'order'),
      placedAt: buyerCheckoutOptionalDate(json, 'placed_at', 'order'),
      sellerOrders: buyerCheckoutList(
        json['seller_orders'],
        'order.seller_orders',
      ).map(BuyerPlacedSellerOrder.fromJson).toList(growable: false),
    );
    if (result.id < 1 ||
        result.currency != 'PHP' ||
        result.paymentMethod != 'cod' ||
        [
          result.subtotalMinor,
          result.shippingFeeMinor,
          result.discountMinor,
          result.platformDiscountMinor,
          result.campaignPlatformDiscountMinor,
          result.shippingDiscountMinor,
          result.totalMinor,
        ].any((amount) => amount < 0)) {
      throw const BuyerCheckoutFormatException('order');
    }
    return result;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'order_reference': reference,
    'status': status,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'initial_payment_state': initialPaymentState,
    'currency': currency,
    'subtotal_minor': subtotalMinor,
    'shipping_fee_minor': shippingFeeMinor,
    'discount_minor': discountMinor,
    'platform_discount_minor': platformDiscountMinor,
    'campaign_platform_discount_minor': campaignPlatformDiscountMinor,
    'shipping_discount_minor': shippingDiscountMinor,
    'total_minor': totalMinor,
    'created_at': createdAt?.toIso8601String(),
    'placed_at': placedAt?.toIso8601String(),
    'seller_orders': sellerOrders
        .map((sellerOrder) => sellerOrder.toJson())
        .toList(),
  };
}

class BuyerPlacedSellerOrder {
  const BuyerPlacedSellerOrder({
    required this.id,
    required this.reference,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.itemCount,
  });

  final int id;
  final String reference;
  final int storeId;
  final String storeName;
  final String status;
  final int itemCount;

  factory BuyerPlacedSellerOrder.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'seller_order');
    return BuyerPlacedSellerOrder(
      id: buyerCheckoutInt(json, 'id', 'seller_order'),
      reference: buyerCheckoutString(
        json,
        'seller_order_reference',
        'seller_order',
      ),
      storeId: buyerCheckoutInt(json, 'store_id', 'seller_order'),
      storeName: buyerCheckoutString(
        json,
        'store_name',
        'seller_order',
        allowEmpty: true,
      ),
      status: buyerCheckoutString(json, 'status', 'seller_order'),
      itemCount: buyerCheckoutInt(json, 'item_count', 'seller_order'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'seller_order_reference': reference,
    'store_id': storeId,
    'store_name': storeName,
    'status': status,
    'item_count': itemCount,
  };
}

class BuyerReceiptConfirmation {
  BuyerReceiptConfirmation({
    required this.orderId,
    required this.orderReference,
    required this.status,
    required this.paymentStatus,
    required this.currency,
    required this.totalMinor,
    required this.completedAt,
    required this.receiptConfirmed,
    required this.alreadyConfirmed,
    required List<BuyerReceiptSellerOrder> sellerOrders,
  }) : sellerOrders = List.unmodifiable(sellerOrders);

  final int orderId;
  final String orderReference;
  final String status;
  final String paymentStatus;
  final String currency;
  final int totalMinor;
  final DateTime? completedAt;
  final bool receiptConfirmed;
  final bool alreadyConfirmed;
  final List<BuyerReceiptSellerOrder> sellerOrders;

  factory BuyerReceiptConfirmation.fromResponse(Object? value) {
    final root = buyerCheckoutMap(value, 'root');
    final json = buyerCheckoutMap(root['data'], 'data');
    final result = BuyerReceiptConfirmation(
      orderId: buyerCheckoutInt(json, 'order_id', 'data'),
      orderReference: buyerCheckoutString(json, 'order_reference', 'data'),
      status: buyerCheckoutString(json, 'status', 'data'),
      paymentStatus: buyerCheckoutString(json, 'payment_status', 'data'),
      currency: buyerCheckoutString(json, 'currency', 'data'),
      totalMinor: buyerCheckoutInt(json, 'total_minor', 'data'),
      completedAt: buyerCheckoutOptionalDate(json, 'completed_at', 'data'),
      receiptConfirmed: buyerCheckoutBool(json, 'receipt_confirmed', 'data'),
      alreadyConfirmed: buyerCheckoutBool(json, 'already_confirmed', 'data'),
      sellerOrders: buyerCheckoutList(
        json['seller_orders'],
        'data.seller_orders',
      ).map(BuyerReceiptSellerOrder.fromJson).toList(growable: false),
    );
    if (result.orderId < 1 ||
        result.totalMinor < 0 ||
        result.currency != 'PHP') {
      throw const BuyerCheckoutFormatException('data');
    }
    return result;
  }
}

class BuyerReceiptSellerOrder {
  const BuyerReceiptSellerOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.completedAt,
  });

  final int id;
  final String reference;
  final String status;
  final DateTime? completedAt;

  factory BuyerReceiptSellerOrder.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'seller_order');
    return BuyerReceiptSellerOrder(
      id: buyerCheckoutInt(json, 'id', 'seller_order'),
      reference: buyerCheckoutString(json, 'order_reference', 'seller_order'),
      status: buyerCheckoutString(json, 'status', 'seller_order'),
      completedAt: buyerCheckoutOptionalDate(
        json,
        'completed_at',
        'seller_order',
      ),
    );
  }
}
