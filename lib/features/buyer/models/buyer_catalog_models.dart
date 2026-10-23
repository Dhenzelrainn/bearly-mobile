/// Sort values accepted by Laravel's mobile Buyer catalog endpoint.
enum BuyerCatalogSort {
  featured('featured'),
  newest('newest'),
  priceLow('price_low'),
  priceHigh('price_high');

  const BuyerCatalogSort(this.value);

  final String value;

  static BuyerCatalogSort fromValue(String value) {
    for (final option in values) {
      if (option.value == value) return option;
    }
    throw BuyerCatalogFormatException('filters.sort');
  }
}

class BuyerCatalogFormatException implements Exception {
  const BuyerCatalogFormatException(this.field);

  /// Field path only; response bodies and user data are never included.
  final String field;

  @override
  String toString() => 'Invalid Buyer catalog response field: $field.';
}

class BuyerCatalogProductPage {
  BuyerCatalogProductPage({
    required List<BuyerCatalogProduct> products,
    required this.pagination,
    required this.filters,
  }) : products = List.unmodifiable(products);

  final List<BuyerCatalogProduct> products;
  final BuyerCatalogPagination pagination;
  final BuyerCatalogFilters filters;

  factory BuyerCatalogProductPage.fromJson(Object? value) {
    final json = _jsonMap(value, 'root');
    final data = json['data'];
    if (data is! List) {
      throw const BuyerCatalogFormatException('data');
    }

    return BuyerCatalogProductPage(
      products: data.map(BuyerCatalogProduct.fromJson).toList(growable: false),
      pagination: BuyerCatalogPagination.fromJson(json['meta']),
      filters: BuyerCatalogFilters.fromJson(json['filters']),
    );
  }
}

class BuyerCatalogPagination {
  const BuyerCatalogPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMore,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMore;

  factory BuyerCatalogPagination.fromJson(Object? value) {
    final json = _jsonMap(value, 'meta');
    final currentPage = _requiredInt(json, 'current_page', 'meta');
    final perPage = _requiredInt(json, 'per_page', 'meta');
    final total = _requiredInt(json, 'total', 'meta');
    final lastPage = _requiredInt(json, 'last_page', 'meta');
    final hasMore = _requiredBool(json, 'has_more', 'meta');
    if (currentPage < 1 || perPage < 1 || total < 0 || lastPage < 1) {
      throw const BuyerCatalogFormatException('meta');
    }
    return BuyerCatalogPagination(
      currentPage: currentPage,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
      hasMore: hasMore,
    );
  }
}

class BuyerCatalogFilters {
  const BuyerCatalogFilters({
    required this.search,
    required this.category,
    required this.sort,
  });

  final String search;
  final String? category;
  final BuyerCatalogSort sort;

  factory BuyerCatalogFilters.fromJson(Object? value) {
    final json = _jsonMap(value, 'filters');
    final search = _requiredString(json, 'search', 'filters', allowEmpty: true);
    final categoryValue = json['category'];
    if (categoryValue != null && categoryValue is! String) {
      throw const BuyerCatalogFormatException('filters.category');
    }
    return BuyerCatalogFilters(
      search: search,
      category: categoryValue as String?,
      sort: BuyerCatalogSort.fromValue(
        _requiredString(json, 'sort', 'filters'),
      ),
    );
  }
}

