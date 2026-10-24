/// Field-only error for a malformed Laravel Buyer checkout response.
///
/// The exception never includes a response body, quote token, address, or
/// other private checkout value.
class BuyerCheckoutFormatException implements Exception {
  const BuyerCheckoutFormatException(this.field);

  final String field;

  @override
  String toString() => 'Invalid Buyer checkout response field: $field.';
}

class BuyerCheckoutVoucherSelection {
  BuyerCheckoutVoucherSelection({
    this.platformVoucherId,
    this.storeVoucherId,
    String? voucherCode,
  }) : voucherCode = _normalizeVoucherCode(voucherCode) {
    if ((platformVoucherId != null && platformVoucherId! < 1) ||
        (storeVoucherId != null && storeVoucherId! < 1)) {
      throw ArgumentError('Voucher IDs must be positive.');
    }
    if ((this.voucherCode?.length ?? 0) > 40 ||
        (this.voucherCode != null &&
            !RegExp(r'^[A-Z0-9_-]+$').hasMatch(this.voucherCode!))) {
      throw ArgumentError.value(voucherCode, 'voucherCode');
    }
  }

  final int? platformVoucherId;
  final int? storeVoucherId;
  final String? voucherCode;

  bool get isEmpty =>
      platformVoucherId == null &&
      storeVoucherId == null &&
      voucherCode == null;

  Map<String, Object?> toJson({bool includeNulls = false}) => {
    if (includeNulls || platformVoucherId != null)
      'platform_voucher_id': platformVoucherId,
    if (includeNulls || storeVoucherId != null)
      'store_voucher_id': storeVoucherId,
    if (includeNulls || voucherCode != null) 'voucher_code': voucherCode,
  };

  factory BuyerCheckoutVoucherSelection.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'promotion_selection');
    try {
      return BuyerCheckoutVoucherSelection(
        platformVoucherId: buyerCheckoutOptionalInt(
          json,
          'platform_voucher_id',
          'promotion_selection',
        ),
        storeVoucherId: buyerCheckoutOptionalInt(
          json,
          'store_voucher_id',
          'promotion_selection',
        ),
        voucherCode: buyerCheckoutOptionalString(
          json,
          'voucher_code',
          'promotion_selection',
        ),
      );
    } on ArgumentError {
      throw const BuyerCheckoutFormatException('promotion_selection');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BuyerCheckoutVoucherSelection &&
      other.platformVoucherId == platformVoucherId &&
      other.storeVoucherId == storeVoucherId &&
      other.voucherCode == voucherCode;

  @override
  int get hashCode =>
      Object.hash(platformVoucherId, storeVoucherId, voucherCode);
}

/// The exact client selection sent to Laravel for a fresh quote.
///
/// Totals and prices are intentionally absent; Laravel calculates them.
class BuyerCheckoutQuoteRequest {
  BuyerCheckoutQuoteRequest({
    required this.addressId,
    required List<int> cartItemIds,
    BuyerCheckoutVoucherSelection? vouchers,
  }) : cartItemIds = List.unmodifiable(cartItemIds),
       vouchers = vouchers ?? BuyerCheckoutVoucherSelection() {
    _validateSelection(addressId, this.cartItemIds);
  }

  final int addressId;
  final List<int> cartItemIds;
  final BuyerCheckoutVoucherSelection vouchers;
  String get paymentMethod => 'cod';

  Map<String, Object?> toJson() => {
    'address_id': addressId,
    'cart_item_ids': cartItemIds,
    'payment_method': paymentMethod,
    ...vouchers.toJson(),
  };
}

/// Immutable COD placement payload. Retries must serialize this same instance
/// and preserve both the UUID and Laravel quote token.
class BuyerCheckoutPlacementRequest {
  BuyerCheckoutPlacementRequest({
    required this.checkoutRequestKey,
    required this.quoteToken,
    required this.addressId,
    required List<int> cartItemIds,
    BuyerCheckoutVoucherSelection? vouchers,
    String? sellerNote,
  }) : cartItemIds = List.unmodifiable(cartItemIds),
       vouchers = vouchers ?? BuyerCheckoutVoucherSelection(),
       sellerNote = _normalizeSellerNote(sellerNote) {
    if (!_isUuid(checkoutRequestKey)) {
      throw ArgumentError.value(checkoutRequestKey, 'checkoutRequestKey');
    }
    if (quoteToken.trim().isEmpty) {
      throw ArgumentError.value(quoteToken, 'quoteToken');
    }
    _validateSelection(addressId, this.cartItemIds);
    if ((this.sellerNote?.length ?? 0) > 120) {
      throw ArgumentError.value(sellerNote, 'sellerNote');
    }
  }

