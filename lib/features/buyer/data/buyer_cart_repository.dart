import '../../auth/data/auth_service.dart';
import '../models/buyer_shopping_models.dart';

/// Read/write access to Laravel's persistent Buyer cart.
class BuyerCartRepository {
  BuyerCartRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<BuyerCart> fetchCart() => _authenticatedCartRequest(
    method: AuthenticatedRequestMethod.get,
    path: '/api/mobile/buyer/cart',
  );

  /// Adds a product or specific variant. Prices, stock, and totals are always
  /// supplied by Laravel and are never included in the request.
  Future<BuyerCart> addItem({
    int? productId,
    int? productVariantId,
    required int quantity,
  }) {
    if ((productId == null && productVariantId == null) ||
        (productId != null && productId < 1) ||
        (productVariantId != null && productVariantId < 1)) {
      throw ArgumentError('Provide a positive product or variant ID.');
    }
    _validateQuantity(quantity);

    return _authenticatedCartRequest(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/cart/items',
      body: {
        'product_variant_id': ?productVariantId,
        'product_id': ?productId,
        'quantity': quantity,
      },
      requireMutationItem: true,
    );
  }

  Future<BuyerCart> updateQuantity({
    required int cartItemId,
    required int quantity,
  }) {
    _validateId(cartItemId, 'cartItemId');
    _validateQuantity(quantity);
    return _authenticatedCartRequest(
      method: AuthenticatedRequestMethod.patch,
      path: '/api/mobile/buyer/cart/items/$cartItemId',
      body: {'quantity': quantity},
      requireMutationItem: true,
      expectedCartItemId: cartItemId,
    );
  }

  Future<BuyerCart> removeItem(int cartItemId) {
    _validateId(cartItemId, 'cartItemId');
    return _authenticatedCartRequest(
      method: AuthenticatedRequestMethod.delete,
      path: '/api/mobile/buyer/cart/items/$cartItemId',
    );
  }

  Future<BuyerCart> _authenticatedCartRequest({
    required AuthenticatedRequestMethod method,
    required String path,
    Map<String, Object?>? body,
    bool requireMutationItem = false,
    int? expectedCartItemId,
  }) => _authService.requestWithSession<BuyerCart>(
    method: method,
    path: path,
    body: body,
    parse: (response) {
      final cart = BuyerCart.fromResponse(response);
      if (requireMutationItem && cart.mutationItem == null) {
        throw const BuyerShoppingFormatException('data.item');
      }
      if (expectedCartItemId != null &&
          cart.mutationItem?.id != expectedCartItemId) {
        throw const BuyerShoppingFormatException('data.item.id');
      }
      return cart;
    },
  );

  static void _validateId(int value, String name) {
    if (value < 1) {
      throw RangeError.value(value, name, 'Must be a positive ID.');
    }
  }

  static void _validateQuantity(int quantity) {
    if (quantity < 1) {
      throw RangeError.value(quantity, 'quantity', 'Must be at least one.');
    }
  }
}
