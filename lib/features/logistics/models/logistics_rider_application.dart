class LogisticsRiderApplication {
  const LogisticsRiderApplication({
    required this.id,
    required this.applicationNumber,
    required this.status,
    required this.statusLabel,
    required this.requestedWorkType,
    required this.requestedWorkTypeLabel,
    required this.submittedAt,
    required this.reviewStartedAt,
    required this.decidedAt,
    required this.decisionReason,
    required this.revisionNotes,
    required this.accountStatus,
    required this.canReviewDocuments,
    required this.canDecide,
    required this.ownershipConsistent,
    required this.vehicle,
    required this.vehicleModel,
    required this.plateNumber,
    required this.documentCount,
    required this.applicant,
    required this.documents,
  });

  final int id;
  final String applicationNumber;
  final String status;
  final String statusLabel;
  final String requestedWorkType;
  final String requestedWorkTypeLabel;
  final DateTime? submittedAt;
  final DateTime? reviewStartedAt;
  final DateTime? decidedAt;
  final String? decisionReason;
  final String? revisionNotes;
  final String? accountStatus;
  final bool canReviewDocuments;
  final bool canDecide;
  final bool ownershipConsistent;
  final String? vehicle;
  final String? vehicleModel;
  final String? plateNumber;
  final int documentCount;
  final LogisticsRiderApplicant applicant;
  final List<LogisticsRiderApplicationDocument> documents;

  bool get isCourier => requestedWorkType == 'courier';

  bool get requiredDocumentsVerified {
    const required = {'driver_license', 'or_cr'};
    final statuses = {
      for (final document in documents) document.type: document.status,
    };
    return required.every((type) => statuses[type] == 'verified');
  }

  factory LogisticsRiderApplication.fromListEntry(Object? response) {
    final data = _asMap(response);
    final applicant = _asMap(data['applicant']);
    return LogisticsRiderApplication(
      id: _asInt(data['id']),
      applicationNumber: _asString(data['application_no']),
      status: _asString(data['status']),
      statusLabel: _asString(data['status_label']),
      requestedWorkType: _asString(data['requested_work_type']),
      requestedWorkTypeLabel: _asString(data['requested_work_type_label']),
      submittedAt: _asDate(data['submitted_at']),
      reviewStartedAt: _asDate(data['review_started_at']),
      decidedAt: _asDate(data['decided_at']),
      decisionReason: _optionalString(data['decision_reason']),
      revisionNotes: _optionalString(data['revision_notes']),
      accountStatus: _optionalString(data['account_status']),
      canReviewDocuments: data['can_review_documents'] == true,
      canDecide: data['can_decide'] == true,
      ownershipConsistent: data['ownership_consistent'] == true,
      vehicle: _optionalString(data['vehicle']),
      vehicleModel: _optionalString(data['vehicle_model']),
      plateNumber: _optionalString(data['plate_number']),
      documentCount: _asInt(data['document_count']),
      applicant: LogisticsRiderApplicant.fromMap(applicant),
      documents: _asDocuments(data['documents']),
    );
  }

  factory LogisticsRiderApplication.fromResponse(Object? response) {
    final payload = _asMap(response);
    final data = _asMap(payload['data']);
    return LogisticsRiderApplication.fromListEntry(data['application']);
  }

  static List<LogisticsRiderApplication> listFromResponse(Object? response) {
    final payload = _asMap(response);
    final data = _asMap(payload['data']);
    final items = data['applications'];
    if (items is! List) {
      throw const FormatException('Missing Rider applications.');
    }
    return List.unmodifiable(
      items.map(LogisticsRiderApplication.fromListEntry),
    );
  }
}

class LogisticsRiderApplicant {
  const LogisticsRiderApplicant({
    required this.name,
    required this.email,
    required this.phone,
    required this.birthday,
    required this.sex,
    required this.area,
    required this.street,
    required this.barangay,
    required this.cityMunicipality,
    required this.province,
    required this.postalCode,
  });

  final String name;
  final String? email;
  final String? phone;
  final DateTime? birthday;
  final String? sex;
  final String? area;
  final String? street;
  final String? barangay;
  final String? cityMunicipality;
  final String? province;
  final String? postalCode;

  String get formattedAddress => [
    street,
    barangay,
    cityMunicipality,
    province,
    postalCode,
  ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  factory LogisticsRiderApplicant.fromMap(Map<Object?, Object?> data) {
    final address = data['address'] is Map
        ? _asMap(data['address'])
        : const <Object?, Object?>{};
    return LogisticsRiderApplicant(
      name: _asString(data['name']),
      email: _optionalString(data['email']),
      phone: _optionalString(data['phone']),
      birthday: _asDate(data['birthday']),
      sex: _optionalString(data['sex']),
      area: _optionalString(data['area']),
      street: _optionalString(address['street']),
      barangay: _optionalString(address['barangay']),
      cityMunicipality: _optionalString(address['city_municipality']),
      province: _optionalString(address['province']),
      postalCode: _optionalString(address['postal_code']),
    );
  }
}

class LogisticsRiderApplicationDocument {
  const LogisticsRiderApplicationDocument({
    required this.id,
    required this.type,
    required this.label,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.status,
    required this.rejectionReason,
    required this.verifiedAt,
    required this.fileUrl,
  });

  final int id;
  final String type;
  final String label;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String status;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final String fileUrl;

  factory LogisticsRiderApplicationDocument.fromMap(
    Map<Object?, Object?> data,
  ) => LogisticsRiderApplicationDocument(
    id: _asInt(data['id']),
    type: _asString(data['type']),
    label: _asString(data['label']),
    filename: _asString(data['filename']),
    mimeType: _asString(data['mime_type']),
    sizeBytes: _asInt(data['size_bytes']),
    status: _asString(data['status']),
    rejectionReason: _optionalString(data['rejection_reason']),
    verifiedAt: _asDate(data['verified_at']),
    fileUrl: _asString(data['file_url']),
  );
}

class LogisticsRiderApplicationDocumentContent {
  const LogisticsRiderApplicationDocumentContent({
    required this.bytes,
    required this.mimeType,
  });

  final List<int> bytes;
  final String mimeType;
}

Map<Object?, Object?> _asMap(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  throw const FormatException('Invalid Rider application response.');
}

List<LogisticsRiderApplicationDocument> _asDocuments(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Invalid Rider application documents.');
  }
  return List.unmodifiable(
    value.map(
      (document) => LogisticsRiderApplicationDocument.fromMap(_asMap(document)),
    ),
  );
}

int _asInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

String _asString(Object? value) => value is String ? value.trim() : '';

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

DateTime? _asDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
