import '../../auth/data/auth_service.dart';
import '../models/logistics_dashboard.dart';
import '../models/logistics_dispatch.dart';
import '../models/logistics_sorting.dart';

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

  Future<void> acceptHandoff(
    String identifier, {
    required String scanMethod,
  }) async {
    await _authService.requestWithSession<void>(
      method: AuthenticatedRequestMethod.post,
      path:
          '/api/mobile/logistics/waybills/${Uri.encodeComponent(identifier.trim())}/accept-handoff',
      body: {'scan_method': scanMethod},
      parse: (response) {
        if (response is! Map || response['data'] is! Map) {
          throw const FormatException('Missing handoff response data.');
        }

        final data = response['data'] as Map;
        final shipment = data['shipment'];
        final handoff = data['handoff'];
        final parcels = data['parcels'];
        if (data['waybill'] is! String ||
            shipment is! Map ||
            shipment['status'] != 'at_sorting_center' ||
            handoff is! Map ||
            handoff['status'] != 'accepted' ||
            data['receiving_sorting_center'] is! Map ||
            parcels is! List ||
            parcels.isEmpty ||
            parcels.any(
              (parcel) => parcel is! Map || parcel['status'] != 'received',
            )) {
          throw const FormatException(
            'Bearly returned an incomplete handoff confirmation.',
          );
        }
      },
    );
  }

  Future<LogisticsSortingQueue> sortingQueue() async =>
      LogisticsSortingQueue.fromResponse(
        await _authService.getWithSession(
          '/api/mobile/logistics/sorting-queue',
        ),
      );

  Future<LogisticsSortResult> sortParcel({
    required int parcelId,
    required int sortingZoneId,
  }) async => _authService.requestWithSession<LogisticsSortResult>(
    method: AuthenticatedRequestMethod.post,
    path: '/api/mobile/logistics/sorting/parcels/$parcelId/sort',
    body: {'sorting_zone_id': sortingZoneId},
    parse: LogisticsSortResult.fromResponse,
  );

  Future<LogisticsDispatchBoard> dispatchBoard() async =>
      LogisticsDispatchBoard.fromResponse(
        await _authService.getWithSession(
          '/api/mobile/logistics/dispatch-board',
        ),
      );

  Future<LogisticsDispatchResult> dispatchZone({
    required int zoneId,
    required int riderProfileId,
  }) async => _authService.requestWithSession<LogisticsDispatchResult>(
    method: AuthenticatedRequestMethod.post,
    path: '/api/mobile/logistics/dispatch/zones/$zoneId/dispatch',
    body: {'rider_profile_id': riderProfileId},
    parse: LogisticsDispatchResult.fromResponse,
  );
}
