import '../../../core/models/product_preview.dart';
import 'logistics_dashboard.dart';
import 'logistics_dispatch.dart';
import 'logistics_sorting.dart';

class LogisticsSortingWorkspace {
  const LogisticsSortingWorkspace({
    required this.providerName,
    required this.sortingCenter,
    required this.setupRequired,
    required this.setupMessage,
    required this.zones,
    required this.parcels,
    required this.metrics,
    required this.pagination,
    required this.statusFilter,
    required this.search,
    required this.dispatchReadiness,
  });

  final String providerName;
  final LogisticsSortingCenter? sortingCenter;
  final bool setupRequired;
  final String? setupMessage;
  final List<LogisticsSortingWorkspaceZone> zones;
  final List<LogisticsSortingWorkspaceParcel> parcels;
  final LogisticsSortingWorkspaceMetrics metrics;
  final LogisticsSortingWorkspacePagination pagination;
  final String statusFilter;
  final String search;
  final LogisticsDispatchBoard? dispatchReadiness;

  factory LogisticsSortingWorkspace.fromResponse(Object? value) {
    final root = _map(value, 'sorting center response');
    final data = _map(root['data'], 'sorting center data');
    final provider = _map(data['provider'], 'sorting provider');
    final zones = _list(data['zones'], 'sorting zones');
    final parcels = _list(data['parcels'], 'sorting parcels');
    final filters = _map(data['filters'], 'sorting filters');
    final center = data['sorting_center'];
    final dispatchValue = data['dispatch_readiness'];
    return LogisticsSortingWorkspace(
      providerName: _string(provider['name']),
      sortingCenter: center == null
          ? null
          : LogisticsSortingCenter.fromJson(center),
      setupRequired: data['setup_required'] == true,
      setupMessage: _nullableString(data['setup_message']),
      zones: zones
          .map(LogisticsSortingWorkspaceZone.fromJson)
          .toList(growable: false),
      parcels: parcels
          .map(LogisticsSortingWorkspaceParcel.fromJson)
          .toList(growable: false),
      metrics: LogisticsSortingWorkspaceMetrics.fromJson(data['metrics']),
      pagination: LogisticsSortingWorkspacePagination.fromJson(
        data['pagination'],
      ),
      statusFilter: _string(filters['status']),
      search: _string(filters['search']),
      dispatchReadiness: dispatchValue == null
          ? null
          : LogisticsDispatchBoard.fromData(dispatchValue),
    );
  }
}

class LogisticsSortingWorkspaceMetrics {
  const LogisticsSortingWorkspaceMetrics({
    required this.awaitingSorting,
    required this.sorted,
    required this.exceptions,
  });

  final int awaitingSorting;
  final int sorted;
  final int exceptions;

  factory LogisticsSortingWorkspaceMetrics.fromJson(Object? value) {
    final map = _map(value, 'sorting metrics');
    return LogisticsSortingWorkspaceMetrics(
      awaitingSorting: _int(map['awaiting_sorting']),
      sorted: _int(map['sorted']),
      exceptions: _int(map['exceptions']),
    );
  }
}

class LogisticsSortingWorkspacePagination {
  const LogisticsSortingWorkspacePagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMorePages,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  factory LogisticsSortingWorkspacePagination.fromJson(Object? value) {
    final map = _map(value, 'sorting pagination');
    return LogisticsSortingWorkspacePagination(
      currentPage: _int(map['current_page'], fallback: 1),
      lastPage: _int(map['last_page'], fallback: 1),
      perPage: _int(map['per_page'], fallback: 20),
      total: _int(map['total']),
      hasMorePages: map['has_more_pages'] == true,
    );
  }
}

class LogisticsSortingWorkspaceZone {
  const LogisticsSortingWorkspaceZone({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.coverage,
  });

  final int id;
  final String code;
  final String name;
  final String status;
  final String coverage;

  factory LogisticsSortingWorkspaceZone.fromJson(Object? value) {
    final map = _map(value, 'sorting zone');
    return LogisticsSortingWorkspaceZone(
      id: _int(map['id']),
      code: _string(map['code']),
      name: _string(map['name']),
      status: _string(map['status']),
      coverage: _string(map['coverage']),
    );
  }
}

