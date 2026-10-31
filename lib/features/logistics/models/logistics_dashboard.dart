class LogisticsDashboard {
  const LogisticsDashboard({
    required this.providerName,
    required this.providerStatus,
    required this.sortingCenter,
    required this.setupRequired,
    required this.metrics,
    required this.incomingHandoffs,
    required this.incomingParcels,
  });

  final String providerName;
  final String providerStatus;
  final LogisticsSortingCenter? sortingCenter;
  final bool setupRequired;
  final LogisticsMetrics metrics;
  final List<LogisticsIncomingHandoff> incomingHandoffs;
  final List<LogisticsIncomingParcel> incomingParcels;

  factory LogisticsDashboard.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'data');
    final provider = _map(data['provider'], 'provider');
    final centerValue = data['sorting_center'];
    final incoming = _map(data['incoming'], 'incoming');

    return LogisticsDashboard(
      providerName: _string(provider['name']),
      providerStatus: _string(provider['status']),
      sortingCenter: centerValue == null
          ? null
          : LogisticsSortingCenter.fromJson(centerValue),
      setupRequired: data['setup_required'] == true,
      metrics: LogisticsMetrics.fromJson(data['metrics']),
      incomingHandoffs: _list(
        incoming['handoffs'],
        'incoming.handoffs',
      ).map(LogisticsIncomingHandoff.fromJson).toList(growable: false),
      incomingParcels: _list(
        incoming['parcels'],
        'incoming.parcels',
      ).map(LogisticsIncomingParcel.fromJson).toList(growable: false),
    );
  }
}

class LogisticsSortingCenter {
  const LogisticsSortingCenter({
    required this.name,
    required this.code,
    required this.status,
    required this.address,
  });

  final String name;
  final String code;
  final String status;
  final String address;

  factory LogisticsSortingCenter.fromJson(Object? value) {
    final map = _map(value, 'sorting_center');
    return LogisticsSortingCenter(
      name: _string(map['name']),
      code: _string(map['code']),
      status: _string(map['status']),
      address: _string(map['address']),
    );
  }
}

class LogisticsMetrics {
  const LogisticsMetrics({
    required this.receivedToday,
    required this.awaitingSorting,
    required this.sortedReady,
    required this.dispatchedShipments,
    required this.activeRoutes,
    required this.sortingExceptions,
    required this.pendingPickupRequests,
    required this.incomingHandoffs,
  });

  final int receivedToday;
  final int awaitingSorting;
  final int sortedReady;
  final int dispatchedShipments;
  final int activeRoutes;
  final int sortingExceptions;
  final int pendingPickupRequests;
  final int incomingHandoffs;

  factory LogisticsMetrics.fromJson(Object? value) {
    final map = _map(value, 'metrics');
    return LogisticsMetrics(
      receivedToday: _integer(map['received_today']),
      awaitingSorting: _integer(map['awaiting_sorting']),
      sortedReady: _integer(map['sorted_ready']),
      dispatchedShipments: _integer(map['dispatched_shipments']),
      activeRoutes: _integer(map['active_routes']),
      sortingExceptions: _integer(map['sorting_exceptions']),
      pendingPickupRequests: _integer(map['pending_pickup_requests']),
      incomingHandoffs: _integer(map['incoming_handoffs']),
    );
  }
}

class LogisticsIncomingHandoff {
  const LogisticsIncomingHandoff({
    required this.waybill,
    required this.fromProvider,
    required this.purpose,
    required this.parcelCount,
  });

  final String waybill;
  final String fromProvider;
  final String purpose;
  final int parcelCount;

  factory LogisticsIncomingHandoff.fromJson(Object? value) {
    final map = _map(value, 'incoming.handoff');
    return LogisticsIncomingHandoff(
      waybill: _string(map['waybill']),
      fromProvider: _string(map['from_provider']),
      purpose: _string(map['purpose']),
      parcelCount: _integer(map['parcel_count']),
    );
  }
}

class LogisticsIncomingParcel {
  const LogisticsIncomingParcel({
    required this.waybill,
    required this.purpose,
    required this.status,
    required this.parcelCount,
  });

  final String waybill;
  final String purpose;
  final String status;
  final int parcelCount;

  factory LogisticsIncomingParcel.fromJson(Object? value) {
    final map = _map(value, 'incoming.parcel');
    return LogisticsIncomingParcel(
      waybill: _string(map['waybill']),
      purpose: _string(map['purpose']),
      status: _string(map['status']),
      parcelCount: _integer(map['parcel_count']),
    );
  }
}

Map _map(Object? value, String path) {
  if (value is Map) return value;
  throw FormatException('Bearly returned an invalid Logistics $path value.');
}

List _list(Object? value, String path) {
  if (value is List) return value;
  throw FormatException('Bearly returned an invalid Logistics $path list.');
}

String _string(Object? value) => value is String ? value.trim() : '';

int _integer(Object? value) {
  if (value is int && value >= 0) return value;
  final parsed = int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : 0;
}
