class RiderCourierRunPage {
  const RiderCourierRunPage({
    required this.runs,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<RiderCourierRun> runs;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory RiderCourierRunPage.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    return RiderCourierRunPage(
      runs: _list(
        json['data'],
      ).map(RiderCourierRun.fromJson).toList(growable: false),
      currentPage: _int(meta['current_page'], fallback: 1),
      lastPage: _int(meta['last_page'], fallback: 1),
      total: _int(meta['total']),
    );
  }
}

class RiderCourierRun {
  const RiderCourierRun({
    required this.id,
    required this.runNo,
    required this.status,
    required this.statusBeforeException,
    required this.originProvider,
    required this.originCenter,
    required this.destinationProvider,
    required this.shipments,
    required this.events,
    required this.availableActions,
    this.assignedAt,
    this.loadedAt,
    this.departedAt,
    this.arrivedAt,
    this.completedAt,
  });

  final int id;
  final String runNo;
  final String status;
  final String? statusBeforeException;
  final String originProvider;
  final String originCenter;
  final String destinationProvider;
  final List<RiderCourierShipment> shipments;
  final List<RiderCourierRunEvent> events;
  final List<RiderCourierRunAction> availableActions;
  final DateTime? assignedAt;
  final DateTime? loadedAt;
  final DateTime? departedAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  int get manifestCount => shipments.length;
  int get parcelCount =>
      shipments.fold(0, (sum, item) => sum + item.parcels.length);

  factory RiderCourierRun.fromJson(Map<String, dynamic> json) {
    final origin = _map(json['origin']);
    final destination = _map(json['destination']);
    final manifest = _map(json['manifest']);
    return RiderCourierRun(
      id: _int(json['id']),
      runNo: _string(json['run_no']),
      status: _string(json['status'], fallback: 'unknown'),
      statusBeforeException: _nullableString(json['status_before_exception']),
      originProvider: _string(origin['provider']),
      originCenter: _string(origin['sorting_center']),
      destinationProvider: _string(destination['provider']),
      shipments: _list(
        manifest['shipments'],
      ).map(RiderCourierShipment.fromJson).toList(growable: false),
      events: _list(
        json['events'],
      ).map(RiderCourierRunEvent.fromJson).toList(growable: false),
      availableActions: _list(
        json['available_actions'],
      ).map(RiderCourierRunAction.fromJson).toList(growable: false),
      assignedAt: _date(json['assigned_at']),
      loadedAt: _date(json['loaded_at']),
      departedAt: _date(json['departed_at']),
      arrivedAt: _date(json['arrived_at']),
      completedAt: _date(json['completed_at']),
    );
  }
}

class RiderCourierShipment {
  const RiderCourierShipment({
    required this.shipmentNo,
    required this.waybillNo,
    required this.status,
    required this.parcels,
  });

  final String shipmentNo;
  final String waybillNo;
  final String status;
  final List<RiderCourierParcel> parcels;

  factory RiderCourierShipment.fromJson(Map<String, dynamic> json) =>
      RiderCourierShipment(
        shipmentNo: _string(json['shipment_no']),
        waybillNo: _string(json['waybill_no']),
        status: _string(json['status'], fallback: 'unknown'),
        parcels: _list(
          json['parcels'],
        ).map(RiderCourierParcel.fromJson).toList(growable: false),
      );
}

class RiderCourierParcel {
  const RiderCourierParcel({
    required this.parcelNo,
    required this.status,
    required this.currentSortingCenter,
  });

  final String parcelNo;
  final String status;
  final String currentSortingCenter;

  factory RiderCourierParcel.fromJson(Map<String, dynamic> json) =>
      RiderCourierParcel(
        parcelNo: _string(json['parcel_no']),
        status: _string(json['status'], fallback: 'unknown'),
        currentSortingCenter: _string(json['current_sorting_center']),
      );
}

class RiderCourierRunEvent {
  const RiderCourierRunEvent({
    required this.type,
    required this.fromStatus,
    required this.toStatus,
    required this.reason,
    this.occurredAt,
  });

  final String type;
  final String? fromStatus;
  final String? toStatus;
  final String? reason;
  final DateTime? occurredAt;

  factory RiderCourierRunEvent.fromJson(Map<String, dynamic> json) =>
      RiderCourierRunEvent(
        type: _string(json['type'], fallback: 'Run update'),
        fromStatus: _nullableString(json['from_status']),
        toStatus: _nullableString(json['to_status']),
        reason: _nullableString(json['reason']),
        occurredAt: _date(json['occurred_at']),
      );
}

class RiderCourierRunAction {
  const RiderCourierRunAction({required this.key, required this.label});

  final String key;
  final String label;

  factory RiderCourierRunAction.fromJson(Map<String, dynamic> json) =>
      RiderCourierRunAction(
        key: _string(json['key']),
        label: _string(json['label'], fallback: 'Continue'),
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const <Map<String, dynamic>>[];

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) => value is String ? value : null;

int _int(Object? value, {int fallback = 0}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
