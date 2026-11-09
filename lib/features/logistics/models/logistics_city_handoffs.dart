class LogisticsCityHandoffsPage {
  const LogisticsCityHandoffsPage({
    required this.view,
    required this.providerName,
    required this.activeCenterName,
    required this.items,
    required this.runs,
    required this.availableCouriers,
    required this.status,
    required this.search,
    required this.pagination,
  });

  final String view;
  final String providerName;
  final String? activeCenterName;
  final List<LogisticsCityHandoff> items;
  final List<LogisticsCityRun> runs;
  final List<LogisticsAvailableCourier> availableCouriers;
  final String status;
  final String? search;
  final LogisticsCityHandoffsPagination pagination;

  factory LogisticsCityHandoffsPage.fromResponse(Object? value) {
    final root = _cityMap(value, 'response');
    final data = _cityMap(root['data'], 'data');
    final provider = _cityMap(data['provider'], 'provider');
    final centerValue = data['active_sorting_center'];
    final center = centerValue == null
        ? null
        : _cityMap(centerValue, 'active_sorting_center');
    final view = _cityString(data['view']);
    final items = _cityList(data['items'], 'items');
    final courierValues = _cityList(
      data['available_couriers'],
      'available_couriers',
    );
    final filters = _cityMap(data['filters'], 'filters');
    final pagination = _cityMap(data['pagination'], 'pagination');

    return LogisticsCityHandoffsPage(
      view: view,
      providerName: _cityString(provider['name']),
      activeCenterName: center == null ? null : _cityString(center['name']),
      items: view == 'runs'
          ? const []
          : items.map(LogisticsCityHandoff.fromJson).toList(growable: false),
      runs: view == 'runs'
          ? items.map(LogisticsCityRun.fromJson).toList(growable: false)
          : const [],
      availableCouriers: courierValues
          .map(LogisticsAvailableCourier.fromJson)
          .toList(growable: false),
      status: _cityString(filters['status']),
      search: _cityNullableString(filters['search']),
      pagination: LogisticsCityHandoffsPagination.fromJson(pagination),
    );
  }
}

class LogisticsCityHandoffsPagination {
  const LogisticsCityHandoffsPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < lastPage;

  factory LogisticsCityHandoffsPagination.fromJson(Map value) =>
      LogisticsCityHandoffsPagination(
        currentPage: _cityInt(value['current_page']),
        lastPage: _cityInt(value['last_page'], fallback: 1),
        perPage: _cityInt(value['per_page'], fallback: 20),
        total: _cityInt(value['total']),
      );
}

class LogisticsCityHandoff {
  const LogisticsCityHandoff({
    required this.id,
    required this.direction,
    required this.status,
    required this.stage,
    required this.waybill,
    required this.shipmentReference,
    required this.shipmentStatus,
    required this.purpose,
    required this.origin,
    required this.destination,
    required this.parcelCount,
    required this.parcels,
    required this.run,
    required this.acceptanceEligibility,
    required this.sentAt,
    required this.acceptedAt,
    required this.history,
  });

  final int id;
  final String direction;
  final String status;
  final String stage;
  final String waybill;
  final String shipmentReference;
  final String shipmentStatus;
  final String purpose;
  final LogisticsCityHandoffLocation origin;
  final LogisticsCityHandoffLocation destination;
  final int parcelCount;
  final List<LogisticsCityParcel> parcels;
  final LogisticsCityHandoffRun? run;
  final LogisticsCityAcceptanceEligibility? acceptanceEligibility;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final List<LogisticsCityHistoryEvent> history;

  factory LogisticsCityHandoff.fromJson(Object? value) {
    final map = _cityMap(value, 'handoff');
    final shipment = _cityMap(map['shipment'], 'shipment');
    final runValue = map['run'];
    final eligibilityValue = map['acceptance_eligibility'];
    return LogisticsCityHandoff(
      id: _cityInt(map['id']),
      direction: _cityString(map['direction']),
      status: _cityString(map['status']),
      stage: _cityString(map['stage']),
      waybill: _cityString(map['waybill']),
      shipmentReference: _cityString(shipment['reference']),
      shipmentStatus: _cityString(shipment['status']),
      purpose: _cityString(shipment['purpose']),
      origin: LogisticsCityHandoffLocation.fromJson(map['origin']),
      destination: LogisticsCityHandoffLocation.fromJson(map['destination']),
      parcelCount: _cityInt(map['parcel_count']),
      parcels: _cityList(
        map['parcels'],
        'parcels',
      ).map(LogisticsCityParcel.fromJson).toList(growable: false),
      run: runValue == null ? null : LogisticsCityHandoffRun.fromJson(runValue),
      acceptanceEligibility: eligibilityValue == null
          ? null
          : LogisticsCityAcceptanceEligibility.fromJson(eligibilityValue),
      sentAt: _cityDate(map['sent_at']),
      acceptedAt: _cityDate(map['accepted_at']),
      history: _cityList(
        map['history'],
        'history',
      ).map(LogisticsCityHistoryEvent.fromJson).toList(growable: false),
    );
  }
}

