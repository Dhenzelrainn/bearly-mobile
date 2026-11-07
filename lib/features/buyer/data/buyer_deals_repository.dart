import '../../auth/data/auth_service.dart';
import '../models/buyer_deals_models.dart';

abstract interface class BuyerDealsDataSource {
  Future<BuyerDealsPageData> getDeals();
}

/// Read-only Buyer deals backed by Laravel's active campaign and promotion rules.
class BuyerDealsRepository implements BuyerDealsDataSource {
  BuyerDealsRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  @override
  Future<BuyerDealsPageData> getDeals() async {
    final response = await _authService.getWithSession(
      '/api/mobile/buyer/deals',
    );
    return BuyerDealsPageData.fromJson(response);
  }
}