  final String checkoutRequestKey;
  final String quoteToken;
  final int addressId;
  final List<int> cartItemIds;
  final BuyerCheckoutVoucherSelection vouchers;
  final String? sellerNote;

  Map<String, Object?> toJson() => {
    'checkout_request_key': checkoutRequestKey,
    'quote_token': quoteToken,
    'address_id': addressId,
    'cart_item_ids': cartItemIds,
    'payment_method': 'cod',
    ...vouchers.toJson(),
    if (sellerNote != null) 'seller_note': sellerNote,
  };

  factory BuyerCheckoutPlacementRequest.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'placement_request');
    final ids = buyerCheckoutList(json['cart_item_ids'], 'cart_item_ids');
    if (ids.any((id) => id is! int)) {
      throw const BuyerCheckoutFormatException('cart_item_ids');
    }
    final request = BuyerCheckoutPlacementRequest(
      checkoutRequestKey: buyerCheckoutString(
        json,
        'checkout_request_key',
        'placement_request',
      ),
      quoteToken: buyerCheckoutString(json, 'quote_token', 'placement_request'),
      addressId: buyerCheckoutInt(json, 'address_id', 'placement_request'),
      cartItemIds: ids.cast<int>(),
      vouchers: BuyerCheckoutVoucherSelection.fromJson(json),
      sellerNote: buyerCheckoutOptionalString(
        json,
        'seller_note',
        'placement_request',
      ),
    );
    if (json['payment_method'] != 'cod') {
      throw const BuyerCheckoutFormatException('payment_method');
    }
    return request;
  }
}