class LogisticsCityHandoffLocation {
  const LogisticsCityHandoffLocation({
    required this.providerName,
    required this.sortingCenterName,
    required this.sortingCenterCode,
  });

  final String providerName;
  final String? sortingCenterName;
  final String? sortingCenterCode;

  factory LogisticsCityHandoffLocation.fromJson(Object? value) {
    final map = _cityMap(value, 'location');
    final providerValue = map['provider'];
    final centerValue = map['sorting_center'];
    final provider = providerValue == null
        ? null
        : _cityMap(providerValue, 'provider');
    final center = centerValue == null
        ? null
        : _cityMap(centerValue, 'sorting_center');
    return LogisticsCityHandoffLocation(
      providerName: _cityString(provider?['name']),
      sortingCenterName: center == null ? null : _cityString(center['name']),
      sortingCenterCode: center == null ? null : _cityString(center['code']),
    );
  }
}

class LogisticsCityParcel {
  const LogisticsCityParcel({
    required this.reference,
    required this.status,
    required this.currentCenter,
  });

  final String reference;
  final String status;
  final String? currentCenter;

  factory LogisticsCityParcel.fromJson(Object? value) {
    final map = _cityMap(value, 'parcel');
    final centerValue = map['current_sorting_center'];
    final center = centerValue == null
        ? null
        : _cityMap(centerValue, 'current_sorting_center');
    return LogisticsCityParcel(
      reference: _cityString(map['reference']),
      status: _cityString(map['status']),
      currentCenter: center == null ? null : _cityString(center['name']),
    );
  }
}

class LogisticsCityHandoffRun {
  const LogisticsCityHandoffRun({
    required this.runNo,
    required this.status,
    required this.courierName,
    required this.assignedAt,
    required this.loadedAt,
    required this.departedAt,
    required this.arrivedAt,
  });

  final String runNo;
  final String status;
  final String courierName;
  final DateTime? assignedAt;
  final DateTime? loadedAt;
  final DateTime? departedAt;
  final DateTime? arrivedAt;

  factory LogisticsCityHandoffRun.fromJson(Object? value) {
    final map = _cityMap(value, 'run');
    final courierValue = map['courier'];
    final courier = courierValue == null
        ? null
        : _cityMap(courierValue, 'courier');
    return LogisticsCityHandoffRun(
      runNo: _cityString(map['run_no']),
      status: _cityString(map['status']),
      courierName: _cityString(courier?['name']),
      assignedAt: _cityDate(map['assigned_at']),
      loadedAt: _cityDate(map['loaded_at']),
      departedAt: _cityDate(map['departed_at']),
      arrivedAt: _cityDate(map['arrived_at']),
    );
  }
}

class LogisticsCityAcceptanceEligibility {
  const LogisticsCityAcceptanceEligibility({
    required this.eligible,
    required this.code,
    required this.message,
  });

  final bool eligible;
  final String code;
  final String message;

  factory LogisticsCityAcceptanceEligibility.fromJson(Object? value) {
    final map = _cityMap(value, 'acceptance eligibility');
    return LogisticsCityAcceptanceEligibility(
      eligible: map['eligible'] == true,
      code: _cityString(map['code']),
      message: _cityString(map['message']),
    );
  }
}

class LogisticsCityHistoryEvent {
  const LogisticsCityHistoryEvent({
    required this.event,
    required this.fromStatus,
    required this.toStatus,
    required this.occurredAt,
    required this.actor,
  });

  final String event;
  final String? fromStatus;
  final String? toStatus;
  final DateTime? occurredAt;
  final String? actor;

  factory LogisticsCityHistoryEvent.fromJson(Object? value) {
    final map = _cityMap(value, 'history event');
    return LogisticsCityHistoryEvent(
      event: _cityString(map['event']),
      fromStatus: _cityNullableString(map['from_status']),
      toStatus: _cityNullableString(map['to_status'] ?? map['status']),
      occurredAt: _cityDate(map['occurred_at']),
      actor: _cityNullableString(map['actor']),
    );
  }
}

class LogisticsCityRun {
  const LogisticsCityRun({
    required this.id,
    required this.runNo,
    required this.status,
    required this.statusLabel,
    required this.origin,
    required this.destination,
    required this.courier,
    required this.shipmentCount,
    required this.parcelCount,
    required this.shipments,
    required this.assignedAt,
    required this.loadedAt,
    required this.departedAt,
    required this.arrivedAt,
    required this.completedAt,
    required this.history,
  });

