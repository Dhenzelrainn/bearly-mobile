import '../../auth/data/auth_service.dart';
import '../models/buyer_shopping_models.dart';

/// Read/write access to the authenticated Buyer's existing Laravel addresses.
class BuyerAddressRepository {
  BuyerAddressRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<List<BuyerAddress>> fetchAddresses() =>
      _authService.requestWithSession<List<BuyerAddress>>(
        method: AuthenticatedRequestMethod.get,
        path: '/api/mobile/buyer/addresses',
        parse: (response) {
          final root = _responseMap(response, 'root');
          final rawData = root['data'];
          if (rawData is! List) {
            throw const BuyerShoppingFormatException('data');
          }
          return List.unmodifiable(rawData.map(BuyerAddress.fromJson));
        },
      );

  Future<BuyerAddress> createAddress(BuyerAddressCreate address) =>
      _authService.requestWithSession<BuyerAddress>(
        method: AuthenticatedRequestMethod.post,
        path: '/api/mobile/buyer/addresses',
        body: address.toJson(),
        parse: BuyerAddress.fromMutationResponse,
      );

  Future<BuyerAddress> updateAddress({
    required int addressId,
    required BuyerAddressPatch changes,
  }) {
    _validateAddressId(addressId);
    return _authService.requestWithSession<BuyerAddress>(
      method: AuthenticatedRequestMethod.patch,
      path: '/api/mobile/buyer/addresses/$addressId',
      body: changes.toJson(),
      parse: BuyerAddress.fromMutationResponse,
    );
  }

  Future<void> deleteAddress(int addressId) {
    _validateAddressId(addressId);
    return _authService.requestWithSession<void>(
      method: AuthenticatedRequestMethod.delete,
      path: '/api/mobile/buyer/addresses/$addressId',
      parse: (response) {
        final root = _responseMap(response, 'root');
        if (!root.containsKey('data') || root['data'] != null) {
          throw const BuyerShoppingFormatException('data');
        }
      },
    );
  }

  Future<BuyerAddress> setDefaultAddress(int addressId) {
    _validateAddressId(addressId);
    return _authService.requestWithSession<BuyerAddress>(
      method: AuthenticatedRequestMethod.patch,
      path: '/api/mobile/buyer/addresses/$addressId/default',
      parse: BuyerAddress.fromMutationResponse,
    );
  }

  static void _validateAddressId(int addressId) {
    if (addressId < 1) {
      throw RangeError.value(addressId, 'addressId', 'Must be a positive ID.');
    }
  }
}

Map<String, Object?> _responseMap(Object? value, String field) {
  if (value is! Map) throw BuyerShoppingFormatException(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerShoppingFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}
