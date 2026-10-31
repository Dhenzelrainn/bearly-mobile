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
    required this.parcelStatuses,
    required this.intakeRecorded,
    required this.parcelCount,
  });

  final String waybill;
  final String purpose;
  final List<String> parcelStatuses;
  final bool intakeRecorded;
  final int parcelCount;

  factory LogisticsIncomingParcel.fromJson(Object? value) {
    final map = _map(value, 'incoming.parcel');
    return LogisticsIncomingParcel(
      waybill: _string(map['waybill']),
      purpose: _string(map['purpose']),
      parcelStatuses: _stringList(map['parcel_statuses']),
      intakeRecorded: map['intake_recorded'] == true,
      parcelCount: _integer(map['parcel_count']),
    );
  }
}

class LogisticsWaybillLookup {
  const LogisticsWaybillLookup({
    required this.waybill,
    required this.shipmentReference,
    required this.shipmentStatus,
    required this.purpose,
    required this.destination,
    required this.logisticsProvider,
    required this.receivingProvider,
    required this.currentSortingCenter,
    required this.receivingSortingCenter,
    required this.receiptEligibility,
    required this.handoff,
    required this.parcels,
    required this.terminal,
    required this.guidance,
  });

  final String waybill;
  final String shipmentReference;
  final String shipmentStatus;
  final String purpose;
  final LogisticsDestination destination;
  final String logisticsProvider;
  final String receivingProvider;
  final LogisticsSortingCenter? currentSortingCenter;
  final LogisticsSortingCenter? receivingSortingCenter;
  final LogisticsReceiptEligibility receiptEligibility;
  final LogisticsWaybillHandoff? handoff;
  final List<LogisticsLookupParcel> parcels;
  final bool terminal;
  final String guidance;

  factory LogisticsWaybillLookup.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'data');
    final shipment = _map(data['shipment'], 'shipment');
    final destination = _map(data['destination'], 'destination');
    final provider = _map(data['logistics_provider'], 'logistics_provider');
    final receivingProvider = data['receiving_logistics_provider'];
    final centerValue = data['current_sorting_center'];
    final receivingCenterValue = data['receiving_sorting_center'];
    final handoffValue = data['handoff'];
    final receiptEligibilityValue = data['receipt_eligibility'];
    final guidance = _map(data['next_step_guidance'], 'next_step_guidance');
    final parcelList = _list(data['parcels'], 'parcels');

    return LogisticsWaybillLookup(
      waybill: _string(data['waybill']),
      shipmentReference: _string(shipment['reference']),
      shipmentStatus: _string(shipment['status']),
      purpose: _string(shipment['purpose']),
      destination: LogisticsDestination.fromJson(destination),
      logisticsProvider: _string(provider['name']),
      receivingProvider: receivingProvider is Map
          ? _string(receivingProvider['name'])
          : _string(provider['name']),
      currentSortingCenter: centerValue == null
          ? null
          : LogisticsSortingCenter.fromJson(centerValue),
      receivingSortingCenter: receivingCenterValue == null
          ? null
          : LogisticsSortingCenter.fromJson(receivingCenterValue),
      receiptEligibility: LogisticsReceiptEligibility.fromJson(
        receiptEligibilityValue,
      ),
      handoff: handoffValue == null
          ? null
          : LogisticsWaybillHandoff.fromJson(handoffValue),
      parcels: parcelList
          .map(LogisticsLookupParcel.fromJson)
          .toList(growable: false),
      terminal: data['terminal'] == true,
      guidance: _string(guidance['message']),
    );
  }
}

class LogisticsReceiptEligibility {
  const LogisticsReceiptEligibility({
    required this.eligible,
    required this.code,
    required this.message,
  });

  final bool eligible;
  final String code;
  final String message;

  factory LogisticsReceiptEligibility.fromJson(Object? value) {
    if (value is! Map) {
      return const LogisticsReceiptEligibility(
        eligible: false,
        code: 'unavailable',
        message: 'Receipt eligibility was not provided by the server.',
      );
    }

    return LogisticsReceiptEligibility(
      eligible: value['eligible'] == true,
      code: _string(value['code']),
      message: _string(value['message']),
    );
  }
}

class LogisticsDestination {
  const LogisticsDestination({
    required this.barangay,
    required this.city,
    required this.province,
  });

  final String barangay;
  final String city;
  final String province;

  factory LogisticsDestination.fromJson(Object? value) {
    final map = _map(value, 'destination');
    return LogisticsDestination(
      barangay: _string(map['barangay']),
      city: _string(map['city']),
      province: _string(map['province']),
    );
  }
}

class LogisticsWaybillHandoff {
  const LogisticsWaybillHandoff({
    required this.status,
    required this.fromProvider,
    required this.toProvider,
  });

  final String status;
  final String fromProvider;
  final String toProvider;

  factory LogisticsWaybillHandoff.fromJson(Object? value) {
    final map = _map(value, 'handoff');
    return LogisticsWaybillHandoff(
      status: _string(map['status']),
      fromProvider: _string(map['from_provider']),
      toProvider: _string(map['to_provider']),
    );
  }
}

class LogisticsLookupParcel {
  const LogisticsLookupParcel({
    required this.reference,
    required this.status,
    required this.terminal,
    required this.currentSortingCenter,
    required this.lastRecordedCenter,
    required this.centerIntakeRecordedAt,
  });

  final String reference;
  final String status;
  final bool terminal;
  final LogisticsSortingCenter? currentSortingCenter;
  final LogisticsSortingCenter? lastRecordedCenter;
  final String centerIntakeRecordedAt;

  factory LogisticsLookupParcel.fromJson(Object? value) {
    final map = _map(value, 'parcel');
    final currentCenter = map['current_sorting_center'];
    final lastCenter = map['last_recorded_center'];
    return LogisticsLookupParcel(
      reference: _string(map['reference']),
      status: _string(map['status']),
      terminal: map['terminal'] == true,
      currentSortingCenter: currentCenter == null
          ? null
          : LogisticsSortingCenter.fromJson(currentCenter),
      lastRecordedCenter: lastCenter == null
          ? null
          : LogisticsSortingCenter.fromJson(lastCenter),
      centerIntakeRecordedAt: _string(map['center_intake_recorded_at']),
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

List<String> _stringList(Object? value) => value is List
    ? value
          .whereType<String>()
          .map((item) => item.trim())
          .toList(growable: false)
    : const [];

int _integer(Object? value) {
  if (value is int && value >= 0) return value;
  final parsed = int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : 0;
}