  final int id;
  final String runNo;
  final String status;
  final String statusLabel;
  final LogisticsCityHandoffLocation origin;
  final LogisticsCityHandoffLocation destination;
  final LogisticsCityRunCourier courier;
  final int shipmentCount;
  final int parcelCount;
  final List<LogisticsCityManifestShipment> shipments;
  final DateTime? assignedAt;
  final DateTime? loadedAt;
  final DateTime? departedAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final List<LogisticsCityHistoryEvent> history;

  factory LogisticsCityRun.fromJson(Object? value) {
    final map = _cityMap(value, 'run');
    final manifest = _cityMap(map['manifest'], 'manifest');
    return LogisticsCityRun(
      id: _cityInt(map['id']),
      runNo: _cityString(map['run_no']),
      status: _cityString(map['status']),
      statusLabel: _cityString(map['status_label']),
      origin: LogisticsCityHandoffLocation.fromJson(map['origin']),
      destination: LogisticsCityHandoffLocation.fromJson(map['destination']),
      courier: LogisticsCityRunCourier.fromJson(map['courier']),
      shipmentCount: _cityInt(manifest['shipment_count']),
      parcelCount: _cityInt(manifest['parcel_count']),
      shipments: _cityList(
        manifest['shipments'],
        'manifest shipments',
      ).map(LogisticsCityManifestShipment.fromJson).toList(growable: false),
      assignedAt: _cityDate(map['assigned_at']),
      loadedAt: _cityDate(map['loaded_at']),
      departedAt: _cityDate(map['departed_at']),
      arrivedAt: _cityDate(map['arrived_at']),
      completedAt: _cityDate(map['completed_at']),
      history: _cityList(
        map['history'],
        'history',
      ).map(LogisticsCityHistoryEvent.fromJson).toList(growable: false),
    );
  }
}

class LogisticsCityRunCourier {
  const LogisticsCityRunCourier({
    required this.name,
    required this.workType,
    required this.vehicleType,
    required this.parcelCapacity,
  });

  final String name;
  final String? workType;
  final String? vehicleType;
  final int? parcelCapacity;

  factory LogisticsCityRunCourier.fromJson(Object? value) {
    final map = _cityMap(value, 'Courier');
    return LogisticsCityRunCourier(
      name: _cityString(map['name']),
      workType: _cityNullableString(map['work_type']),
      vehicleType: _cityNullableString(map['vehicle_type']),
      parcelCapacity: map['parcel_capacity'] is num
          ? (map['parcel_capacity'] as num).toInt()
          : null,
    );
  }
}

class LogisticsCityManifestShipment {
  const LogisticsCityManifestShipment({
    required this.reference,
    required this.waybill,
    required this.status,
    required this.purpose,
    required this.handoffStatus,
    required this.parcels,
  });

  final String reference;
  final String waybill;
  final String status;
  final String purpose;
  final String? handoffStatus;
  final List<LogisticsCityParcel> parcels;

  factory LogisticsCityManifestShipment.fromJson(Object? value) {
    final map = _cityMap(value, 'manifest shipment');
    return LogisticsCityManifestShipment(
      reference: _cityString(map['reference']),
      waybill: _cityString(map['waybill']),
      status: _cityString(map['status']),
      purpose: _cityString(map['purpose']),
      handoffStatus: _cityNullableString(map['handoff_status']),
      parcels: _cityList(
        map['parcels'],
        'manifest parcels',
      ).map(LogisticsCityParcel.fromJson).toList(growable: false),
    );
  }
}

class LogisticsAvailableCourier {
  const LogisticsAvailableCourier({
    required this.name,
    required this.vehicleType,
    required this.parcelCapacity,
  });

  final String name;
  final String vehicleType;
  final int parcelCapacity;

  factory LogisticsAvailableCourier.fromJson(Object? value) {
    final map = _cityMap(value, 'available Courier');
    return LogisticsAvailableCourier(
      name: _cityString(map['name']),
      vehicleType: _cityString(map['vehicle_type']),
      parcelCapacity: _cityInt(map['parcel_capacity']),
    );
  }
}

Map _cityMap(Object? value, String path) {
  if (value is Map) return value;
  throw FormatException('Bearly returned an invalid City Handoffs $path.');
}

List _cityList(Object? value, String path) {
  if (value is List) return value;
  throw FormatException('Bearly returned an invalid City Handoffs $path list.');
}

String _cityString(Object? value) => value is String ? value.trim() : '';

String? _cityNullableString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

int _cityInt(Object? value, {int fallback = 0}) {
  if (value is int && value >= 0) return value;
  final parsed = int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : fallback;
}

DateTime? _cityDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
