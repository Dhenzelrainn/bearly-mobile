import '../../../core/network/api_client.dart';

class RegistrationVerificationChallenge {
  const RegistrationVerificationChallenge({
    required this.verificationId,
    required this.retryAfter,
    required this.expiresIn,
  });

  final String verificationId;
  final int retryAfter;
  final int expiresIn;
}

class RegistrationPartner {
  const RegistrationPartner({required this.id, required this.name});

  final int id;
  final String name;

  factory RegistrationPartner.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid partner response.');
    final idValue = value['id'];
    final id = idValue is int ? idValue : int.tryParse('$idValue');
    final name = value['name'];
    if (id == null || name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid partner response.');
    }
    return RegistrationPartner(id: id, name: name.trim());
  }
}

class RegistrationOutcome {
  const RegistrationOutcome({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.message,
    this.workType,
    this.reviewAuthority,
  });

  final int userId;
  final String name;
  final String email;
  final String role;
  final String status;
  final String message;
  final String? workType;
  final String? reviewAuthority;

  factory RegistrationOutcome.fromJson(Object? value) {
    if (value is! Map || value['data'] is! Map) {
      throw const FormatException(
        'Bearly returned an unreadable registration response.',
      );
    }
    final data = value['data'] as Map;
    final idValue = data['user_id'];
    final id = idValue is int ? idValue : int.tryParse('$idValue');
    final name = data['name'];
    final email = data['email'];
    final role = data['role'];
    final status = data['status'];
    final message = value['message'];
    if (id == null ||
        name is! String ||
        email is! String ||
        role is! String ||
        status is! String ||
        message is! String) {
      throw const FormatException(
        'Bearly returned an incomplete registration response.',
      );
    }
    return RegistrationOutcome(
      userId: id,
      name: name,
      email: email,
      role: role,
      status: status,
      message: message,
      workType: data['work_type'] is String
          ? data['work_type'] as String
          : null,
      reviewAuthority: data['review_authority'] is String
          ? data['review_authority'] as String
          : null,
    );
  }
}

abstract interface class RegistrationDataSource {
  Future<RegistrationVerificationChallenge> sendEmailCode(String email);

  Future<void> verifyEmailCode({
    required String email,
    required String code,
    required String verificationId,
  });

  Future<List<RegistrationPartner>> logisticsPartners(String cityCode);

  Future<RegistrationOutcome> registerBuyer(Map<String, Object?> fields);

  Future<RegistrationOutcome> registerRider({
    required Map<String, String> fields,
    required List<ApiMultipartFile> documents,
  });

  Future<RegistrationOutcome> registerLogistics({
    required Map<String, String> fields,
    required List<ApiMultipartFile> documents,
  });
}

class RegistrationRepository implements RegistrationDataSource {
  RegistrationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<RegistrationVerificationChallenge> sendEmailCode(String email) async {
    final response = _asMap(
      await _apiClient.post(
        '/api/mobile/register/email/send',
        body: {'email': email.trim().toLowerCase()},
      ),
    );
    final id = response['verification_id'];
    if (id is! String || id.length != 64) {
      throw const FormatException(
        'Bearly did not return a valid verification request.',
      );
    }
    return RegistrationVerificationChallenge(
      verificationId: id,
      retryAfter: _intValue(response['retry_after']),
      expiresIn: _intValue(response['expires_in']),
    );
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
    required String verificationId,
  }) async {
    await _apiClient.post(
      '/api/mobile/register/email/verify',
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'verification_id': verificationId,
      },
    );
  }

  @override
  Future<List<RegistrationPartner>> logisticsPartners(String cityCode) async {
    final response = _asMap(
      await _apiClient.get(
        '/api/mobile/register/logistics-partners',
        queryParameters: {'city_code': cityCode},
      ),
    );
    final items = response['data'];
    if (items is! List) {
      throw const FormatException('Invalid Logistics directory response.');
    }
    return items.map(RegistrationPartner.fromJson).toList(growable: false);
  }

  @override
  Future<RegistrationOutcome> registerBuyer(Map<String, Object?> fields) async {
    return RegistrationOutcome.fromJson(
      await _apiClient.post('/api/mobile/register/buyer', body: fields),
    );
  }

  @override
  Future<RegistrationOutcome> registerRider({
    required Map<String, String> fields,
    required List<ApiMultipartFile> documents,
  }) async {
    return RegistrationOutcome.fromJson(
      await _apiClient.postMultipartFiles(
        '/api/mobile/register/rider',
        fields: fields,
        files: documents,
      ),
    );
  }

  @override
  Future<RegistrationOutcome> registerLogistics({
    required Map<String, String> fields,
    required List<ApiMultipartFile> documents,
  }) async {
    return RegistrationOutcome.fromJson(
      await _apiClient.postMultipartFiles(
        '/api/mobile/register/logistics',
        fields: fields,
        files: documents,
      ),
    );
  }

  static Map _asMap(Object? value) {
    if (value is Map) return value;
    throw const FormatException('Bearly returned an unreadable response.');
  }

  static int _intValue(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
}
