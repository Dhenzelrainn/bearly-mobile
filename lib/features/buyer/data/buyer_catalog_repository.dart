import '../../auth/data/auth_service.dart';
import '../models/buyer_catalog_models.dart';

/// Read-only access to the Laravel mobile Buyer catalog.
///
/// Requests use the active session held by [AuthService], including a
/// remember-me-disabled in-memory token. The repository never receives or
/// stores the raw Sanctum credential.
class BuyerCatalogRepository {
  BuyerCatalogRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<BuyerCatalogProductPage> getProducts({
    String? search,
    String? category,
    BuyerCatalogSort sort = BuyerCatalogSort.featured,
    int page = 1,
    int perPage = 12,
  }) async {
    if (page < 1 || page > 1000000) {
      throw RangeError.range(page, 1, 1000000, 'page');
    }
    if (perPage < 1 || perPage > 50) {
      throw RangeError.range(perPage, 1, 50, 'perPage');
    }

    final normalizedSearch = search?.trim();
    final normalizedCategory = category?.trim();
    if ((normalizedSearch?.length ?? 0) > 120) {
      throw ArgumentError.value(
        search,
        'search',
        'Must be at most 120 characters.',
      );
    }
    if ((normalizedCategory?.length ?? 0) > 140) {
      throw ArgumentError.value(
        category,
        'category',
        'Must be at most 140 characters.',
      );
    }

    final response = await _authService.getWithSession(
      '/api/mobile/buyer/products',
      queryParameters: {
        if (normalizedSearch != null && normalizedSearch.isNotEmpty)
          'search': normalizedSearch,
        if (normalizedCategory != null && normalizedCategory.isNotEmpty)
          'category': normalizedCategory,
        'sort': sort.value,
        'page': page,
        'per_page': perPage,
      },
    );
    return BuyerCatalogProductPage.fromJson(response);
  }

  /// Laravel route-model binds this endpoint by the product's numeric ID.
  Future<BuyerCatalogProduct> getProduct(int productId) async {
    if (productId < 1) {
      throw RangeError.value(productId, 'productId', 'Must be a positive ID.');
    }
    final response = await _authService.getWithSession(
      '/api/mobile/buyer/products/$productId',
    );
    final root = _catalogMap(response, 'root');
    return BuyerCatalogProduct.fromJson(root['data']);
  }

  Future<List<BuyerCatalogCategory>> getCategories() async {
    final response = await _authService.getWithSession(
      '/api/mobile/buyer/categories',
    );
    final root = _catalogMap(response, 'root');
    final data = root['data'];
    if (data is! List) {
      throw const BuyerCatalogFormatException('data');
    }
    return List.unmodifiable(data.map(BuyerCatalogCategory.fromJson));
  }
}

Map<String, Object?> _catalogMap(Object? value, String field) {
  if (value is! Map) throw BuyerCatalogFormatException(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerCatalogFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}
