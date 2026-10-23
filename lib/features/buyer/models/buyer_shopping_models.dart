import 'buyer_catalog_models.dart';

/// Safe contract error for malformed cart, wishlist, address, or location JSON.
class BuyerShoppingFormatException implements Exception {
  const BuyerShoppingFormatException(this.field);

  /// A field path only. Response bodies and private values are never included.
  final String field;

  @override
  String toString() => 'Invalid Buyer shopping response field: $field.';
}

class BuyerCart {
  BuyerCart({
    required List<BuyerCartItem> items,
    required this.cartCount,
    required this.subtotalMinor,
    required this.currency,
    this.mutationItem,
  }) : items = List.unmodifiable(items);

  final List<BuyerCartItem> items;
  final int cartCount;
  final int subtotalMinor;
  final String currency;

  /// Present after Laravel add/update responses; absent after GET/remove.
  final BuyerCartItem? mutationItem;

  factory BuyerCart.fromResponse(Object? value) {
    final root = _shoppingMap(value, 'root');
    final data = _shoppingMap(root['data'], 'data');
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const BuyerShoppingFormatException('data.items');
    }
    final cartCount = _shoppingInt(data, 'cart_count', 'data');
    final subtotalMinor = _shoppingInt(data, 'subtotal_minor', 'data');
    if (cartCount < 0 || subtotalMinor < 0) {
      throw const BuyerShoppingFormatException('data');
    }
    final rawMutationItem = data['item'];

    return BuyerCart(
      items: rawItems
          .map((item) => BuyerCartItem.fromJson(item))
          .toList(growable: false),
      cartCount: cartCount,
      subtotalMinor: subtotalMinor,
      currency: _shoppingString(data, 'currency', 'data'),
      mutationItem: rawMutationItem == null
          ? null
          : BuyerCartItem.fromJson(rawMutationItem),
    );
  }
}

class BuyerCartItem {
  const BuyerCartItem({
    required this.id,
    required this.productId,
    required this.productVariantId,
    required this.product,
    required this.variant,
    required this.name,
    required this.variantName,
    required this.options,
    required this.priceMinor,
    required this.unitPriceMinor,
    required this.lineSubtotalMinor,
    required this.regularPriceMinor,
    required this.discountPercent,
    required this.campaignName,
    required this.quantity,
    required this.selected,
    required this.image,
    required this.imageUrl,
    required this.availableStock,
    required this.inStock,
    required this.isAvailable,
    required this.storeName,
    required this.sellerName,
  });

  /// Laravel cart_items.id. This is not a product or variant ID.
  final int id;
  final int? productId;
  final int? productVariantId;
  final BuyerCartProductInfo? product;
  final BuyerCartVariantInfo? variant;
  final String name;
  final String variantName;
  final Map<String, Object?> options;
  final int priceMinor;
  final int unitPriceMinor;
  final int lineSubtotalMinor;
  final int regularPriceMinor;
  final int discountPercent;
  final String? campaignName;
  final int quantity;
  final bool selected;
  final String image;
  final String? imageUrl;
  final int availableStock;
  final bool inStock;
  final bool isAvailable;
  final String? storeName;
  final String sellerName;

