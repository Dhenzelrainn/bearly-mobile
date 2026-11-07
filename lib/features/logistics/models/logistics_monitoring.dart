import '../../../core/models/product_preview.dart';

class LogisticsDeliveryMonitoring {
  const LogisticsDeliveryMonitoring({
    required this.providerName,
    required this.deliveries,
  });

  final String providerName;
  final List<LogisticsDeliverySummary> deliveries;

  factory LogisticsDeliveryMonitoring.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'data');
    final provider = _map(data['provider'], 'provider');
    final deliveries = _list(data['deliveries'], 'deliveries');
    return LogisticsDeliveryMonitoring(
      providerName: _string(provider['name']),
      deliveries: deliveries
          .map(LogisticsDeliverySummary.fromJson)
          .toList(growable: false),
    );
  }
}

class LogisticsDeliverySummary {
  const LogisticsDeliverySummary({
    required this.reference,
    required this.rider,
    required this.zoneCode,
    required this.zoneName,
    required this.parcelCount,
    required this.progress,
    required this.status,
    required this.statusLabel,
    required this.lastUpdate,
  });

  final String reference;
  final String rider;
  final String zoneCode;
  final String zoneName;
  final int parcelCount;
  final int progress;
  final String status;
  final String statusLabel;
  final String lastUpdate;

  factory LogisticsDeliverySummary.fromJson(Object? value) {
    final map = _map(value, 'delivery');
    final zone = _map(map['zone'], 'delivery zone');
    return LogisticsDeliverySummary(
      reference: _string(map['reference']),
      rider: _string(map['rider']),
      zoneCode: _string(zone['code']),
      zoneName: _string(zone['name']),
      parcelCount: _integer(map['parcel_count']),
      progress: _integer(map['progress']).clamp(0, 100).toInt(),
      status: _string(map['status']),
      statusLabel: _string(map['status_label']),
      lastUpdate: _string(map['last_update']),
    );
  }
}

class LogisticsDeliveryDetail {
  const LogisticsDeliveryDetail({
    required this.providerName,
    required this.sortingCenterName,
    required this.sortingCenterCode,
    required this.delivery,
    required this.parcels,
    required this.timeline,
  });

  final String providerName;
  final String sortingCenterName;
  final String sortingCenterCode;
  final LogisticsDeliverySummary delivery;
  final List<LogisticsMonitoredParcel> parcels;
  final List<LogisticsMonitoringEvent> timeline;

  factory LogisticsDeliveryDetail.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'data');
    final provider = _map(data['provider'], 'provider');
    final center = _map(data['sorting_center'], 'sorting center');
    final deliveryMap = _map(data['delivery'], 'delivery detail');
    final delivery = LogisticsDeliverySummary.fromJson({
      'reference': deliveryMap['reference'],
      'rider': deliveryMap['rider'],
      'zone': deliveryMap['zone'],
      'parcel_count': deliveryMap['parcel_count'],
      'progress': deliveryMap['progress'],
      'status': deliveryMap['status'],
      'status_label': deliveryMap['status_label'],
      'last_update': deliveryMap['last_update'],
    });

    return LogisticsDeliveryDetail(
      providerName: _string(provider['name']),
      sortingCenterName: _string(center['name']),
      sortingCenterCode: _string(center['code']),
      delivery: delivery,
      parcels: _list(data['parcels'], 'parcels')
          .map(LogisticsMonitoredParcel.fromJson)
          .toList(growable: false),
      timeline: _list(data['timeline'], 'timeline')
          .map(LogisticsMonitoringEvent.fromJson)
          .toList(growable: false),
    );
  }
}

class LogisticsMonitoredParcel {
  const LogisticsMonitoredParcel({
    required this.reference,
    required this.waybill,
    required this.status,
    required this.lastEventAt,
    required this.shipmentReference,
    required this.shipmentStatus,
    this.products = const [],
  });

  final String reference;
  final String waybill;
  final String status;
  final String lastEventAt;
  final String shipmentReference;
  final String shipmentStatus;
  final List<ProductPreview> products;

  factory LogisticsMonitoredParcel.fromJson(Object? value) {
    final map = _map(value, 'parcel');
    final shipment = _map(map['shipment'], 'parcel shipment');
    return LogisticsMonitoredParcel(
      reference: _string(map['reference']),
      waybill: _string(map['waybill']),
      status: _string(map['status']),
      lastEventAt: _string(map['last_event_at']),
      shipmentReference: _string(shipment['reference']),
      shipmentStatus: _string(shipment['status']),
      products: ProductPreview.listFromJson(map['products']),
    );
  }
}

class LogisticsMonitoringEvent {
  const LogisticsMonitoringEvent({
    required this.time,
    required this.label,
    required this.detail,
    required this.occurredAt,
  });

  final String time;
  final String label;
  final String detail;
  final String occurredAt;

  factory LogisticsMonitoringEvent.fromJson(Object? value) {
    final map = _map(value, 'timeline event');
    return LogisticsMonitoringEvent(
      time: _string(map['time']),
      label: _string(map['label']),
      detail: _string(map['detail']),
      occurredAt: _string(map['occurred_at']),
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
  final parsed = value is int ? value : int.tryParse('$value');
  return parsed == null || parsed < 0 ? 0 : parsed;
}
