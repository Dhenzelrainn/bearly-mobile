enum RiderAssignmentKind { pickup, delivery }

class RiderDashboard {
  const RiderDashboard({
    required this.name,
    required this.vehicleType,
    required this.plateNumber,
    required this.availabilityStatus,
    required this.logisticsProvider,
    required this.assignedPickups,
    required this.pickupsInProgress,
    required this.assignedDeliveries,
    required this.outForDelivery,
  });

  final String name;
  final String vehicleType;
  final String plateNumber;
  final String availabilityStatus;
  final String logisticsProvider;
  final int assignedPickups;
  final int pickupsInProgress;
  final int assignedDeliveries;
  final int outForDelivery;

  factory RiderDashboard.fromJson(Object? value) {
    final map = _jsonMap(value, 'dashboard');
    final rider = _jsonMap(map['rider'], 'rider');
    final metrics = _jsonMap(map['metrics'], 'metrics');

    return RiderDashboard(
      name: _string(rider['name']),
      vehicleType: _string(rider['vehicle_type']),
      plateNumber: _string(rider['plate_number']),
      availabilityStatus: _string(rider['availability_status']),
      logisticsProvider: _string(rider['logistics_provider']),
      assignedPickups: _integer(metrics['assigned_pickups']),
      pickupsInProgress: _integer(metrics['pickup_in_progress']),
      assignedDeliveries: _integer(metrics['assigned_deliveries']),
      outForDelivery: _integer(metrics['out_for_delivery']),
    );
  }
}

class RiderAssignment {
  const RiderAssignment({
    required this.kind,
    required this.id,
    required this.title,
    required this.status,
    required this.address,
    required this.parcelCount,
    this.contactName = '',
    this.contactPhone = '',
    this.waybill = '',
    this.window = '',
    this.instructions = '',
    this.zone = '',
    this.batchNumber = '',
    this.parcels = const [],
    this.products = const [],
  });

  final RiderAssignmentKind kind;
  final String id;
  final String title;
  final String status;
  final String address;
  final int parcelCount;
  final String contactName;
  final String contactPhone;
  final String waybill;
  final String window;
  final String instructions;
  final String zone;
  final String batchNumber;
  final List<RiderJobParcel> parcels;
  final List<String> products;

  factory RiderAssignment.fromJson(Object? value) {
    final map = _jsonMap(value, 'job');
    final kind = switch (map['kind']) {
      'pickup' => RiderAssignmentKind.pickup,
      'delivery' => RiderAssignmentKind.delivery,
      _ => throw const FormatException('Unknown Rider job type.'),
    };

    final parcelEntries = <RiderJobParcel>[];
    final products = <String>[];
    if (kind == RiderAssignmentKind.pickup) {
      for (final groupValue in _jsonList(map['manifest'])) {
        final group = _jsonMap(groupValue, 'pickup manifest');
        final waybill = _string(group['waybill']);
        for (final parcelValue in _jsonList(group['parcels'])) {
          final parcel = _jsonMap(parcelValue, 'pickup parcel');
          parcelEntries.add(
            RiderJobParcel.fromJson(parcel, fallbackWaybill: waybill),
          );
        }
        for (final productValue in _jsonList(group['products'])) {
          final product = _jsonMap(productValue, 'pickup product');
          final name = _string(product['name']);
          final variant = _string(product['variant']);
          final quantity = _integer(product['quantity']);
          if (name.isNotEmpty) {
            products.add(
              '$name${variant.isEmpty ? '' : ' · $variant'} × $quantity',
            );
          }
        }
      }
    } else {
      for (final parcelValue in _jsonList(map['parcels'])) {
        parcelEntries.add(
          RiderJobParcel.fromJson(_jsonMap(parcelValue, 'delivery parcel')),
        );
      }
    }

    return RiderAssignment(
      kind: kind,
      id: _string(map['id']),
      title: _string(map['title']),
      status: _string(map['status']),
      address: _string(map['address']),
      parcelCount: _integer(map['parcel_count']),
      contactName: _string(map['contact_name']),
      contactPhone: _string(map['contact_phone']),
      waybill: _string(map['waybill']),
      window: _string(map['window']),
      instructions: _string(map['instructions']),
      zone: _string(map['zone']),
      batchNumber: _string(map['batch_no']),
      parcels: parcelEntries,
      products: products,
    );
  }
}

class RiderJobParcel {
  const RiderJobParcel({
    required this.parcelNumber,
    required this.waybill,
    required this.status,
    required this.size,
  });

  final String parcelNumber;
  final String waybill;
  final String status;
  final String size;

  factory RiderJobParcel.fromJson(
    Map<String, Object?> value, {
    String fallbackWaybill = '',
  }) => RiderJobParcel(
    parcelNumber: _string(value['parcel_no']),
    waybill: _string(value['waybill']).isNotEmpty
        ? _string(value['waybill'])
        : fallbackWaybill,
    status: _string(value['status']),
    size: _string(value['size'] ?? value['size_class']),
  );
}

Map<String, Object?> _jsonMap(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Bearly returned an invalid Rider $label.');
  }
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _jsonList(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String _string(Object? value) => value is String ? value : '';

int _integer(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
