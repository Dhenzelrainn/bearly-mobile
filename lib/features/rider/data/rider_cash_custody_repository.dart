import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/rider/models/rider_cash_custody.dart';

abstract interface class RiderCashCustodyDataSource {
  Future<RiderCashCustody> load();
}

class RiderCashCustodyRepository implements RiderCashCustodyDataSource {
  const RiderCashCustodyRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  @override
  Future<RiderCashCustody> load() async {
    final response = await _authService.getWithSession(
      '/api/mobile/rider/cash-custody',
    );
    if (response is! Map || response['data'] is! Map) {
      throw const FormatException('Bearly returned invalid cash custody data.');
    }
    return RiderCashCustody.fromJson(response['data']);
  }
}
