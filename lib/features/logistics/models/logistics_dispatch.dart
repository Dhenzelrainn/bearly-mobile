import 'logistics_dashboard.dart';

class LogisticsDispatchBoard {
  const LogisticsDispatchBoard({
    required this.providerName,
    required this.sortingCenter,
    required this.zones,
  });

  final String providerName;
  final LogisticsSortingCenter sortingCenter;
  final List<LogisticsDispatchZone> zones;

  factory LogisticsDispatchBoard.fromResponse(Object? value) =>
      LogisticsDispatchBoard.fromData(
        _dispatchMap(
          _dispatchMap(value, 'dispatch board response')['data'],
          'dispatch board data',
        ),
      );

  factory LogisticsDispatchBoard.fromData(Object? value) {
    final data = _dispatchMap(value, 'dispatch board data');
    final provider = _dispatchMap(data['provider'], 'dispatch provider');
    final zones = _dispatchList(data['zones'], 'dispatch zones');
    return LogisticsDispatchBoard(
      providerName: _dispatchString(provider['name']),
      sortingCenter: LogisticsSortingCenter.fromJson(data['sorting_center']),
      zones: zones.map(LogisticsDispatchZone.fromJson).toList(growable: false),
    );
  }
}

class LogisticsDispatchZone {
  const LogisticsDispatchZone({
    required this.id,
    required this.code,
    required this.name,
    required this.coverage,
    required this.readyCount,
    required this.routingIssues,
    required this.parcels,
    required this.riders,
  });

  final int id;
  final String code;
  final String name;
  final String coverage;
  final int readyCount;
  final int routingIssues;
  final List<LogisticsDispatchParcel> parcels;
  final List<LogisticsDispatchRider> riders;

  factory LogisticsDispatchZone.fromJson(Object? value) {
    final map = _dispatchMap(value, 'dispatch zone');
    return LogisticsDispatchZone(
      id: _dispatchInt(map['id']),
      code: _dispatchString(map['zone']),
      name: _dispatchString(map['area']),
      coverage: _dispatchString(map['coverage']),
      readyCount: _dispatchInt(map['ready']),
      routingIssues: _dispatchInt(map['routing_issues']),
      parcels: _dispatchList(
        map['parcels'],
        'ready parcels',
      ).map(LogisticsDispatchParcel.fromJson).toList(growable: false),
      riders: _dispatchList(
        map['riders'],
        'eligible riders',
      ).map(LogisticsDispatchRider.fromJson).toList(growable: false),
    );
  }
}

class LogisticsDispatchParcel {
  const LogisticsDispatchParcel({
    required this.id,
    required this.reference,
    required this.waybill,
    required this.shipmentReference,
    required this.status,
  });

  final int id;
  final String reference;
  final String waybill;
  final String shipmentReference;
  final String status;

  factory LogisticsDispatchParcel.fromJson(Object? value) {
    final map = _dispatchMap(value, 'dispatch parcel');
    return LogisticsDispatchParcel(
      id: _dispatchInt(map['id']),
      reference: _dispatchString(map['reference']),
      waybill: _dispatchString(map['waybill']),
      shipmentReference: _dispatchString(map['shipment_reference']),
      status: _dispatchString(map['status']),
    );
  }
}

class LogisticsDispatchRider {
  const LogisticsDispatchRider({
    required this.id,
    required this.name,
    required this.load,
    required this.capacity,
    required this.remaining,
  });

  final int id;
  final String name;
  final int load;
  final int capacity;
  final int remaining;

  factory LogisticsDispatchRider.fromJson(Object? value) {
    final map = _dispatchMap(value, 'eligible rider');
    return LogisticsDispatchRider(
      id: _dispatchInt(map['id']),
      name: _dispatchString(map['name']),
      load: _dispatchInt(map['load'], allowZero: true),
      capacity: _dispatchInt(map['capacity'], allowZero: true),
      remaining: _dispatchInt(map['remaining'], allowZero: true),
    );
  }
}

class LogisticsDispatchResult {
  const LogisticsDispatchResult({
    required this.batchReference,
    required this.riderName,
    required this.zoneCode,
    required this.parcels,
    required this.refreshedBoard,
  });

  final String batchReference;
  final String riderName;
  final String zoneCode;
  final List<LogisticsDispatchParcel> parcels;
  final LogisticsDispatchBoard refreshedBoard;

  factory LogisticsDispatchResult.fromResponse(Object? value) {
    final root = _dispatchMap(value, 'dispatch result response');
    final data = _dispatchMap(root['data'], 'dispatch result data');
    final batch = _dispatchMap(data['dispatch_batch'], 'dispatch batch');
    final rider = _dispatchMap(batch['rider'], 'dispatch rider');
    final zone = _dispatchMap(batch['zone'], 'dispatched zone');
    final parcels = _dispatchList(
      batch['parcels'],
      'dispatched parcels',
    ).map(LogisticsDispatchParcel.fromJson).toList(growable: false);
    final result = LogisticsDispatchResult(
      batchReference: _dispatchString(batch['reference']),
      riderName: _dispatchString(rider['name']),
      zoneCode: _dispatchString(zone['code']),
      parcels: parcels,
      refreshedBoard: LogisticsDispatchBoard.fromData(
        data['refreshed_dispatch_board'],
      ),
    );
    if (batch['status'] != 'dispatched' ||
        result.batchReference.isEmpty ||
        result.zoneCode.isEmpty ||
        parcels.isEmpty ||
        parcels.any((parcel) => parcel.status != 'dispatched')) {
      throw const FormatException(
        'Bearly did not confirm the complete delivery dispatch.',
      );
    }
    return result;
  }
}

Map _dispatchMap(Object? value, String path) {
  if (value is Map) return value;
  throw FormatException('Bearly returned an invalid $path.');
}

List _dispatchList(Object? value, String path) {
  if (value is List) return value;
  throw FormatException('Bearly returned an invalid $path.');
}

String _dispatchString(Object? value) => value is String ? value.trim() : '';

int _dispatchInt(Object? value, {bool allowZero = false}) {
  final parsed = value is int ? value : int.tryParse('$value');
  if (parsed == null || parsed < (allowZero ? 0 : 1)) return 0;
  return parsed;
}