  factory BuyerCartItem.fromJson(Object? value) {
    final json = _shoppingMap(value, 'data.items[]');
    final id = _shoppingInt(json, 'id', 'cart_item');
    final productId = _shoppingOptionalInt(json, 'product_id', 'cart_item');
    final variantId = _shoppingOptionalInt(
      json,
      'product_variant_id',
      'cart_item',
    );
    final quantity = _shoppingInt(json, 'quantity', 'cart_item');
    final priceMinor = _shoppingInt(json, 'price_minor', 'cart_item');
    final unitPriceMinor = _shoppingInt(json, 'unit_price_minor', 'cart_item');
    final lineSubtotalMinor = _shoppingInt(
      json,
      'line_subtotal_minor',
      'cart_item',
    );
    final regularPriceMinor = _shoppingInt(
      json,
      'regular_price_minor',
      'cart_item',
    );
    final discountPercent = _shoppingInt(json, 'discount_percent', 'cart_item');
    final availableStock = _shoppingInt(json, 'available_stock', 'cart_item');
    final rawOptions = json['options'];
    if (rawOptions is! Map) {
      throw const BuyerShoppingFormatException('cart_item.options');
    }
    if (id < 1 ||
        (productId != null && productId < 1) ||
        (variantId != null && variantId < 1) ||
        quantity < 1 ||
        priceMinor < 0 ||
        unitPriceMinor < 0 ||
        lineSubtotalMinor < 0 ||
        regularPriceMinor < 0 ||
        discountPercent < 0 ||
        availableStock < 0) {
      throw const BuyerShoppingFormatException('cart_item');
    }

    final rawProduct = json['product'];
    final rawVariant = json['variant'];
    final product = rawProduct == null
        ? null
        : BuyerCartProductInfo.fromJson(rawProduct);
    final variant = rawVariant == null
        ? null
        : BuyerCartVariantInfo.fromJson(rawVariant);
    if ((productId != null && product != null && productId != product.id) ||
        (variantId != null && variant != null && variantId != variant.id)) {
      throw const BuyerShoppingFormatException('cart_item.identifiers');
    }
    final campaignName = json['campaign_name'];
    if (campaignName != null && campaignName is! String) {
      throw const BuyerShoppingFormatException('cart_item.campaign_name');
    }

    return BuyerCartItem(
      id: id,
      productId: productId,
      productVariantId: variantId,
      product: product,
      variant: variant,
      name: _shoppingString(json, 'name', 'cart_item', allowEmpty: true),
      variantName: _shoppingString(
        json,
        'variant_name',
        'cart_item',
        allowEmpty: true,
      ),
      options: _shoppingStringKeyMap(rawOptions, 'cart_item.options'),
      priceMinor: priceMinor,
      unitPriceMinor: unitPriceMinor,
      lineSubtotalMinor: lineSubtotalMinor,
      regularPriceMinor: regularPriceMinor,
      discountPercent: discountPercent,
      campaignName: campaignName as String?,
      quantity: quantity,
      selected: _shoppingBool(json, 'selected', 'cart_item'),
      image: _shoppingString(json, 'image', 'cart_item', allowEmpty: true),
      imageUrl: _shoppingOptionalString(json, 'image_url', 'cart_item'),
      availableStock: availableStock,
      inStock: _shoppingBool(json, 'in_stock', 'cart_item'),
      isAvailable: _shoppingBool(json, 'is_available', 'cart_item'),
      storeName: _shoppingOptionalString(json, 'store_name', 'cart_item'),
      sellerName: _shoppingString(json, 'seller_name', 'cart_item'),
    );
  }
}

class BuyerCartProductInfo {
  const BuyerCartProductInfo({required this.id, required this.name});

  final int id;
  final String name;

  factory BuyerCartProductInfo.fromJson(Object? value) {
    final json = _shoppingMap(value, 'cart_item.product');
    final id = _shoppingInt(json, 'id', 'cart_item.product');
    if (id < 1) {
      throw const BuyerShoppingFormatException('cart_item.product.id');
    }
    return BuyerCartProductInfo(
      id: id,
      name: _shoppingString(json, 'name', 'cart_item.product'),
    );
  }
}

class BuyerCartVariantInfo {
  BuyerCartVariantInfo({
    required this.id,
    required this.name,
    required Map<String, Object?> options,
  }) : options = Map.unmodifiable(options);

  final int id;
  final String name;
  final Map<String, Object?> options;

  factory BuyerCartVariantInfo.fromJson(Object? value) {
    final json = _shoppingMap(value, 'cart_item.variant');
    final id = _shoppingInt(json, 'id', 'cart_item.variant');
    if (id < 1) {
      throw const BuyerShoppingFormatException('cart_item.variant.id');
    }
    final rawOptions = json['options'];
    if (rawOptions is! Map) {
      throw const BuyerShoppingFormatException('cart_item.variant.options');
    }
    return BuyerCartVariantInfo(
      id: id,
      name: _shoppingString(
        json,
        'name',
        'cart_item.variant',
        allowEmpty: true,
      ),
      options: _shoppingStringKeyMap(rawOptions, 'cart_item.variant.options'),
    );
  }
}

class BuyerWishlistPage {
  BuyerWishlistPage({
    required List<BuyerSavedProduct> entries,
    required this.pagination,
  }) : entries = List.unmodifiable(entries);

  final List<BuyerSavedProduct> entries;
  final BuyerCatalogPagination pagination;

  factory BuyerWishlistPage.fromResponse(Object? value) {
    final root = _shoppingMap(value, 'root');
    final rawEntries = root['data'];
    if (rawEntries is! List) {
      throw const BuyerShoppingFormatException('data');
    }
    final rawMeta = root['meta'];
    final pagination = BuyerCatalogPagination.fromJson(rawMeta);
    return BuyerWishlistPage(
      entries: rawEntries
          .map((entry) => BuyerSavedProduct.fromJson(entry))
          .toList(growable: false),
      pagination: pagination,
    );
  }
}