class BuyerCatalogProduct {
  BuyerCatalogProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.descriptionSummary,
    required this.store,
    required this.category,
    required this.priceMinor,
    required this.regularPriceMinor,
    required this.discountPercent,
    required this.currency,
    required this.imageUrl,
    required this.inStock,
    required List<BuyerCatalogVariant> variants,
    required this.ratingSummary,
    required List<BuyerProductImage> images,
  }) : variants = List.unmodifiable(variants),
       images = List.unmodifiable(images);

  final int id;
  final String slug;
  final String name;
  final String description;
  final String descriptionSummary;
  final BuyerCatalogStore? store;
  final BuyerCatalogCategory? category;
  final int priceMinor;
  final int regularPriceMinor;
  final int discountPercent;
  final String currency;
  final String? imageUrl;
  final bool inStock;
  final List<BuyerCatalogVariant> variants;
  final BuyerRatingSummary ratingSummary;
  final List<BuyerProductImage> images;

  String get formattedPrice =>
      formatPriceMinorUnits(priceMinor, currency: currency);

  String get formattedRegularPrice =>
      formatPriceMinorUnits(regularPriceMinor, currency: currency);

  factory BuyerCatalogProduct.fromJson(Object? value) {
    final json = _jsonMap(value, 'product');
    final id = _requiredInt(json, 'id', 'product');
    final priceMinor = _requiredInt(json, 'price_minor', 'product');
    final regularPriceMinor = _requiredInt(
      json,
      'regular_price_minor',
      'product',
    );
    final discountPercent = _requiredInt(json, 'discount_percent', 'product');
    if (id < 1 ||
        priceMinor < 0 ||
        regularPriceMinor < 0 ||
        discountPercent < 0) {
      throw const BuyerCatalogFormatException('product');
    }

    final rawVariants = json['variants'];
    if (rawVariants is! List) {
      throw const BuyerCatalogFormatException('product.variants');
    }
    final rawImages = json['images'];
    if (rawImages != null && rawImages is! List) {
      throw const BuyerCatalogFormatException('product.images');
    }

    return BuyerCatalogProduct(
      id: id,
      slug: _requiredString(json, 'slug', 'product'),
      name: _requiredString(json, 'name', 'product'),
      description: _requiredString(
        json,
        'description',
        'product',
        allowEmpty: true,
      ),
      descriptionSummary: _requiredString(
        json,
        'description_summary',
        'product',
        allowEmpty: true,
      ),
      store: json['store'] == null
          ? null
          : BuyerCatalogStore.fromJson(json['store']),
      category: json['category'] == null
          ? null
          : BuyerCatalogCategory.fromJson(json['category']),
      priceMinor: priceMinor,
      regularPriceMinor: regularPriceMinor,
      discountPercent: discountPercent,
      currency: _requiredString(json, 'currency', 'product'),
      imageUrl: _publicHttpsUrl(json['image_url']),
      inStock: _requiredBool(json, 'in_stock', 'product'),
      variants: rawVariants
          .map(BuyerCatalogVariant.fromJson)
          .toList(growable: false),
      ratingSummary: BuyerRatingSummary.fromJson(json['rating_summary']),
      images: rawImages == null
          ? const []
          : (rawImages as List)
                .map(BuyerProductImage.tryFromJson)
                .whereType<BuyerProductImage>()
                .toList(growable: false),
    );
  }
}

class BuyerCatalogStore {
  const BuyerCatalogStore({required this.name, required this.slug});

  final String name;
  final String slug;

  factory BuyerCatalogStore.fromJson(Object? value) {
    final json = _jsonMap(value, 'product.store');
    return BuyerCatalogStore(
      name: _requiredString(json, 'name', 'product.store'),
      slug: _requiredString(json, 'slug', 'product.store'),
    );
  }
}

class BuyerCatalogCategory {
  const BuyerCatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.parent,
  });

  final int id;
  final String name;
  final String slug;
  final BuyerCatalogCategory? parent;

  factory BuyerCatalogCategory.fromJson(Object? value) {
    final json = _jsonMap(value, 'category');
    return BuyerCatalogCategory(
      id: _positiveInt(json, 'id', 'category'),
      name: _requiredString(json, 'name', 'category'),
      slug: _requiredString(json, 'slug', 'category'),
      parent: json['parent'] == null
          ? null
          : _categoryParentFromJson(json['parent']),
    );
  }
}

class BuyerCatalogVariant {
  BuyerCatalogVariant({
    required this.id,
    required this.name,
    required Map<String, Object?> options,
    required this.priceMinor,
    required this.regularPriceMinor,
    required this.discountPercent,
    required this.currency,
    required this.inStock,
  }) : options = Map.unmodifiable(options);

  final int id;
  final String name;
  final Map<String, Object?> options;
  final int priceMinor;
  final int regularPriceMinor;
  final int discountPercent;
  final String currency;
  final bool inStock;

  String get formattedPrice =>
      formatPriceMinorUnits(priceMinor, currency: currency);

