import 'logistics_dashboard.dart';

class LogisticsIncomingParcelsResult {
  const LogisticsIncomingParcelsResult({
    required this.providerName,
    required this.parcels,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final String providerName;
  final List<LogisticsIncomingParcelRecord> parcels;
  final int currentPage;
  final int lastPage;
  final int total;

  factory LogisticsIncomingParcelsResult.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'data');
    final provider = _map(data['provider'], 'provider');
    final pagination = _map(data['pagination'], 'pagination');
    final values = _list(data['parcels'], 'parcels');

    return LogisticsIncomingParcelsResult(
      providerName: _string(provider['name']),
      parcels: values
          .map(LogisticsIncomingParcelRecord.fromJson)
          .toList(growable: false),
      currentPage: _integer(pagination['current_page']),
      lastPage: _integer(pagination['last_page']),
      total: _integer(pagination['total']),
    );
  }
}

class LogisticsIncomingParcelRecord {
  const LogisticsIncomingParcelRecord({
    required this.waybill,
    required this.shipmentReference,
    required this.shipmentStatus,
    required this.purpose,
    required this.purposeLabel,
    required this.status,
    required this.expectedPieceCount,
    required this.parcelRecordCount,
    required this.receivedPieceCount,
    required this.remainingPieceCount,
    required this.receivedAt,
    required this.seller,
    required this.receivedFrom,
    required this.destination,
    required this.currentSortingCenters,
    required this.parcelStatuses,
    this.pieces = const [],
    this.receivingSortingCenter,
    this.sizeClasses = const [],
  });

  final String waybill;
  final String shipmentReference;
  final String shipmentStatus;
  final String purpose;
  final String purposeLabel;
  final String status;
  final int expectedPieceCount;
  final int parcelRecordCount;
  final int receivedPieceCount;
  final int remainingPieceCount;
  final DateTime? receivedAt;
  final String seller;
  final String receivedFrom;
  final String destination;
  final List<LogisticsSortingCenter> currentSortingCenters;
  final List<String> parcelStatuses;
  final List<LogisticsIncomingParcelPiece> pieces;
  final LogisticsSortingCenter? receivingSortingCenter;
  final List<String> sizeClasses;

  factory LogisticsIncomingParcelRecord.fromJson(Object? value) {
    final map = _map(value, 'incoming parcel');
    final receivedAtValue = map['received_at'];
    final centers = _list(map['current_sorting_centers'], 'sorting centers');
    return LogisticsIncomingParcelRecord(
      waybill: _string(map['waybill']),
      shipmentReference: _string(map['shipment_reference']),
      shipmentStatus: _string(map['shipment_status']),
      purpose: _string(map['purpose']),
      purposeLabel: _string(map['purpose_label']),
      status: _string(map['status']),
      expectedPieceCount: _integer(map['expected_piece_count']),
      parcelRecordCount: _integer(map['parcel_record_count']),
      receivedPieceCount: _integer(map['received_piece_count']),
      remainingPieceCount: _integer(map['remaining_piece_count']),
      receivedAt: receivedAtValue is String
          ? DateTime.tryParse(receivedAtValue)
          : null,
      seller: _string(map['seller']),
      receivedFrom: _string(map['received_from']),
      destination: _string(map['destination']),
      currentSortingCenters: centers
          .map(LogisticsSortingCenter.fromJson)
          .toList(growable: false),
      parcelStatuses: _stringList(map['parcel_statuses']),
      sizeClasses: _stringList(map['size_classes']),
    );
  }