class BuyerSavedProduct {
  const BuyerSavedProduct({
    required this.wishlistId,
    required this.savedAt,
    required this.product,
  });

  final int wishlistId;
  final DateTime? savedAt;
  final BuyerCatalogProduct product;

  factory BuyerSavedProduct.fromJson(Object? value) {
    final json = _shoppingMap(value, 'data[]');
    final wishlistId = _shoppingInt(json, 'wishlist_id', 'wishlist_entry');
    if (wishlistId < 1) {
      throw const BuyerShoppingFormatException('wishlist_entry.wishlist_id');
    }
    final rawSavedAt = json['saved_at'];
    final DateTime? savedAt;
    if (rawSavedAt == null) {
      savedAt = null;
    } else if (rawSavedAt is String) {
      savedAt = DateTime.tryParse(rawSavedAt);
      if (savedAt == null) {
        throw const BuyerShoppingFormatException('wishlist_entry.saved_at');
      }
    } else {
      throw const BuyerShoppingFormatException('wishlist_entry.saved_at');
    }

    return BuyerSavedProduct(
      wishlistId: wishlistId,
      savedAt: savedAt,
      product: BuyerCatalogProduct.fromJson(json['product']),
    );
  }
}

class BuyerWishlistMutationResult {
  const BuyerWishlistMutationResult({
    required this.productId,
    required this.isSaved,
  });

  final int productId;
  final bool isSaved;

  factory BuyerWishlistMutationResult.fromResponse(Object? value) {
    final root = _shoppingMap(value, 'root');
    final data = _shoppingMap(root['data'], 'data');
    final productId = _shoppingInt(data, 'product_id', 'data');
    if (productId < 1) {
      throw const BuyerShoppingFormatException('data.product_id');
    }
    return BuyerWishlistMutationResult(
      productId: productId,
      isSaved: _shoppingBool(data, 'is_saved', 'data'),
    );
  }
}