String? _normalizeSellerNote(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

class BuyerCheckoutQuote {
  BuyerCheckoutQuote({
    required this.buyerAccountId,
    this.sourceRequest,
    required this.currency,
    required List<BuyerCheckoutQuoteItem> items,
    required List<BuyerCheckoutSellerGroup> sellerOrders,
    required this.deliveryAddress,
    required this.subtotalMinor,
    required this.shippingFeeMinor,
    required this.sellerDiscountMinor,
    required this.platformDiscountMinor,
    required this.shippingDiscountMinor,
    required this.discountMinor,
    required this.totalDiscountMinor,
    required this.totalMinor,
    required this.paymentMethod,
    required List<String> availablePaymentMethods,
    required this.promotionSelection,
    required List<BuyerCheckoutPromotion> appliedPromotions,
    required this.quoteToken,
    required this.quoteExpiresAt,
  }) : items = List.unmodifiable(items),
       sellerOrders = List.unmodifiable(sellerOrders),
       availablePaymentMethods = List.unmodifiable(availablePaymentMethods),
       appliedPromotions = List.unmodifiable(appliedPromotions);

  /// Local session owner; it is not returned by Laravel or serialized.
  final int buyerAccountId;

  /// Original local selection, retained so placement is bound to the exact
  /// selection that produced this quote token.
  final BuyerCheckoutQuoteRequest? sourceRequest;
  final String currency;
  final List<BuyerCheckoutQuoteItem> items;
  final List<BuyerCheckoutSellerGroup> sellerOrders;
  final BuyerCheckoutDeliveryAddress deliveryAddress;
  final int subtotalMinor;
  final int shippingFeeMinor;
  final int sellerDiscountMinor;
  final int platformDiscountMinor;
  final int shippingDiscountMinor;
  final int discountMinor;
  final int totalDiscountMinor;
  final int totalMinor;
  final String paymentMethod;
  final List<String> availablePaymentMethods;
  final BuyerCheckoutVoucherSelection promotionSelection;
  final List<BuyerCheckoutPromotion> appliedPromotions;
  final String quoteToken;
  final DateTime quoteExpiresAt;

  factory BuyerCheckoutQuote.fromResponse(
    Object? value, {
    required int buyerAccountId,
    BuyerCheckoutQuoteRequest? sourceRequest,
  }) {
    final root = buyerCheckoutMap(value, 'root');
    final data = buyerCheckoutMap(root['data'], 'data');
    final items = buyerCheckoutList(
      data['items'],
      'data.items',
    ).map(BuyerCheckoutQuoteItem.fromJson).toList(growable: false);
    final sellerOrders = buyerCheckoutList(
      data['seller_orders'],
      'data.seller_orders',
    ).map(BuyerCheckoutSellerGroup.fromJson).toList(growable: false);
    final rawMethods = buyerCheckoutList(
      data['available_payment_methods'],
      'data.available_payment_methods',
    );
    final quoteToken = buyerCheckoutString(data, 'quote_token', 'data');
    final rawPromotions = data['applied_promotions'] ?? const [];
    final rawSelection =
        data['promotion_selection'] ?? const <String, Object?>{};
    final currency = buyerCheckoutString(data, 'currency', 'data');
    final paymentMethod = buyerCheckoutString(data, 'payment_method', 'data');
    final deliveryAddress = BuyerCheckoutDeliveryAddress.fromJson(
      data['delivery_address'],
    );
    final expiresAt = buyerCheckoutDate(data, 'quote_expires_at', 'data');

    if (buyerAccountId < 1 ||
        quoteToken.isEmpty ||
        currency != 'PHP' ||
        paymentMethod != 'cod' ||
        rawMethods.any((method) => method is! String) ||
        (rawMethods as List).isEmpty ||
        !rawMethods.contains('cod')) {
      throw const BuyerCheckoutFormatException('data');
    }

    if (sourceRequest != null &&
        (deliveryAddress.id != sourceRequest.addressId ||
            items.length != sourceRequest.cartItemIds.length ||
            items.map((item) => item.cartItemId).toSet().length !=
                sourceRequest.cartItemIds.toSet().length ||
            !items
                .map((item) => item.cartItemId)
                .toSet()
                .containsAll(sourceRequest.cartItemIds))) {
      throw const BuyerCheckoutFormatException('data.selection');
    }

    return BuyerCheckoutQuote(
      buyerAccountId: buyerAccountId,
      sourceRequest: sourceRequest,
      currency: currency,
      items: items,
      sellerOrders: sellerOrders,
      deliveryAddress: deliveryAddress,
      subtotalMinor: buyerCheckoutInt(data, 'subtotal_minor', 'data'),
      shippingFeeMinor: buyerCheckoutInt(data, 'shipping_fee_minor', 'data'),
      sellerDiscountMinor: buyerCheckoutInt(
        data,
        'seller_discount_minor',
        'data',
      ),
      platformDiscountMinor: buyerCheckoutInt(
        data,
        'platform_discount_minor',
        'data',
      ),
      shippingDiscountMinor: buyerCheckoutInt(
        data,
        'shipping_discount_minor',
        'data',
      ),
      discountMinor: buyerCheckoutInt(data, 'discount_minor', 'data'),
      totalDiscountMinor: buyerCheckoutInt(
        data,
        'total_discount_minor',
        'data',
      ),
      totalMinor: buyerCheckoutInt(data, 'total_minor', 'data'),
      paymentMethod: paymentMethod,
      availablePaymentMethods: rawMethods.cast<String>(),
      promotionSelection: BuyerCheckoutVoucherSelection.fromJson(rawSelection),
      appliedPromotions: buyerCheckoutList(
        rawPromotions,
        'data.applied_promotions',
      ).map(BuyerCheckoutPromotion.fromJson).toList(growable: false),
      quoteToken: quoteToken,
      quoteExpiresAt: expiresAt,
    );
  }
}

class BuyerCheckoutQuoteItem {
  BuyerCheckoutQuoteItem({
    required this.cartItemId,
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantName,
    required Map<String, Object?> options,
    required this.quantity,
    required this.unitPriceMinor,
    required this.subtotalMinor,
    required this.sellerDiscountMinor,
    required this.platformDiscountMinor,
    required this.totalDiscountMinor,
    required this.totalMinor,
  }) : options = Map.unmodifiable(options);

  final int cartItemId;
  final int productId;
  final String productName;
  final int variantId;
  final String variantName;
  final Map<String, Object?> options;
  final int quantity;
  final int unitPriceMinor;
  final int subtotalMinor;
  final int sellerDiscountMinor;
  final int platformDiscountMinor;
  final int totalDiscountMinor;
  final int totalMinor;

  factory BuyerCheckoutQuoteItem.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'data.items[]');
    final options = buyerCheckoutMap(json['options'], 'data.items[].options');
    final item = BuyerCheckoutQuoteItem(
      cartItemId: buyerCheckoutInt(json, 'cart_item_id', 'quote_item'),
      productId: buyerCheckoutInt(json, 'product_id', 'quote_item'),
      productName: buyerCheckoutString(json, 'product_name', 'quote_item'),
      variantId: buyerCheckoutInt(json, 'variant_id', 'quote_item'),
      variantName: buyerCheckoutString(
        json,
        'variant_name',
        'quote_item',
        allowEmpty: true,
      ),
      options: options,
      quantity: buyerCheckoutInt(json, 'quantity', 'quote_item'),
      unitPriceMinor: buyerCheckoutInt(json, 'unit_price_minor', 'quote_item'),
      subtotalMinor: buyerCheckoutInt(json, 'subtotal_minor', 'quote_item'),
      sellerDiscountMinor: buyerCheckoutInt(
        json,
        'seller_discount_minor',
        'quote_item',
      ),
      platformDiscountMinor: buyerCheckoutInt(
        json,
        'platform_discount_minor',
        'quote_item',
      ),
      totalDiscountMinor: buyerCheckoutInt(
        json,
        'total_discount_minor',
        'quote_item',
      ),
      totalMinor: buyerCheckoutInt(json, 'total_minor', 'quote_item'),
    );
    if (item.cartItemId < 1 ||
        item.productId < 1 ||
        item.variantId < 1 ||
        item.quantity < 1 ||
        [
          item.unitPriceMinor,
          item.subtotalMinor,
          item.sellerDiscountMinor,
          item.platformDiscountMinor,
          item.totalDiscountMinor,
          item.totalMinor,
        ].any((value) => value < 0)) {
      throw const BuyerCheckoutFormatException('data.items[]');
    }
    return item;
  }
}