class LogisticsSortingWorkspaceParcel {
  const LogisticsSortingWorkspaceParcel({
    required this.id,
    required this.reference,
    required this.waybill,
    required this.shipmentReference,
    required this.purpose,
    required this.status,
    required this.pieceSequence,
    required this.pieceCount,
    required this.products,
    required this.barangay,
    required this.city,
    required this.province,
    required this.currentZone,
    required this.matchingZones,
    required this.pieces,
    required this.sortingHistory,
  });

  final int id;
  final String reference;
  final String waybill;
  final String shipmentReference;
  final String purpose;
  final String status;
  final int pieceSequence;
  final int pieceCount;
  final List<ProductPreview> products;
  final String barangay;
  final String city;
  final String province;
  final LogisticsSortingWorkspaceZone? currentZone;
  final List<LogisticsMatchingZone> matchingZones;
  final List<LogisticsSortingWorkspacePiece> pieces;
  final List<LogisticsSortingHistoryEntry> sortingHistory;

  String get destination =>
      [barangay, city, province].where((part) => part.isNotEmpty).join(', ');

  factory LogisticsSortingWorkspaceParcel.fromJson(Object? value) {
    final map = _map(value, 'sorting parcel');
    final destination = _map(map['destination'], 'sorting destination');
    final zoneValue = map['current_zone_detail'];
    return LogisticsSortingWorkspaceParcel(
      id: _int(map['id']),
      reference: _string(map['reference']),
      waybill: _string(map['waybill']),
      shipmentReference: _string(map['shipment_reference']),
      purpose: _string(map['purpose']),
      status: _string(map['status']),
      pieceSequence: _int(map['piece_sequence']),
      pieceCount: _int(map['piece_count'], fallback: 1),
      products: ProductPreview.listFromJson(map['products']),
      barangay: _string(destination['barangay']),
      city: _string(destination['city_municipality']),
      province: _string(destination['province']),
      currentZone: zoneValue == null
          ? null
          : LogisticsSortingWorkspaceZone.fromJson(zoneValue),
      matchingZones: _list(
        map['matching_zones'],
        'matching zones',
      ).map(LogisticsMatchingZone.fromJson).toList(growable: false),
      pieces: _list(
        map['pieces'],
        'waybill pieces',
      ).map(LogisticsSortingWorkspacePiece.fromJson).toList(growable: false),
      sortingHistory: _list(
        map['sorting_history'],
        'sorting history',
      ).map(LogisticsSortingHistoryEntry.fromJson).toList(growable: false),
    );
  }
}

class LogisticsSortingWorkspacePiece {
  const LogisticsSortingWorkspacePiece({
    required this.reference,
    required this.sequence,
    required this.status,
    required this.currentZone,
  });

  final String reference;
  final int sequence;
  final String status;
  final String? currentZone;

  factory LogisticsSortingWorkspacePiece.fromJson(Object? value) {
    final map = _map(value, 'waybill piece');
    final currentZone = _string(map['current_zone']);
    return LogisticsSortingWorkspacePiece(
      reference: _string(map['reference']),
      sequence: _int(map['sequence']),
      status: _string(map['status']),
      currentZone: currentZone.isEmpty ? null : currentZone,
    );
  }
}

class LogisticsSortingHistoryEntry {
  const LogisticsSortingHistoryEntry({
    required this.event,
    required this.fromStatus,
    required this.toStatus,
    required this.sortingCenter,
    required this.sortingZone,
    required this.occurredAt,
  });

  final String event;
  final String? fromStatus;
  final String? toStatus;
  final String? sortingCenter;
  final String? sortingZone;
  final DateTime? occurredAt;

  factory LogisticsSortingHistoryEntry.fromJson(Object? value) {
    final map = _map(value, 'sorting history entry');
    return LogisticsSortingHistoryEntry(
      event: _string(map['event']),
      fromStatus: _nullableString(map['from_status']),
      toStatus: _nullableString(map['to_status']),
      sortingCenter: _nullableString(map['sorting_center']),
      sortingZone: _nullableString(map['sorting_zone']),
      occurredAt: DateTime.tryParse(_string(map['occurred_at'])),
    );
  }
}

Map _map(Object? value, String label) {
  if (value is Map) return value;
  throw FormatException('Bearly returned an invalid $label.');
}

List _list(Object? value, String label) {
  if (value is List) return value;
  throw FormatException('Bearly returned an invalid $label.');
}

String _string(Object? value) => value is String ? value.trim() : '';

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(Object? value, {int fallback = 0}) {
  final parsed = value is int ? value : int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : fallback;
}
