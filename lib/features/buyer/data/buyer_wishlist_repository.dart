import '../../auth/data/auth_service.dart';
import '../models/buyer_shopping_models.dart';

/// Read/write access to saved products in Laravel's Buyer wishlist.
class BuyerWishlistRepository {
  BuyerWishlistRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<BuyerWishlistPage> fetchSavedProducts({
    int page = 1,
    int perPage = 12,
  }) {
    if (page < 1 || page > 1000000) {
      throw RangeError.range(page, 1, 1000000, 'page');
    }
    if (perPage < 1 || perPage > 50) {
      throw RangeError.range(perPage, 1, 50, 'perPage');
    }

    return _authService.requestWithSession<BuyerWishlistPage>(
      method: AuthenticatedRequestMethod.get,
      path: '/api/mobile/buyer/wishlist',
      queryParameters: {'page': page, 'per_page': perPage},
      parse: BuyerWishlistPage.fromResponse,
    );
  }

  /// [productId] is the Laravel product ID, never a variant or wishlist ID.
  Future<BuyerWishlistMutationResult> saveProduct(int productId) =>
      _mutate(productId, AuthenticatedRequestMethod.put, isSave: true);

  /// Repeated removal is still authoritative: Laravel returns `is_saved:false`.
  Future<BuyerWishlistMutationResult> removeProduct(int productId) =>
      _mutate(productId, AuthenticatedRequestMethod.delete, isSave: false);

  Future<BuyerWishlistMutationResult> _mutate(
    int productId,
    AuthenticatedRequestMethod method, {
    required bool isSave,
  }) {
    if (productId < 1) {
      throw RangeError.value(productId, 'productId', 'Must be a positive ID.');
    }

    return _authService.requestWithSession<BuyerWishlistMutationResult>(
      method: method,
      path: '/api/mobile/buyer/wishlist/$productId',
      parse: (response) {
        final result = BuyerWishlistMutationResult.fromResponse(response);
        if (result.productId != productId) {
          throw const BuyerShoppingFormatException('data.product_id');
        }
        // Keep the server's state; checking the expected operation guards
        // against a malformed or stale response without inventing success.
        if (result.isSaved != isSave) {
          throw const BuyerShoppingFormatException('data.is_saved');
        }
        return result;
      },
    );
  }
}
