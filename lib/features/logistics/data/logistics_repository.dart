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

  Future<void> receiveWaybill(
    String identifier, {
    required String scanMethod,
  }) async {
    await _authService.requestWithSession<void>(
      method: AuthenticatedRequestMethod.post,
      path:
          '/api/mobile/logistics/waybills/${Uri.encodeComponent(identifier.trim())}/receive',
      body: {'scan_method': scanMethod},
      parse: (response) {
        if (response is! Map || response['data'] is! Map) {
          throw const FormatException('Missing receipt response data.');
        }

        final data = response['data'] as Map;
        final shipment = data['shipment'];
        final parcels = data['parcels'];
        if (data['waybill'] is! String ||
            shipment is! Map ||
            shipment['status'] != 'at_sorting_center' ||
            parcels is! List ||
            parcels.isEmpty ||
            parcels.any(
              (parcel) => parcel is! Map || parcel['status'] != 'received',
            )) {
          throw const FormatException(
            'Bearly returned an incomplete receipt confirmation.',
          );
        }
      },
    );
  }
}
