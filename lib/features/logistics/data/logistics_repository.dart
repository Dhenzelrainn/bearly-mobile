import '../../auth/data/auth_service.dart';
import '../models/logistics_dashboard.dart';
import '../models/logistics_city_handoffs.dart';
import '../models/logistics_dispatch.dart';
import '../models/logistics_incoming_parcel.dart';
import '../models/logistics_monitoring.dart';
import '../models/logistics_pickup_request.dart';
import '../models/logistics_rider.dart';
import '../models/logistics_rider_application.dart';
import '../models/logistics_sorting.dart';
import '../models/logistics_sorting_workspace.dart';

class LogisticsRepository {
  const LogisticsRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<LogisticsDashboard> dashboard() async =>
      LogisticsDashboard.fromResponse(
        await _authService.getWithSession('/api/mobile/logistics/dashboard'),
      );

  Future<LogisticsCityHandoffsPage> cityHandoffs({
    String view = 'incoming',
    String status = 'sent',
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    const transferStatuses = {'sent', 'accepted', 'all'};
    const runStatuses = {'active', 'completed', 'all'};
    if (!{'incoming', 'outgoing', 'runs'}.contains(view) ||
        !(view == 'runs' ? runStatuses : transferStatuses).contains(status) ||
        page < 1 ||
        perPage < 1 ||
        perPage > 50) {
      throw ArgumentError('Invalid City Handoffs filter or pagination.');
    }
    final query = Uri(
      queryParameters: {
        'view': view,
        'status': status,
        'page': '$page',
        'per_page': '$perPage',
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      },
    ).query;
    return LogisticsCityHandoffsPage.fromResponse(
      await _authService.getWithSession(
        '/api/mobile/logistics/city-handoffs?$query',
      ),
    );
  }

  Future<LogisticsPickupRequestPage> pickupRequests({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    return LogisticsPickupRequestPage.fromResponse(
      await _authService.getWithSession(
        '/api/mobile/logistics/pickup-requests?$query',
      ),
    );
  }

  Future<LogisticsPickupRequest> pickupRequest(int pickupRequestId) async {
    final response = await _authService.getWithSession(
      '/api/mobile/logistics/pickup-requests/$pickupRequestId',
    );
    if (response is! Map || response['data'] is! Map) {
      throw const FormatException('Missing pickup request details.');
    }
    final data = response['data'] as Map;
    return LogisticsPickupRequest.fromJson(data['pickup_request']);
  }

  Future<LogisticsIncomingParcelsResult> incomingParcels({
    String? status,
    String? search,
    String? destination,
    int page = 1,
    int perPage = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (destination != null && destination.trim().isNotEmpty)
          'destination': destination.trim(),
      },
    ).query;
    return LogisticsIncomingParcelsResult.fromResponse(
      await _authService.getWithSession(
        '/api/mobile/logistics/incoming-parcels?$query',
      ),
    );
  }

  Future<LogisticsIncomingParcelRecord> incomingParcel(
    String identifier,
  ) async {
    final response = await _authService.getWithSession(
      '/api/mobile/logistics/incoming-parcels/${Uri.encodeComponent(identifier.trim())}',
    );
    if (response is! Map || response['data'] is! Map) {
      throw const FormatException('Missing incoming parcel details.');
    }
    final data = response['data'] as Map;
    final parcel = LogisticsIncomingParcelRecord.fromJson(data['parcel']);
    final pieces = data['pieces'];
    final center = data['receiving_sorting_center'];
    final rawSizeClasses = data['size_classes'];
    if (pieces is! List) {
      throw const FormatException('Missing parcel pieces.');
    }
    return parcel.withPieces(
      pieces.map(LogisticsIncomingParcelPiece.fromJson).toList(growable: false),
      receivingCenter: center == null
          ? null
          : LogisticsSortingCenter.fromJson(center),
      availableSizeClasses: rawSizeClasses is List
          ? rawSizeClasses
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  Future<LogisticsPickupRequest> verifyPickupRequest(int pickupRequestId) =>
      _pickupAction(pickupRequestId, 'verify', const {});

  Future<LogisticsPickupRequest> rejectPickupRequest(
    int pickupRequestId, {
    required String reason,
  }) => _pickupAction(pickupRequestId, 'reject', {
    'cancellation_reason': reason.trim(),
  });

  Future<LogisticsPickupRequest> assignPickupRequest(
    int pickupRequestId, {
    required int riderProfileId,
    String? notes,
  }) => _pickupAction(pickupRequestId, 'assign', {
    'rider_profile_id': riderProfileId,
    if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
  });

  Future<LogisticsPickupRequest> replacePickupRequestRider(
    int pickupRequestId, {
    required int riderProfileId,
    required String reason,
  }) => _pickupAction(pickupRequestId, 'replace-rider', {
    'rider_profile_id': riderProfileId,
    'reason': reason.trim(),
  });

  Future<LogisticsPickupRequest> _pickupAction(
    int pickupRequestId,
    String action,
    Map<String, Object?> body,
  ) => _authService.requestWithSession<LogisticsPickupRequest>(
    method: AuthenticatedRequestMethod.post,
    path: '/api/mobile/logistics/pickup-requests/$pickupRequestId/$action',
    body: body,
    parse: (response) {
      if (response is! Map || response['data'] is! Map) {
        throw const FormatException('Missing pickup action response data.');
      }
      final data = response['data'] as Map;
      return LogisticsPickupRequest.fromJson(data['pickup_request']);
    },
  );

  Future<LogisticsWaybillLookup> lookupWaybill(
    String identifier,
  ) async => LogisticsWaybillLookup.fromResponse(
    await _authService.getWithSession(
      '/api/mobile/logistics/waybills/${Uri.encodeComponent(identifier.trim())}',
    ),
  );

  Future<LogisticsIncomingParcelReceipt> receiveParcel({
    required String waybill,
    required String parcel,
    required String sizeClass,
    required String scanMethod,
  }) => _authService.requestWithSession<LogisticsIncomingParcelReceipt>(
    method: AuthenticatedRequestMethod.post,
    path:
        '/api/mobile/logistics/incoming-parcels/${Uri.encodeComponent(waybill.trim())}/pieces/${Uri.encodeComponent(parcel.trim())}/receive',
    body: {'scan_method': scanMethod, 'size_class': sizeClass},
    parse: (response) {
      final receipt = LogisticsIncomingParcelReceipt.fromResponse(response);
      if (receipt.waybill.waybill != waybill.trim() ||
          receipt.piece.parcel != parcel.trim() ||
          receipt.piece.status != 'received' ||
          receipt.piece.sizeClass != sizeClass ||
          receipt.evidence?.event != 'received_at_center') {
        throw const FormatException('Missing receipt response data.');
      }
      return receipt;
    },
  );

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

  Future<LogisticsSortingWorkspace> sortingCenterWorkspace({
    String status = 'awaiting_sorting',
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    const statuses = {'awaiting_sorting', 'sorted', 'exceptions', 'all'};
    if (!statuses.contains(status) || page < 1 || perPage < 1 || perPage > 50) {
      throw ArgumentError('Invalid sorting center filter or pagination.');
    }
    final query = Uri(
      queryParameters: {
        'status': status,
        'page': '$page',
        'per_page': '$perPage',
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      },
    ).query;
    return LogisticsSortingWorkspace.fromResponse(
      await _authService.getWithSession(
        '/api/mobile/logistics/sorting-center/workspace?$query',
      ),
    );
  }

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
    String? assignmentReason,
  }) async => _authService.requestWithSession<LogisticsDispatchResult>(
    method: AuthenticatedRequestMethod.post,
    path: '/api/mobile/logistics/dispatch/zones/$zoneId/dispatch',
    body: {
      'rider_profile_id': riderProfileId,
      if (assignmentReason?.trim().isNotEmpty == true)
        'assignment_reason': assignmentReason!.trim(),
    },
    parse: LogisticsDispatchResult.fromResponse,
  );

  Future<LogisticsDeliveryMonitoring> deliveryMonitoring() async =>
      LogisticsDeliveryMonitoring.fromResponse(
        await _authService.getWithSession(
          '/api/mobile/logistics/delivery-monitoring',
        ),
      );

  Future<LogisticsDeliveryDetail> deliveryMonitoringDetail(
    String batchReference,
  ) async => LogisticsDeliveryDetail.fromResponse(
    await _authService.getWithSession(
      '/api/mobile/logistics/delivery-monitoring/${Uri.encodeComponent(batchReference.trim())}',
    ),
  );

  Future<List<LogisticsRider>> riders() async =>
      LogisticsRidersResponse.fromResponse(
        await _authService.getWithSession('/api/mobile/logistics/riders'),
      ).riders;

  Future<LogisticsRider> rider(int userId) async => LogisticsRider.fromResponse(
    await _authService.getWithSession('/api/mobile/logistics/riders/$userId'),
  );

  Future<LogisticsRider> updateRiderCapacity({
    required int userId,
    required int parcelCapacity,
  }) async => _authService.requestWithSession<LogisticsRider>(
    method: AuthenticatedRequestMethod.patch,
    path: '/api/mobile/logistics/riders/$userId/capacity',
    body: {'parcel_capacity': parcelCapacity},
    parse: LogisticsRider.fromResponse,
  );

  Future<LogisticsRider> updateRiderSpecialization({
    required int userId,
    required String specialization,
    required String reason,
  }) async => _authService.requestWithSession<LogisticsRider>(
    method: AuthenticatedRequestMethod.patch,
    path: '/api/mobile/logistics/riders/$userId/specialization',
    body: {'specialization': specialization, 'reason': reason},
    parse: LogisticsRider.fromResponse,
  );

  Future<LogisticsRider> refreshRiderAssignment({required int userId}) async =>
      _authService.requestWithSession<LogisticsRider>(
        method: AuthenticatedRequestMethod.patch,
        path: '/api/mobile/logistics/riders/$userId/assignment',
        parse: LogisticsRider.fromResponse,
      );

  Future<List<LogisticsRiderApplication>> riderApplications() async =>
      LogisticsRiderApplication.listFromResponse(
        await _authService.getWithSession(
          '/api/mobile/logistics/rider-applications',
        ),
      );

  Future<LogisticsRiderApplication> riderApplication(int applicationId) async =>
      LogisticsRiderApplication.fromResponse(
        await _authService.getWithSession(
          '/api/mobile/logistics/rider-applications/$applicationId',
        ),
      );

  Future<LogisticsRiderApplicationDocumentContent>
  downloadRiderApplicationDocument({
    required int applicationId,
    required int documentId,
  }) async {
    final response = await _authService.downloadWithSession(
      path:
          '/api/mobile/logistics/rider-applications/$applicationId/documents/$documentId',
    );
    if (response.bytes.isEmpty) {
      throw const FormatException('The Rider application document is empty.');
    }
    return LogisticsRiderApplicationDocumentContent(
      bytes: response.bytes,
      mimeType:
          response.contentType?.split(';').first.trim() ??
          'application/octet-stream',
    );
  }

  Future<LogisticsRiderApplication> reviewRiderApplicationDocument({
    required int applicationId,
    required int documentId,
    required String verificationStatus,
    String? rejectionReason,
  }) async => _authService.requestWithSession<LogisticsRiderApplication>(
    method: AuthenticatedRequestMethod.patch,
    path:
        '/api/mobile/logistics/rider-applications/$applicationId/documents/$documentId',
    body: {
      'verification_status': verificationStatus,
      'rejection_reason': ?rejectionReason,
    },
    parse: LogisticsRiderApplication.fromResponse,
  );

  Future<LogisticsRiderApplication> approveRiderApplication({
    required int applicationId,
    int? linehaulCapacity,
  }) async => _authService.requestWithSession<LogisticsRiderApplication>(
    method: AuthenticatedRequestMethod.post,
    path: '/api/mobile/logistics/rider-applications/$applicationId/approve',
    body: linehaulCapacity == null
        ? null
        : {'linehaul_capacity': linehaulCapacity},
    parse: LogisticsRiderApplication.fromResponse,
  );

  Future<LogisticsRiderApplication> rejectRiderApplication({
    required int applicationId,
    required String reason,
  }) async => _authService.requestWithSession<LogisticsRiderApplication>(
    method: AuthenticatedRequestMethod.post,
    path: '/api/mobile/logistics/rider-applications/$applicationId/reject',
    body: {'reason': reason},
    parse: LogisticsRiderApplication.fromResponse,
  );
}