  LogisticsIncomingParcelRecord withPieces(
    List<LogisticsIncomingParcelPiece> value, {
    LogisticsSortingCenter? receivingCenter,
    List<String>? availableSizeClasses,
  }) => LogisticsIncomingParcelRecord(
    waybill: waybill,
    shipmentReference: shipmentReference,
    shipmentStatus: shipmentStatus,
    purpose: purpose,
    purposeLabel: purposeLabel,
    status: status,
    expectedPieceCount: expectedPieceCount,
    parcelRecordCount: parcelRecordCount,
    receivedPieceCount: receivedPieceCount,
    remainingPieceCount: remainingPieceCount,
    receivedAt: receivedAt,
    seller: seller,
    receivedFrom: receivedFrom,
    destination: destination,
    currentSortingCenters: currentSortingCenters,
    parcelStatuses: parcelStatuses,
    pieces: value,
    receivingSortingCenter: receivingCenter ?? receivingSortingCenter,
    sizeClasses: availableSizeClasses ?? sizeClasses,
  );
}

class LogisticsIncomingParcelPiece {
  const LogisticsIncomingParcelPiece({
    required this.parcel,
    required this.pieceSequence,
    required this.status,
    required this.weightKg,
    required this.sizeClass,
    required this.currentSortingCenter,
    required this.intakeHistory,
    required this.receiptEligibility,
  });

  final String parcel;
  final int pieceSequence;
  final String status;
  final String weightKg;
  final String? sizeClass;
  final LogisticsSortingCenter? currentSortingCenter;
  final List<LogisticsParcelIntakeEvent> intakeHistory;
  final LogisticsReceiptEligibility receiptEligibility;

  factory LogisticsIncomingParcelPiece.fromJson(Object? value) {
    final map = _map(value, 'parcel piece');
    final center = map['current_sorting_center'];
    return LogisticsIncomingParcelPiece(
      parcel: _string(map['parcel']),
      pieceSequence: _integer(map['piece_sequence']),
      status: _string(map['status']),
      weightKg: _string(map['weight_kg']),
      sizeClass: map['size_class'] is String
          ? _string(map['size_class'])
          : null,
      currentSortingCenter: center == null
          ? null
          : LogisticsSortingCenter.fromJson(center),
      receiptEligibility: LogisticsReceiptEligibility.fromJson(
        map['receipt_eligibility'],
      ),
      intakeHistory: _list(
        map['intake_history'],
        'intake history',
      ).map(LogisticsParcelIntakeEvent.fromJson).toList(growable: false),
    );
  }
}

class LogisticsIncomingParcelReceipt {
  const LogisticsIncomingParcelReceipt({
    required this.waybill,
    required this.piece,
    required this.evidence,
  });

  final LogisticsIncomingParcelRecord waybill;
  final LogisticsIncomingParcelPiece piece;
  final LogisticsParcelIntakeEvent? evidence;

  factory LogisticsIncomingParcelReceipt.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'receipt data');
    final evidence = data['receipt_evidence'];
    return LogisticsIncomingParcelReceipt(
      waybill: LogisticsIncomingParcelRecord.fromJson(data['waybill']),
      piece: LogisticsIncomingParcelPiece.fromJson(data['piece']),
      evidence: evidence == null
          ? null
          : LogisticsParcelIntakeEvent.fromJson(evidence),
    );
  }
}

class LogisticsParcelIntakeEvent {
  const LogisticsParcelIntakeEvent({
    required this.event,
    required this.fromStatus,
    required this.toStatus,
    required this.scanMethod,
    required this.occurredAt,
    required this.sortingCenterName,
    required this.sortingCenterCode,
  });

  final String event;
  final String fromStatus;
  final String toStatus;
  final String scanMethod;
  final DateTime? occurredAt;
  final String sortingCenterName;
  final String sortingCenterCode;

  factory LogisticsParcelIntakeEvent.fromJson(Object? value) {
    final map = _map(value, 'intake history item');
    final center = map['sorting_center'] is Map
        ? map['sorting_center'] as Map
        : const {};
    final occurred = map['occurred_at'];
    return LogisticsParcelIntakeEvent(
      event: _string(map['event']),
      fromStatus: _string(map['from_status']),
      toStatus: _string(map['to_status']),
      scanMethod: _string(map['scan_method']),
      occurredAt: occurred is String ? DateTime.tryParse(occurred) : null,
      sortingCenterName: _string(center['name']),
      sortingCenterCode: _string(center['code']),
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