class BuyerCheckoutSellerGroup {
  const BuyerCheckoutSellerGroup({
    required this.storeId,
    required this.storeName,
    required this.itemCount,
    required this.subtotalMinor,
    required this.sellerDiscountMinor,
    required this.platformDiscountMinor,
    required this.shippingFeeMinor,
    required this.shippingDiscountMinor,
    required this.totalDiscountMinor,
    required this.totalMinor,
  });

  final int storeId;
  final String storeName;
  final int itemCount;
  final int subtotalMinor;
  final int sellerDiscountMinor;
  final int platformDiscountMinor;
  final int shippingFeeMinor;
  final int shippingDiscountMinor;
  final int totalDiscountMinor;
  final int totalMinor;

  factory BuyerCheckoutSellerGroup.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'data.seller_orders[]');
    final group = BuyerCheckoutSellerGroup(
      storeId: buyerCheckoutInt(json, 'store_id', 'seller_group'),
      storeName: buyerCheckoutString(json, 'store_name', 'seller_group'),
      itemCount: buyerCheckoutInt(json, 'item_count', 'seller_group'),
      subtotalMinor: buyerCheckoutInt(json, 'subtotal_minor', 'seller_group'),
      sellerDiscountMinor: buyerCheckoutInt(
        json,
        'seller_discount_minor',
        'seller_group',
      ),
      platformDiscountMinor: buyerCheckoutInt(
        json,
        'platform_discount_minor',
        'seller_group',
      ),
      shippingFeeMinor: buyerCheckoutInt(
        json,
        'shipping_fee_minor',
        'seller_group',
      ),
      shippingDiscountMinor: buyerCheckoutInt(
        json,
        'shipping_discount_minor',
        'seller_group',
      ),
      totalDiscountMinor: buyerCheckoutInt(
        json,
        'total_discount_minor',
        'seller_group',
      ),
      totalMinor: buyerCheckoutInt(json, 'total_minor', 'seller_group'),
    );
    if (group.storeId < 1 ||
        group.itemCount < 0 ||
        [
          group.subtotalMinor,
          group.sellerDiscountMinor,
          group.platformDiscountMinor,
          group.shippingFeeMinor,
          group.shippingDiscountMinor,
          group.totalDiscountMinor,
          group.totalMinor,
        ].any((value) => value < 0)) {
      throw const BuyerCheckoutFormatException('data.seller_orders[]');
    }
    return group;
  }
}

class BuyerCheckoutDeliveryAddress {
  const BuyerCheckoutDeliveryAddress({
    required this.id,
    required this.name,
    required this.phone,
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.postal,
    required this.isDefault,
  });

  final int id;
  final String name;
  final String phone;
  final String street;
  final String barangay;
  final String city;
  final String province;
  final String? postal;
  final bool isDefault;

