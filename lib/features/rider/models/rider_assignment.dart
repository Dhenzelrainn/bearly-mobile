import '../../../core/models/product_preview.dart';
import 'rider_operational_status.dart';

enum RiderAssignmentKind { pickup, delivery }

class RiderDashboard {
  const RiderDashboard({
    required this.name,
    required this.vehicleType,
    required this.plateNumber,
    required this.availabilityStatus,
    required this.logisticsProvider,
    this.vehicleModel = '',
    this.homeSortingCenter = '',
    this.currentZone = '',
    this.currentZoneCenter = '',
    this.workType = 'unknown',
    this.supportsLocalFulfillment = false,
    this.operationalStatus,
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
  final String vehicleModel;
  final String homeSortingCenter;
  final String currentZone;
  final String currentZoneCenter;
  final String workType;
  final bool supportsLocalFulfillment;
  final RiderOperationalStatus? operationalStatus;
  final int assignedPickups;
  final int pickupsInProgress;
  final int assignedDeliveries;
  final int outForDelivery;

  factory RiderDashboard.fromJson(Object? value) {
    final map = _jsonMap(value, 'dashboard');
    final rider = _jsonMap(map['rider'], 'rider');
    final metrics = _jsonMap(map['metrics'], 'metrics');
    final operationalValue = map['operational_status'];
    final capabilities = rider['capabilities'] is Map
        ? _jsonMap(rider['capabilities'], 'capabilities')
        : const <String, Object?>{};
    final workType = _string(rider['work_type']).trim().toLowerCase();
    final supportsLocalFulfillment =
        capabilities['local_pickup'] is bool &&
            capabilities['local_delivery'] is bool
        ? capabilities['local_pickup'] == true &&
              capabilities['local_delivery'] == true
        : workType == 'local';

    return RiderDashboard(
      name: _string(rider['name']),
      vehicleType: _string(rider['vehicle_type']),
      plateNumber: _string(rider['plate_number']),
      availabilityStatus: _string(rider['availability_status']),
      logisticsProvider: _string(rider['logistics_provider']),
      vehicleModel: _string(rider['vehicle_model']),
      homeSortingCenter: _string(rider['home_sorting_center']),
      currentZone: _string(rider['current_zone']),
      currentZoneCenter: _string(rider['current_zone_center']),
      workType: workType.isEmpty ? 'unknown' : workType,
      supportsLocalFulfillment: supportsLocalFulfillment,
      operationalStatus: operationalValue == null
          ? null
          : RiderOperationalStatus.fromJson(operationalValue),
      assignedPickups: _integer(metrics['assigned_pickups']),
      pickupsInProgress: _integer(metrics['pickup_in_progress']),
      assignedDeliveries: _integer(metrics['assigned_deliveries']),
      outForDelivery: _integer(metrics['out_for_delivery']),
    );
  }

  RiderDashboard copyWith({RiderOperationalStatus? operationalStatus}) =>
      RiderDashboard(
        name: name,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
        availabilityStatus:
            operationalStatus?.availabilityStatus ?? availabilityStatus,
        logisticsProvider: logisticsProvider,
        vehicleModel: vehicleModel,
        homeSortingCenter: homeSortingCenter,
        currentZone: currentZone,
        currentZoneCenter: currentZoneCenter,
        workType: workType,
        supportsLocalFulfillment: supportsLocalFulfillment,
        operationalStatus: operationalStatus ?? this.operationalStatus,
        assignedPickups: assignedPickups,
        pickupsInProgress: pickupsInProgress,
        assignedDeliveries: assignedDeliveries,
        outForDelivery: outForDelivery,
      );
}

class RiderAssignment {
  const RiderAssignment({
    required this.kind,
    required this.id,
    required this.title,
    required this.status,
    this.statusRaw = '',
    this.canStartDelivery = false,
    this.canRetry = false,
    this.retryAvailableAt,
    this.retryUnavailableReason = '',
    this.codDueMinor = 0,
    this.requiresCodCollection = false,
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
    this.productItems = const [],
  });

  final RiderAssignmentKind kind;
  final String id;
  final String title;
  final String status;
  final String statusRaw;
  final bool canStartDelivery;
  final bool canRetry;
  final DateTime? retryAvailableAt;
  final String retryUnavailableReason;
  final int codDueMinor;
  final bool requiresCodCollection;
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
  final List<ProductPreview> productItems;

  factory RiderAssignment.fromJson(Object? value) {
    final map = _jsonMap(value, 'job');
    final kind = switch (map['kind']) {
      'pickup' => RiderAssignmentKind.pickup,
      'delivery' => RiderAssignmentKind.delivery,
      _ => throw const FormatException('Unknown Rider job type.'),
    };

    final parcelEntries = <RiderJobParcel>[];
    final products = <String>[];
    final productItems = <ProductPreview>[];
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
          productItems.add(ProductPreview.fromJson(productValue));
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
      productItems.addAll(ProductPreview.listFromJson(map['products']));
      for (final parcelValue in _jsonList(map['parcels'])) {
        parcelEntries.add(
          RiderJobParcel.fromJson(_jsonMap(parcelValue, 'delivery parcel')),
        );
      }
    }

    final status = _string(map['status']);
    final statusRaw = _string(map['status_raw']);

    return RiderAssignment(
      kind: kind,
      id: _string(map['id']),
      title: _string(map['title']),
      status: status,
      statusRaw: statusRaw.isNotEmpty
          ? statusRaw
          : status.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      canStartDelivery: map['can_start_delivery'] == true,
      canRetry: map['can_retry'] == true,
      retryAvailableAt: DateTime.tryParse(_string(map['retry_available_at'])),
      retryUnavailableReason: _string(map['retry_unavailable_reason']),
      codDueMinor: _integer(map['cod_due_minor']),
      requiresCodCollection: map['requires_cod_collection'] == true,
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
      productItems: productItems,
    );
  }
}

class RiderDeliveryCompletion {
  const RiderDeliveryCompletion({
    required this.assignment,
    required this.shipmentStatus,
    required this.alreadyCompleted,
    this.codCollection,
  });