  factory BuyerCatalogVariant.fromJson(Object? value) {
    final json = _jsonMap(value, 'product.variants[]');
    final priceMinor = _requiredInt(json, 'price_minor', 'variant');
    final regularPriceMinor = _requiredInt(
      json,
      'regular_price_minor',
      'variant',
    );
    final discountPercent = _requiredInt(json, 'discount_percent', 'variant');
    final rawOptions = json['options'];
    if (priceMinor < 0 || regularPriceMinor < 0 || discountPercent < 0) {
      throw const BuyerCatalogFormatException('variant.price');
    }
    if (rawOptions is! Map) {
      throw const BuyerCatalogFormatException('variant.options');
    }
    return BuyerCatalogVariant(
      id: _positiveInt(json, 'id', 'variant'),
      name: _requiredString(json, 'name', 'variant', allowEmpty: true),
      options: _stringKeyMap(rawOptions, 'variant.options'),
      priceMinor: priceMinor,
      regularPriceMinor: regularPriceMinor,
      discountPercent: discountPercent,
      currency: _requiredString(json, 'currency', 'variant'),
      inStock: _requiredBool(json, 'in_stock', 'variant'),
    );
  }
}

class BuyerRatingSummary {
  const BuyerRatingSummary({required this.average, required this.count});

  final double average;
  final int count;

  factory BuyerRatingSummary.fromJson(Object? value) {
    final json = _jsonMap(value, 'rating_summary');
    final rawAverage = json['average'];
    if (rawAverage is! num || !rawAverage.isFinite || rawAverage < 0) {
      throw const BuyerCatalogFormatException('rating_summary.average');
    }
    final count = _requiredInt(json, 'count', 'rating_summary');
    if (count < 0) {
      throw const BuyerCatalogFormatException('rating_summary.count');
    }
    return BuyerRatingSummary(average: rawAverage.toDouble(), count: count);
  }
}

class BuyerProductImage {
  const BuyerProductImage({
    required this.url,
    required this.altText,
    required this.variantId,
    required this.isPrimary,
  });

  final String url;
  final String? altText;
  final int? variantId;
  final bool isPrimary;

  static BuyerProductImage? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = _stringKeyMap(value, 'product.images[]');
    final url = _publicHttpsUrl(json['url']);
    final isPrimary = json['is_primary'];
    final rawVariantId = json['variant_id'];
    if (url == null ||
        isPrimary is! bool ||
        (rawVariantId != null && (rawVariantId is! int || rawVariantId < 1))) {
      return null;
    }
    final rawAltText = json['alt_text'];
    return BuyerProductImage(
      url: url,
      altText: rawAltText is String ? rawAltText : null,
      variantId: rawVariantId as int?,
      isPrimary: isPrimary,
    );
  }
}

/// Formats integer minor-unit values without floating-point arithmetic.
String formatPriceMinorUnits(int priceMinor, {required String currency}) {
  final absolute = priceMinor.abs();
  final whole = (absolute ~/ 100).toString();
  final groupedWhole = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) {
      groupedWhole.write(',');
    }
    groupedWhole.write(whole[index]);
  }
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final prefix = currency == 'PHP' ? '₱' : '$currency ';
  final sign = priceMinor < 0 ? '-' : '';
  return '$sign$prefix$groupedWhole.$fraction';
}

BuyerCatalogCategory _categoryParentFromJson(Object? value) {
  final json = _jsonMap(value, 'category.parent');
  return BuyerCatalogCategory(
    id: _positiveInt(json, 'id', 'category.parent'),
    name: _requiredString(json, 'name', 'category.parent'),
    slug: _requiredString(json, 'slug', 'category.parent'),
    parent: null,
  );
}

Map<String, Object?> _jsonMap(Object? value, String field) {
  if (value is! Map) throw BuyerCatalogFormatException(field);
  return _stringKeyMap(value, field);
}

Map<String, Object?> _stringKeyMap(Map value, String field) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerCatalogFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _requiredString(
  Map<String, Object?> json,
  String key,
  String parent, {
  bool allowEmpty = false,
}) {
  final value = json[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw BuyerCatalogFormatException('$parent.$key');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key, String parent) {
  final value = json[key];
  if (value is! int) throw BuyerCatalogFormatException('$parent.$key');
  return value;
}

int _positiveInt(Map<String, Object?> json, String key, String parent) {
  final value = _requiredInt(json, key, parent);
  if (value < 1) throw BuyerCatalogFormatException('$parent.$key');
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key, String parent) {
  final value = json[key];
  if (value is! bool) throw BuyerCatalogFormatException('$parent.$key');
  return value;
}

String? _publicHttpsUrl(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final candidate = value.trim();
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return candidate;
}
