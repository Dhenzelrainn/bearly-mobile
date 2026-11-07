import '../../../core/models/product_preview.dart';

class RiderHistory {
  const RiderHistory({
    required this.entries,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<RiderHistoryEntry> entries;
  final int currentPage;
  final int lastPage;
  final int total;

  factory RiderHistory.fromJson(Object? value) {
    final map = _map(value, 'history');
    final meta = _map(map['meta'], 'history metadata');
    return RiderHistory(
      entries: _list(
        map['data'],
      ).map(RiderHistoryEntry.fromJson).toList(growable: false),
      currentPage: _integer(meta['current_page']),
      lastPage: _integer(meta['last_page']),
      total: _integer(meta['total']),
    );
  }
}

class RiderHistoryEntry {
  const RiderHistoryEntry({
    required this.shipmentNumber,
    required this.parcelNumber,
    required this.date,
    required this.area,
    required this.status,
    required this.statusLabel,
    required this.earning,
    required this.batchNumber,
    required this.attempt,
    this.products = const [],
  });

  final String shipmentNumber;
  final String parcelNumber;
  final String date;
  final String area;
  final String status;
  final String statusLabel;
  final String earning;
  final String batchNumber;
  final String attempt;
  final List<ProductPreview> products;

  factory RiderHistoryEntry.fromJson(Object? value) {
    final map = _map(value, 'history entry');
    return RiderHistoryEntry(
      shipmentNumber: _string(map['shipment_no']),
      parcelNumber: _string(map['parcel_no']),
      date: _string(map['date']),
      area: _string(map['area']),
      status: _string(map['status']),
      statusLabel: _string(map['status_label']),
      earning: _string(map['earning']),
      batchNumber: _string(map['batch_no']),
      attempt: _string(map['attempt']),
      products: ProductPreview.listFromJson(map['products']),
    );
  }
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Bearly returned invalid Rider $label data.');
  }
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String _string(Object? value) => value is String ? value : '';

int _integer(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