  final RiderAssignment assignment;
  final String shipmentStatus;
  final bool alreadyCompleted;
  final RiderCodCollection? codCollection;

  factory RiderDeliveryCompletion.fromJson(Object? value) {
    final map = _jsonMap(value, 'delivery completion');
    final collection = map['cod_collection'];
    return RiderDeliveryCompletion(
      assignment: RiderAssignment.fromJson(map),
      shipmentStatus: _string(map['shipment_status']),
      alreadyCompleted: map['already_completed'] == true,
      codCollection: collection == null
          ? null
          : RiderCodCollection.fromJson(_jsonMap(collection, 'COD collection')),
    );
  }
}

class RiderDeliveryVerificationProgress {
  const RiderDeliveryVerificationProgress({
    required this.assignedParcelNumbers,
    required this.verifiedParcelNumbers,
    required this.verifiedCount,
    required this.totalCount,
    required this.allVerified,
    this.parcelNumber = '',
    this.newlyVerified = false,
    this.verifiedAt,
  });

  final List<String> assignedParcelNumbers;
  final List<String> verifiedParcelNumbers;
  final int verifiedCount;
  final int totalCount;
  final bool allVerified;
  final String parcelNumber;
  final bool newlyVerified;
  final DateTime? verifiedAt;

  bool isVerified(String parcelNumber) =>
      verifiedParcelNumbers.contains(parcelNumber);

  factory RiderDeliveryVerificationProgress.fromJson(Object? value) {
    final map = _jsonMap(value, 'delivery verification progress');
    return RiderDeliveryVerificationProgress(
      assignedParcelNumbers: _stringList(map['assigned_parcel_nos']),
      verifiedParcelNumbers: _stringList(map['verified_parcel_nos']),
      verifiedCount: _integer(map['verified_count']),
      totalCount: _integer(map['total_count']),
      allVerified: map['all_verified'] == true,
      parcelNumber: _string(map['parcel_no']),
      newlyVerified: map['newly_verified'] == true,
      verifiedAt: DateTime.tryParse(_string(map['verified_at'])),
    );
  }
}

class RiderCodCollection {
  const RiderCodCollection({
    required this.status,
    required this.amountDueMinor,
    required this.amountCollectedMinor,
    required this.discrepancyMinor,
  });

  final String status;
  final int amountDueMinor;
  final int amountCollectedMinor;
  final int discrepancyMinor;

  factory RiderCodCollection.fromJson(Map<String, Object?> value) =>
      RiderCodCollection(
        status: _string(value['status']),
        amountDueMinor: _integer(value['amount_due_minor']),
        amountCollectedMinor: _integer(value['amount_collected_minor']),
        discrepancyMinor: _integer(value['discrepancy_minor']),
      );
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

List<String> _stringList(Object? value) =>
    _jsonList(value).whereType<String>().toList(growable: false);

String _string(Object? value) => value is String ? value : '';

int _integer(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
