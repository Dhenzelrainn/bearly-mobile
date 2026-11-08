class LogisticsRidersResponse {
  const LogisticsRidersResponse({
    required this.providerId,
    required this.providerName,
    required this.riders,
  });

  final int providerId;
  final String providerName;
  final List<LogisticsRider> riders;

  factory LogisticsRidersResponse.fromResponse(Object? response) {
    final data = _map(response)?['data'];
    final root = _map(data);
    final provider = _map(root?['provider']);
    final rows = root?['riders'];
    if (root == null || provider == null || rows is! List) {
      throw const FormatException('Missing Logistics Rider roster data.');
    }

    return LogisticsRidersResponse(
      providerId: _integer(provider['id']),
      providerName: _text(provider['name']),
      riders: rows
          .map((row) {
            final map = _map(row);
            if (map == null) {
              throw const FormatException('Invalid Rider roster entry.');
            }
            return LogisticsRider.fromJson(map);
          })
          .toList(growable: false),
    );
  }
}

class LogisticsRider {
  const LogisticsRider({
    required this.userId,
    required this.profileId,
    required this.name,
    required this.workType,
    required this.workTypeLabel,
    required this.accountStatus,
    required this.verificationStatus,
    required this.applicationStatus,
    required this.availabilityStatus,
    required this.operationalStatus,
    required this.vehicleType,
    required this.vehicleModel,
    required this.plateNumber,
    required this.currentZone,
    required this.homeSortingCenter,
    required this.specialization,
    required this.specializationLabel,
    required this.capacity,
    required this.capacityLabel,
    required this.activeJobs,
    required this.completedToday,
  });

  final int userId;
  final int profileId;
  final String name;
  final String workType;
  final String workTypeLabel;
  final String accountStatus;
  final String verificationStatus;
  final String? applicationStatus;
  final String availabilityStatus;
  final String operationalStatus;
  final String vehicleType;
  final String? vehicleModel;
  final String? plateNumber;
  final String? currentZone;
  final String? homeSortingCenter;
  final String? specialization;
  final String? specializationLabel;
  final int? capacity;
  final String capacityLabel;
  final int activeJobs;
  final int completedToday;

  bool get isCourier => workType == 'courier';

  bool get canManageLocalActions =>
      workType == 'local' &&
      accountStatus == 'active' &&
      verificationStatus == 'approved' &&
      applicationStatus == 'approved';

  factory LogisticsRider.fromResponse(Object? response) {
    final rider = _map(_map(response)?['data'])?['rider'];
    final data = _map(rider);
    if (data == null) {
      throw const FormatException('Missing Logistics Rider details.');
    }
    return LogisticsRider.fromJson(data);
  }

  factory LogisticsRider.fromJson(Map<Object?, Object?> json) => LogisticsRider(
    userId: _integer(json['user_id'] ?? json['id']),
    profileId: _integer(json['profile_id']),
    name: _text(json['name'], fallback: 'Rider'),
    workType: _text(json['work_type'], fallback: 'local'),
    workTypeLabel: _text(json['work_type_label'], fallback: 'Local Rider'),
    accountStatus: _text(json['account_status'], fallback: 'unknown'),
    verificationStatus: _text(json['verification_status'], fallback: 'unknown'),
    applicationStatus: _optionalText(json['application_status']),
    availabilityStatus: _text(json['availability_status'], fallback: 'offline'),
    operationalStatus: _text(json['operational_status'], fallback: 'offline'),
    vehicleType: _text(json['vehicle_type'], fallback: 'Not specified'),
    vehicleModel: _optionalText(json['vehicle_model']),
    plateNumber: _optionalText(json['plate_number']),
    currentZone: _optionalText(json['current_zone']),
    homeSortingCenter: _optionalText(json['home_sorting_center']),
    specialization: _optionalText(json['specialization']),
    specializationLabel: _optionalText(json['specialization_label']),
    capacity: _optionalInteger(json['capacity']),
    capacityLabel: _text(json['capacity_label']),
    activeJobs: _integer(json['active_jobs']),
    completedToday: _integer(json['completed_today']),
  );
}

Map<Object?, Object?>? _map(Object? value) => value is Map ? value : null;

int _integer(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;

int? _optionalInteger(Object? value) =>
    value == null ? null : int.tryParse('$value');

String _text(Object? value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

String? _optionalText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