class BuyerAddress {
  const BuyerAddress({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.province,
    required this.city,
    required this.barangay,
    required this.postal,
    required this.street,
    required this.isDefault,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String label;
  final String name;
  final String phone;
  final String province;
  final String city;
  final String barangay;
  final String postal;
  final String street;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  factory BuyerAddress.fromJson(Object? value) {
    final json = _shoppingMap(value, 'address');
    final id = _shoppingInt(json, 'id', 'address');
    final latitude = _shoppingOptionalDouble(json, 'latitude', 'address');
    final longitude = _shoppingOptionalDouble(json, 'longitude', 'address');
    if (id < 1 ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      throw const BuyerShoppingFormatException('address');
    }
    return BuyerAddress(
      id: id,
      label: _shoppingString(json, 'label', 'address'),
      name: _shoppingString(json, 'name', 'address'),
      phone: _shoppingString(json, 'phone', 'address'),
      province: _shoppingString(json, 'province', 'address'),
      city: _shoppingString(json, 'city', 'address'),
      barangay: _shoppingString(json, 'barangay', 'address'),
      postal: _shoppingString(json, 'postal', 'address'),
      street: _shoppingString(json, 'street', 'address'),
      isDefault: _shoppingBool(json, 'isDefault', 'address'),
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory BuyerAddress.fromMutationResponse(Object? value) {
    final root = _shoppingMap(value, 'root');
    return BuyerAddress.fromJson(root['data']);
  }
}

/// Typed create request using Laravel's write-side names.
class BuyerAddressCreate {
  const BuyerAddressCreate({
    required this.name,
    required this.phone,
    required this.province,
    required this.city,
    required this.barangay,
    required this.postal,
    required this.street,
    required this.label,
    this.cityCode,
    this.isDefault,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String phone;
  final String province;
  final String city;
  final String barangay;
  final String postal;
  final String street;
  final String label;
  final String? cityCode;
  final bool? isDefault;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'province': province,
    'city': city,
    'barangay': barangay,
    'postal': postal,
    'street': street,
    'label': label,
    if (cityCode != null) 'city_code': cityCode,
    if (isDefault != null) 'is_default': isDefault,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

/// Partial request map. Only fields supported by Laravel are accepted, and
/// explicit null values are retained (for example, to clear coordinates).
class BuyerAddressPatch {
  BuyerAddressPatch(Map<String, Object?> changes)
    : changes = Map.unmodifiable(_addressPatchFields(changes));

  static const Set<String> allowedFields = {
    'name',
    'phone',
    'province',
    'city',
    'barangay',
    'postal',
    'street',
    'label',
    'city_code',
    'is_default',
    'latitude',
    'longitude',
  };

  final Map<String, Object?> changes;

  Map<String, Object?> toJson() => Map.unmodifiable(changes);
}

class BuyerLocationOption {
  BuyerLocationOption({
    required this.code,
    required this.name,
    required Map<String, Object?> metadata,
  }) : metadata = Map.unmodifiable(metadata);

  /// Keep PSGC codes as strings so leading zeroes are preserved.
  final String code;
  final String name;

  /// Other fields returned by PSGC v2 (for example region, province, type,
  /// status, or city_municipality), retained without guessing their types.
  final Map<String, Object?> metadata;

  factory BuyerLocationOption.fromJson(Object? value) {
    final json = _shoppingMap(value, 'location');
    final code = _shoppingString(json, 'code', 'location');
    final name = _shoppingString(json, 'name', 'location');
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      throw const BuyerShoppingFormatException('location.code');
    }
    final metadata = <String, Object?>{
      for (final entry in json.entries)
        if (entry.key != 'code' && entry.key != 'name') entry.key: entry.value,
    };
    return BuyerLocationOption(code: code, name: name, metadata: metadata);
  }
}

class BuyerPostalCodeOption {
  const BuyerPostalCodeOption({required this.code, required this.area});

  final String code;
  final String? area;

  factory BuyerPostalCodeOption.fromJson(Object? value) {
    final json = _shoppingMap(value, 'postal_option');
    final code = _shoppingString(json, 'code', 'postal_option');
    final area = _shoppingOptionalString(json, 'area', 'postal_option');
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      throw const BuyerShoppingFormatException('postal_option.code');
    }
    return BuyerPostalCodeOption(code: code, area: area);
  }
}

/// Selection state for cascading location controls. Changing a parent drops
/// stale descendants before M3C presents the new options.
class BuyerLocationSelection {
  const BuyerLocationSelection({
    this.provinceCode,
    this.cityCode,
    this.barangayCode,
  });

  final String? provinceCode;
  final String? cityCode;
  final String? barangayCode;

  BuyerLocationSelection selectProvince(String? code) =>
      BuyerLocationSelection(provinceCode: code);

  BuyerLocationSelection selectCity(String? code) =>
      BuyerLocationSelection(provinceCode: provinceCode, cityCode: code);

  BuyerLocationSelection selectBarangay(String? code) => BuyerLocationSelection(
    provinceCode: provinceCode,
    cityCode: cityCode,
    barangayCode: code,
  );
}

Map<String, Object?> _shoppingMap(Object? value, String field) {
  if (value is! Map) throw BuyerShoppingFormatException(field);
  return _shoppingStringKeyMap(value, field);
}

Map<String, Object?> _shoppingStringKeyMap(Map value, String field) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerShoppingFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

int _shoppingInt(Map<String, Object?> json, String key, String parent) {
  final value = json[key];
  if (value is! int) {
    throw BuyerShoppingFormatException('$parent.$key');
  }
  return value;
}

int? _shoppingOptionalInt(
  Map<String, Object?> json,
  String key,
  String parent,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw BuyerShoppingFormatException('$parent.$key');
  }
  return value;
}

double? _shoppingOptionalDouble(
  Map<String, Object?> json,
  String key,
  String parent,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw BuyerShoppingFormatException('$parent.$key');
  }
  return value.toDouble();
}

String _shoppingString(
  Map<String, Object?> json,
  String key,
  String parent, {
  bool allowEmpty = false,
}) {
  final value = json[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw BuyerShoppingFormatException('$parent.$key');
  }
  return value;
}

String? _shoppingOptionalString(
  Map<String, Object?> json,
  String key,
  String parent,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw BuyerShoppingFormatException('$parent.$key');
  }
  return value;
}

bool _shoppingBool(Map<String, Object?> json, String key, String parent) {
  final value = json[key];
  if (value is! bool) {
    throw BuyerShoppingFormatException('$parent.$key');
  }
  return value;
}

Map<String, Object?> _addressPatchFields(Map<String, Object?> changes) {
  for (final key in changes.keys) {
    if (!BuyerAddressPatch.allowedFields.contains(key)) {
      throw ArgumentError.value(key, 'changes', 'Unsupported address field.');
    }
  }
  return changes;
}
