import '../../../core/network/api_client.dart';
import '../models/buyer_shopping_models.dart';

/// Read-only use of the existing Laravel PSGC and postal-code lookup routes.
class BuyerLocationRepository {
  BuyerLocationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<BuyerLocationOption>> fetchProvinces() async =>
      _parseLocationList(await _apiClient.get('/api/psgc/provinces'));

  Future<List<BuyerLocationOption>> fetchCities(String provinceCode) async {
    _validatePsgcCode(provinceCode, 'provinceCode');
    return _parseLocationList(
      await _apiClient.get('/api/psgc/provinces/$provinceCode/cities'),
    );
  }

  Future<List<BuyerLocationOption>> fetchBarangays(String cityCode) async {
    _validatePsgcCode(cityCode, 'cityCode');
    return _parseLocationList(
      await _apiClient.get('/api/psgc/cities/$cityCode/barangays'),
    );
  }

  /// Laravel accepts a PSGC city code or province/city names. It returns only
  /// `options`; an empty list means no postal choices were found in its local
  /// snapshot and is distinct from a failed request.
  Future<List<BuyerPostalCodeOption>> fetchPostalCodes({
    String? cityCode,
    String? province,
    String? city,
  }) async {
    if (cityCode != null && cityCode.isNotEmpty) {
      _validatePsgcCode(cityCode, 'cityCode');
    }
    final response = await _apiClient.get(
      '/api/postal-codes',
      queryParameters: {
        'city_code': ?cityCode,
        'province': ?province,
        'city': ?city,
      },
    );
    final root = _locationMap(response, 'root');
    final rawOptions = root['options'];
    if (rawOptions is! List) {
      throw const BuyerShoppingFormatException('options');
    }
    return List.unmodifiable(rawOptions.map(BuyerPostalCodeOption.fromJson));
  }

  static List<BuyerLocationOption> _parseLocationList(Object? value) {
    final Object? rawItems;
    if (value is List) {
      rawItems = value;
    } else if (value is Map) {
      final root = _locationMap(value, 'root');
      rawItems = root['data'];
    } else {
      throw const BuyerShoppingFormatException('data');
    }
    if (rawItems is! List) {
      throw const BuyerShoppingFormatException('data');
    }
    return List.unmodifiable(rawItems.map(BuyerLocationOption.fromJson));
  }

  static Map<String, Object?> _locationMap(Object? value, String field) {
    if (value is! Map) throw BuyerShoppingFormatException(field);
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw BuyerShoppingFormatException(field);
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static void _validatePsgcCode(String code, String name) {
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      throw ArgumentError.value(code, name, 'Must be a PSGC numeric code.');
    }
  }
}
