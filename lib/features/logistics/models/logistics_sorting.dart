import 'logistics_dashboard.dart';

class LogisticsSortingQueue {
  const LogisticsSortingQueue({
    required this.sortingCenter,
    required this.parcels,
  });

  final LogisticsSortingCenter sortingCenter;
  final List<LogisticsSortingParcel> parcels;

  factory LogisticsSortingQueue.fromResponse(Object? value) {
    final root = _map(value, 'sorting queue response');
    final data = _map(root['data'], 'sorting queue data');
    final center = LogisticsSortingCenter.fromJson(data['sorting_center']);
    final parcelValues = _list(data['parcels'], 'sorting queue parcels');

    return LogisticsSortingQueue(
      sortingCenter: center,
      parcels: parcelValues
          .map(LogisticsSortingParcel.fromJson)
          .toList(growable: false),
    );
  }
}

class LogisticsSortingParcel {
  const LogisticsSortingParcel({
    required this.id,
    required this.reference,
    required this.waybill,
    required this.shipmentReference,
    required this.status,
    required this.barangay,
    required this.city,
    required this.province,
    required this.currentZone,
    required this.matchingZones,
    required this.canSort,
  });

  final int id;
  final String reference;
  final String waybill;
  final String shipmentReference;
  final String status;
  final String barangay;
  final String city;
  final String province;
  final String? currentZone;
  final List<LogisticsMatchingZone> matchingZones;
  final bool canSort;

  String get destination =>
      [barangay, city, province].where((part) => part.isNotEmpty).join(', ');

  factory LogisticsSortingParcel.fromJson(Object? value) {
    final map = _map(value, 'sorting parcel');
    final destination = _map(map['destination'], 'sorting destination');
    final zoneValues = _list(map['matching_zones'], 'matching sorting zones');
    final zone = map['current_zone'];
    return LogisticsSortingParcel(
      id: _integer(map['id']),
      reference: _string(map['reference']),
      waybill: _string(map['waybill']),
      shipmentReference: _string(map['shipment_reference']),
      status: _string(map['status']),
      barangay: _string(destination['barangay']),
      city: _string(destination['city_municipality']),
      province: _string(destination['province']),
      currentZone: zone is String && zone.trim().isNotEmpty
          ? zone.trim()
          : null,
      matchingZones: zoneValues
          .map(LogisticsMatchingZone.fromJson)
          .toList(growable: false),
      canSort: map['can_sort'] == true,
    );
  }
}

class LogisticsMatchingZone {
  const LogisticsMatchingZone({
    required this.id,
    required this.code,
    required this.name,
    required this.coverage,
  });

  final int id;
  final String code;
  final String name;
  final String coverage;

  factory LogisticsMatchingZone.fromJson(Object? value) {
    final map = _map(value, 'matching zone');
    return LogisticsMatchingZone(
      id: _integer(map['id']),
      code: _string(map['code']),
      name: _string(map['name']),
      coverage: _string(map['coverage']),
    );
  }
}

class LogisticsSortResult {
  const LogisticsSortResult({
    required this.parcelReference,
    required this.parcelStatus,
    required this.zoneCode,
    required this.shipmentReference,
    required this.shipmentStatus,
  });

  final String parcelReference;
  final String parcelStatus;
  final String zoneCode;
  final String shipmentReference;
  final String shipmentStatus;

  factory LogisticsSortResult.fromResponse(Object? value) {
    final root = _map(value, 'sorting result response');
    final data = _map(root['data'], 'sorting result data');
    final parcel = _map(data['parcel'], 'sorted parcel');
    final zone = _map(parcel['current_zone'], 'current sorting zone');
    final shipment = _map(data['shipment'], 'sorted shipment');
    final result = LogisticsSortResult(
      parcelReference: _string(parcel['reference']),
      parcelStatus: _string(parcel['status']),
      zoneCode: _string(zone['code']),
      shipmentReference: _string(shipment['reference']),
      shipmentStatus: _string(shipment['status']),
    );
    if (result.parcelStatus != 'sorted' ||
        result.parcelReference.isEmpty ||
        result.zoneCode.isEmpty) {
      throw const FormatException(
        'Bearly did not confirm the parcel sorting result.',
      );
    }
    return result;
  }
}

Map _map(Object? value, String path) {
  if (value is Map) return value;
  throw FormatException('Bearly returned an invalid $path.');
}

List _list(Object? value, String path) {
  if (value is List) return value;
  throw FormatException('Bearly returned an invalid $path.');
}

String _string(Object? value) => value is String ? value.trim() : '';

int _integer(Object? value) {
  if (value is int && value > 0) return value;
  final parsed = int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : 0;
}