  factory BuyerCheckoutDeliveryAddress.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'data.delivery_address');
    final address = BuyerCheckoutDeliveryAddress(
      id: buyerCheckoutInt(json, 'id', 'delivery_address'),
      name: buyerCheckoutString(json, 'name', 'delivery_address'),
      phone: buyerCheckoutString(json, 'phone', 'delivery_address'),
      street: buyerCheckoutString(
        json,
        'street',
        'delivery_address',
        allowEmpty: true,
      ),
      barangay: buyerCheckoutString(json, 'barangay', 'delivery_address'),
      city: buyerCheckoutString(json, 'city', 'delivery_address'),
      province: buyerCheckoutString(json, 'province', 'delivery_address'),
      postal: buyerCheckoutOptionalString(json, 'postal', 'delivery_address'),
      isDefault: buyerCheckoutBool(json, 'isDefault', 'delivery_address'),
    );
    if (address.id < 1) {
      throw const BuyerCheckoutFormatException('delivery_address.id');
    }
    return address;
  }
}

class BuyerCheckoutPromotion {
  const BuyerCheckoutPromotion({
    required this.source,
    required this.name,
    required this.discountMinor,
    required this.shippingDiscountMinor,
  });

  final String source;
  final String name;
  final int discountMinor;
  final int shippingDiscountMinor;

  factory BuyerCheckoutPromotion.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'data.applied_promotions[]');
    final promotion = BuyerCheckoutPromotion(
      source: buyerCheckoutString(json, 'source', 'promotion'),
      name: buyerCheckoutString(json, 'name', 'promotion'),
      discountMinor: buyerCheckoutInt(json, 'discount_minor', 'promotion'),
      shippingDiscountMinor: buyerCheckoutInt(
        json,
        'shipping_discount_minor',
        'promotion',
      ),
    );
    if (promotion.discountMinor < 0 || promotion.shippingDiscountMinor < 0) {
      throw const BuyerCheckoutFormatException('data.applied_promotions[]');
    }
    return promotion;
  }
}

void validateBuyerCheckoutSelection(int addressId, List<int> cartItemIds) =>
    _validateSelection(addressId, cartItemIds);

void _validateSelection(int addressId, List<int> cartItemIds) {
  if (addressId < 1) throw RangeError.value(addressId, 'addressId');
  if (cartItemIds.isEmpty ||
      cartItemIds.length > 100 ||
      cartItemIds.any((id) => id < 1) ||
      cartItemIds.toSet().length != cartItemIds.length) {
    throw ArgumentError('Choose 1 to 100 distinct positive cart-item IDs.');
  }
}

String? _normalizeVoucherCode(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.toUpperCase();
}

Map<String, Object?> buyerCheckoutMap(Object? value, String field) {
  if (value is! Map) throw BuyerCheckoutFormatException(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerCheckoutFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> buyerCheckoutList(Object? value, String field) {
  if (value is! List) throw BuyerCheckoutFormatException(field);
  return value.cast<Object?>();
}

int buyerCheckoutInt(Map<String, Object?> json, String key, String parent) {
  final value = json[key];
  if (value is! int) throw BuyerCheckoutFormatException('$parent.$key');
  return value;
}

int? buyerCheckoutOptionalInt(
  Map<String, Object?> json,
  String key,
  String parent,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw BuyerCheckoutFormatException('$parent.$key');
  return value;
}

String buyerCheckoutString(
  Map<String, Object?> json,
  String key,
  String parent, {
  bool allowEmpty = false,
}) {
  final value = json[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw BuyerCheckoutFormatException('$parent.$key');
  }
  return value;
}

String? buyerCheckoutOptionalString(
  Map<String, Object?> json,
  String key,
  String parent,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw BuyerCheckoutFormatException('$parent.$key');
  return value;
}

bool buyerCheckoutBool(Map<String, Object?> json, String key, String parent) {
  final value = json[key];
  if (value is! bool) throw BuyerCheckoutFormatException('$parent.$key');
  return value;
}

DateTime? buyerCheckoutOptionalDate(
  Map<String, Object?> json,
  String key,
  String parent,
) {
  final value = json[key];
  if (value == null || value == '') return null;
  if (value is! String) throw BuyerCheckoutFormatException('$parent.$key');
  final date = DateTime.tryParse(value);
  if (date == null) throw BuyerCheckoutFormatException('$parent.$key');
  return date;
}

DateTime buyerCheckoutDate(
  Map<String, Object?> json,
  String key,
  String parent,
) {
  final date = buyerCheckoutOptionalDate(json, key, parent);
  if (date == null) throw BuyerCheckoutFormatException('$parent.$key');
  return date;
}
