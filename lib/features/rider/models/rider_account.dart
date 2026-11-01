class RiderAccount {
  const RiderAccount({
    required this.name,
    required this.email,
    required this.accountStatus,
    required this.verificationStatus,
    required this.availabilityStatus,
    this.workType = 'unknown',
    this.supportsLocalFulfillment = false,
    required this.vehicleType,
    required this.vehicleModel,
    required this.plateNumber,
    required this.parcelCapacity,
    required this.logisticsProvider,
    required this.homeSortingCenter,
    required this.currentZone,
    required this.currentZoneCenter,
    required this.addresses,
    required this.documents,
  });

  final String name;
  final String email;
  final String accountStatus;
  final String verificationStatus;
  final String availabilityStatus;
  final String workType;
  final bool supportsLocalFulfillment;
  final String vehicleType;
  final String vehicleModel;
  final String plateNumber;
  final int? parcelCapacity;
  final String logisticsProvider;
  final String homeSortingCenter;
  final String currentZone;
  final String currentZoneCenter;
  final List<RiderAccountAddress> addresses;
  final Map<String, String> documents;

  factory RiderAccount.fromJson(Object? value) {
    final data = _map(value, 'account');
    final vehicle = _map(data['vehicle'], 'vehicle');
    final provider = _map(data['logistics_provider'], 'Logistics provider');
    final sorting = _map(data['sorting'], 'sorting assignments');
    final documentValues = _map(data['documents'], 'documents');
    final capabilities = data['capabilities'] is Map
        ? _map(data['capabilities'], 'capabilities')
        : const <String, Object?>{};
    final workType = _string(data['work_type']).trim().toLowerCase();
    final supportsLocalFulfillment =
        capabilities['local_pickup'] is bool &&
            capabilities['local_delivery'] is bool
        ? capabilities['local_pickup'] == true &&
              capabilities['local_delivery'] == true
        : workType == 'local';

    return RiderAccount(
      name: _string(data['name']),
      email: _string(data['email']),
      accountStatus: _string(data['account_status']),
      verificationStatus: _string(data['verification_status']),
      availabilityStatus: _string(data['availability_status']),
      workType: workType.isEmpty ? 'unknown' : workType,
      supportsLocalFulfillment: supportsLocalFulfillment,
      vehicleType: _string(vehicle['type']),
      vehicleModel: _string(vehicle['model']),
      plateNumber: _string(vehicle['plate_number']),
      parcelCapacity: _integerOrNull(vehicle['parcel_capacity']),
      logisticsProvider: _string(provider['name']),
      homeSortingCenter: _string(sorting['home_center']),
      currentZone: _string(sorting['current_zone']),
      currentZoneCenter: _string(sorting['current_zone_center']),
      addresses: _list(data['addresses'])
          .map((entry) => RiderAccountAddress.fromJson(entry))
          .toList(growable: false),
      documents: documentValues.map(
        (key, status) => MapEntry(key, _string(status)),
      ),
    );
  }
}

class RiderAccountAddress {
  const RiderAccountAddress({required this.label, required this.address});

  final String label;
  final String address;

  factory RiderAccountAddress.fromJson(Object? value) {
    final map = _map(value, 'address');
    return RiderAccountAddress(
      label: _string(map['label']),
      address: _string(map['address']),
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

int? _integerOrNull(Object? value) =>
    value is int ? value : int.tryParse('$value');
