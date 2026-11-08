class LogisticsPickupRequestPage {
  const LogisticsPickupRequestPage({
    required this.requests,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<LogisticsPickupRequest> requests;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory LogisticsPickupRequestPage.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'data');
    final meta = _map(root['meta'], 'meta');
    return LogisticsPickupRequestPage(
      requests: _list(
        data['pickup_requests'],
        'pickup_requests',
      ).map(LogisticsPickupRequest.fromJson).toList(growable: false),
      currentPage: _integer(meta['current_page']),
      lastPage: _integer(meta['last_page']),
      total: _integer(meta['total']),
    );
  }
}

class LogisticsPickupRequest {
  const LogisticsPickupRequest({
    required this.id,
    required this.reference,
    required this.status,
    required this.statusLabel,
    required this.pickupType,
    required this.storeName,
    required this.sellerOrderReferences,
    required this.parcelCount,
    required this.totalWeightKg,
    required this.pickupLocation,
    required this.requestedDate,
    required this.windowStart,
    required this.windowEnd,
    required this.createdAt,
    required this.verifiedAt,
    required this.cancelledAt,
    required this.completedAt,
    required this.assignedRider,
    required this.sellerInstructions,
    required this.rejectionReason,
    required this.parcels,
    required this.eligibleRiderCandidates,
    required this.history,
  });

  final int id;
  final String reference;
  final String status;
  final String statusLabel;
  final String pickupType;
  final String storeName;
  final List<String> sellerOrderReferences;
  final int parcelCount;
  final double totalWeightKg;
  final String pickupLocation;
  final DateTime? requestedDate;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final DateTime? createdAt;
  final DateTime? verifiedAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;
  final LogisticsPickupAssignedRider? assignedRider;
  final String? sellerInstructions;
  final String? rejectionReason;
  final List<LogisticsPickupParcel> parcels;
  final List<LogisticsPickupCandidate> eligibleRiderCandidates;
  final List<LogisticsPickupActivity> history;

  bool get isReturnPickup => pickupType == 'return';

  factory LogisticsPickupRequest.fromJson(Object? value) {
    final map = _map(value, 'pickup_request');
    final store = _optionalMap(map['store']);
    final assignedRider = _optionalMap(map['assigned_rider']);
    return LogisticsPickupRequest(
      id: _integer(map['id']),
      reference: _string(map['reference']),
      status: _string(map['status']),
      statusLabel: _string(map['status_label']),
      pickupType: _string(map['pickup_type'], fallback: 'outbound'),
      storeName: _string(store?['name'], fallback: 'Store unavailable'),
      sellerOrderReferences: _stringList(map['seller_order_references']),
      parcelCount: _integer(map['parcel_count']),
      totalWeightKg: _number(map['total_weight_kg']),
      pickupLocation: _string(map['pickup_location'], fallback: 'Not provided'),
      requestedDate: _date(map['requested_date']),
      windowStart: _date(map['window_start']),
      windowEnd: _date(map['window_end']),
      createdAt: _date(map['created_at']),
      verifiedAt: _date(map['verified_at']),
      cancelledAt: _date(map['cancelled_at']),
      completedAt: _date(map['completed_at']),
      assignedRider: assignedRider == null
          ? null
          : LogisticsPickupAssignedRider.fromJson(assignedRider),
      sellerInstructions: _nullableString(map['seller_instructions']),
      rejectionReason: _nullableString(map['rejection_reason']),
      parcels: _optionalList(
        map['parcels'],
      ).map(LogisticsPickupParcel.fromJson).toList(growable: false),
      eligibleRiderCandidates: _optionalList(
        map['eligible_rider_candidates'],
      ).map(LogisticsPickupCandidate.fromJson).toList(growable: false),
      history: _optionalList(
        map['history'],
      ).map(LogisticsPickupActivity.fromJson).toList(growable: false),
    );
  }
}

class LogisticsPickupAssignedRider {
  const LogisticsPickupAssignedRider({
    required this.profileId,
    required this.name,
    required this.assignmentStatus,
    required this.assignedAt,
  });

  final int profileId;
  final String name;
  final String assignmentStatus;
  final DateTime? assignedAt;

  factory LogisticsPickupAssignedRider.fromJson(Map<String, dynamic> map) =>
      LogisticsPickupAssignedRider(
        profileId: _integer(map['profile_id']),
        name: _string(map['name'], fallback: 'Rider'),
        assignmentStatus: _string(map['assignment_status']),
        assignedAt: _date(map['assigned_at']),
      );
}

class LogisticsPickupParcel {
  const LogisticsPickupParcel({
    required this.reference,
    required this.pieceNumber,
    required this.status,
    required this.weightKg,
    required this.waybill,
    required this.shipmentReference,
    required this.sellerOrderReferences,
  });

  final String reference;
  final int pieceNumber;
  final String status;
  final double? weightKg;
  final String? waybill;
  final String? shipmentReference;
  final List<String> sellerOrderReferences;

  factory LogisticsPickupParcel.fromJson(Object? value) {
    final map = _map(value, 'parcel');
    final shipment = _optionalMap(map['shipment']);
    return LogisticsPickupParcel(
      reference: _string(map['reference']),
      pieceNumber: _integer(map['piece_number']),
      status: _string(map['status']),
      weightKg: _optionalNumber(map['weight_kg']),
      waybill: _nullableString(map['waybill']),
      shipmentReference: _nullableString(shipment?['reference']),
      sellerOrderReferences: _stringList(shipment?['seller_order_references']),
    );
  }
}

class LogisticsPickupCandidate {
  const LogisticsPickupCandidate({
    required this.profileId,
    required this.name,
    required this.vehicle,
    required this.serviceArea,
    required this.activeJobs,
    required this.recommended,
    required this.recommendationReason,
    required this.distanceLabel,
  });

  final int profileId;
  final String name;
  final String? vehicle;
  final String? serviceArea;
  final int activeJobs;
  final bool recommended;
  final String? recommendationReason;
  final String? distanceLabel;

  factory LogisticsPickupCandidate.fromJson(Object? value) {
    final map = _map(value, 'eligible_rider_candidate');
    return LogisticsPickupCandidate(
      profileId: _integer(map['profile_id']),
      name: _string(map['name'], fallback: 'Rider'),
      vehicle: _nullableString(map['vehicle']),
      serviceArea: _nullableString(map['service_area']),
      activeJobs: _integer(map['active_jobs']),
      recommended: map['recommended'] == true,
      recommendationReason: _nullableString(map['recommendation_reason']),
      distanceLabel: _nullableString(map['distance_label']),
    );
  }
}

class LogisticsPickupActivity {
  const LogisticsPickupActivity({
    required this.event,
    required this.label,
    required this.occurredAt,
    required this.detail,
  });

  final String event;
  final String label;
  final DateTime? occurredAt;
  final String? detail;

  factory LogisticsPickupActivity.fromJson(Object? value) {
    final map = _map(value, 'pickup_history');
    return LogisticsPickupActivity(
      event: _string(map['event']),
      label: _string(map['label']),
      occurredAt: _date(map['occurred_at']),
      detail: _nullableString(map['detail']),
    );
  }
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Missing or invalid $field data.');
}

Map<String, dynamic>? _optionalMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<dynamic> _list(Object? value, String field) {
  if (value is List) return value;
  throw FormatException('Missing or invalid $field list.');
}

List<dynamic> _optionalList(Object? value) => value is List ? value : const [];

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _number(Object? value) => _optionalNumber(value) ?? 0;

double? _optionalNumber(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
