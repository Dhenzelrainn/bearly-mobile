import '../../auth/data/auth_service.dart';
import '../models/logistics_dashboard.dart';

class LogisticsRepository {
  const LogisticsRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<LogisticsDashboard> dashboard() async =>
      LogisticsDashboard.fromResponse(
        await _authService.getWithSession('/api/mobile/logistics/dashboard'),
      );

  Future<LogisticsWaybillLookup> lookupWaybill(
    String identifier,
  ) async => LogisticsWaybillLookup.fromResponse(
    await _authService.getWithSession(
      '/api/mobile/logistics/waybills/${Uri.encodeComponent(identifier.trim())}',
    ),
  );
}
