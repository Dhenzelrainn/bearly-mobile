import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads the provider roster and Courier-specific capacity', () async {
    final requests = <String>[];
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        requests.add(request.url.path);
        return http.Response(jsonEncode(_roster), 200);
      }),
    );

    final riders = await repository.riders();

    expect(requests, ['/api/mobile/logistics/riders']);
    expect(riders, hasLength(2));
    expect(riders.first.name, 'Local Rider');
    expect(riders.first.capacity, 8);
    expect(riders.first.isCourier, isFalse);
    expect(riders.last.name, 'Courier Driver');
    expect(riders.last.capacity, 24);
    expect(riders.last.capacityLabel, 'Line-haul parcels');
    expect(riders.last.isCourier, isTrue);
  });

  test('loads a provider-owned Rider details record by user id', () async {
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        expect(request.url.path, '/api/mobile/logistics/riders/31');
        return http.Response(
          jsonEncode({
            'data': {
              'provider': {'id': 3, 'name': 'North Logistics'},
              'rider': _rider(31, 'Local Rider'),
            },
          }),
          200,
        );
      }),
    );

    final rider = await repository.rider(31);

    expect(rider.userId, 31);
    expect(rider.workType, 'local');
    expect(rider.verificationStatus, 'approved');
    expect(rider.activeJobs, 2);
  });

  test('sends capacity edits to the provider-scoped Mobile API', () async {
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/mobile/logistics/riders/31/capacity');
        expect(jsonDecode(request.body), {'parcel_capacity': 14});
        return http.Response(jsonEncode(_detailResponse(capacity: 14)), 200);
      }),
    );

    final rider = await repository.updateRiderCapacity(
      userId: 31,
      parcelCapacity: 14,
    );

    expect(rider.capacity, 14);
  });

  test('sends specialization and audit reason separately', () async {
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        expect(request.method, 'PATCH');
        expect(
          request.url.path,
          '/api/mobile/logistics/riders/31/specialization',
        );
        expect(jsonDecode(request.body), {
          'specialization': 'pickup_only',
          'reason': 'Coverage plan changed',
        });
        return http.Response(
          jsonEncode(_detailResponse(specialization: 'pickup_only')),
          200,
        );
      }),
    );

    final rider = await repository.updateRiderSpecialization(
      userId: 31,
      specialization: 'pickup_only',
      reason: 'Coverage plan changed',
    );

    expect(rider.specialization, 'pickup_only');
  });

  test('refreshes home-area assignment without sending a zone id', () async {
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/mobile/logistics/riders/31/assignment');
        expect(request.body, isEmpty);
        return http.Response(
          jsonEncode(_detailResponse(zone: 'North Zone')),
          200,
        );
      }),
    );

    final rider = await repository.refreshRiderAssignment(userId: 31);

    expect(rider.currentZone, 'North Zone');
  });

  test('lists applications from the authenticated provider endpoint', () async {
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/mobile/logistics/rider-applications');
        return http.Response(jsonEncode(_applications), 200);
      }),
    );

    final applications = await repository.riderApplications();

    expect(applications, hasLength(1));
    expect(applications.single.applicant.name, 'Rider Applicant');
    expect(applications.single.requestedWorkType, 'courier');
    expect(applications.single.documents.single.filename, 'license.pdf');
  });

  test(
    'loads application details and downloads documents with session auth',
    () async {
      final requests = <http.Request>[];
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/documents/11')) {
            return http.Response.bytes(
              [137, 80, 78, 71],
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          expect(
            request.url.path,
            '/api/mobile/logistics/rider-applications/91',
          );
          return http.Response(jsonEncode(_applicationDetail), 200);
        }),
      );

      final application = await repository.riderApplication(91);
      final document = await repository.downloadRiderApplicationDocument(
        applicationId: 91,
        documentId: 11,
      );

      expect(application.id, 91);
      expect(application.canDecide, isTrue);
      expect(
        requests.last.url.path,
        '/api/mobile/logistics/rider-applications/91/documents/11',
      );
      expect(
        requests.last.headers['authorization'],
        'Bearer logistics-test-token',
      );
      expect(document.mimeType, 'image/png');
      expect(document.bytes, [137, 80, 78, 71]);
    },
  );

  test(
    'sends document decisions and application decisions to scoped APIs',
    () async {
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          final path = request.url.path;
          if (path.endsWith('/documents/11')) {
            expect(request.method, 'PATCH');
            expect(jsonDecode(request.body), {
              'verification_status': 'rejected',
              'rejection_reason': 'Unreadable scan',
            });
          } else if (path.endsWith('/approve')) {
            expect(request.method, 'POST');
            expect(jsonDecode(request.body), {'linehaul_capacity': 40});
          } else {
            expect(path, '/api/mobile/logistics/rider-applications/91/reject');
            expect(request.method, 'POST');
            expect(jsonDecode(request.body), {'reason': 'Missing documents'});
          }
          return http.Response(jsonEncode(_applicationDetail), 200);
        }),
      );

      await repository.reviewRiderApplicationDocument(
        applicationId: 91,
        documentId: 11,
        verificationStatus: 'rejected',
        rejectionReason: 'Unreadable scan',
      );
      await repository.approveRiderApplication(
        applicationId: 91,
        linehaulCapacity: 40,
      );
      await repository.rejectRiderApplication(
        applicationId: 91,
        reason: 'Missing documents',
      );
    },
  );
}

Map<String, Object?> _detailResponse({
  int capacity = 8,
  String specialization = 'both',
  String? zone,
}) => {
  'message': 'Updated',
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'rider': {
      ..._rider(31, 'Local Rider'),
      'capacity': capacity,
      'specialization': specialization,
      'specialization_label': specialization == 'pickup_only'
          ? 'Pickup only'
          : 'Pickup and delivery',
      'current_zone': zone,
      'current_zone_id': zone == null ? null : 7,
      'home_sorting_center_id': 4,
      'application_status': 'approved',
    },
  },
};

Map<String, Object?> _rider(int id, String name, {String workType = 'local'}) =>
    {
      'id': id,
      'user_id': id,
      'profile_id': id + 100,
      'name': name,
      'work_type': workType,
      'work_type_label': workType == 'courier' ? 'Courier' : 'Local Rider',
      'account_status': 'active',
      'verification_status': 'approved',
      'availability_status': 'available',
      'operational_status': 'available',
      'vehicle_type': workType == 'courier' ? 'Van' : 'Motorcycle',
      'vehicle_model': 'Cargo',
      'plate_number': 'ABC-1234',
      'capacity': workType == 'courier' ? 24 : 8,
      'capacity_label': workType == 'courier'
          ? 'Line-haul parcels'
          : 'Local parcels',
      'active_jobs': 2,
      'completed_today': 1,
    };

final _roster = {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'riders': [
      _rider(31, 'Local Rider'),
      _rider(32, 'Courier Driver', workType: 'courier'),
    ],
  },
};

final _applications = {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'applications': [
      {
        'id': 91,
        'application_no': 'RIDER-91',
        'status': 'submitted',
        'status_label': 'Pending',
        'requested_work_type': 'courier',
        'requested_work_type_label': 'Courier',
        'submitted_at': null,
        'review_started_at': null,
        'decided_at': null,
        'decision_reason': null,
        'revision_notes': null,
        'account_status': 'pending',
        'can_review_documents': true,
        'can_decide': true,
        'ownership_consistent': true,
        'vehicle': 'Van',
        'vehicle_model': 'Cargo Van',
        'plate_number': 'ABC-1234',
        'document_count': 1,
        'applicant': {'name': 'Rider Applicant', 'area': 'North Zone'},
        'documents': [
          {
            'id': 11,
            'type': 'driver_license',
            'label': 'Driver License',
            'filename': 'license.pdf',
            'mime_type': 'application/pdf',
            'size_bytes': 50,
            'status': 'pending',
            'rejection_reason': null,
            'verified_at': null,
            'file_url': '/private/11',
          },
        ],
      },
    ],
  },
};

final _applicationDetail = {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'application': {
      'id': 91,
      'application_no': 'RIDER-91',
      'status': 'submitted',
      'status_label': 'Pending',
      'requested_work_type': 'courier',
      'requested_work_type_label': 'Courier',
      'submitted_at': null,
      'review_started_at': null,
      'decided_at': null,
      'decision_reason': null,
      'revision_notes': null,
      'account_status': 'pending',
      'can_review_documents': true,
      'can_decide': true,
      'ownership_consistent': true,
      'vehicle': 'Van',
      'vehicle_model': 'Cargo Van',
      'plate_number': 'ABC-1234',
      'document_count': 1,
      'applicant': {
        'name': 'Rider Applicant',
        'email': 'rider@example.test',
        'phone': '09170000000',
        'birthday': null,
        'sex': null,
        'address': {
          'street': null,
          'barangay': null,
          'city_municipality': null,
          'province': null,
          'postal_code': null,
        },
      },
      'documents': [
        {
          'id': 11,
          'type': 'driver_license',
          'label': 'Driver License',
          'filename': 'license.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 50,
          'status': 'pending',
          'rejection_reason': null,
          'verified_at': null,
          'file_url': '/private/11',
        },
      ],
    },
  },
};

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'logistics-test-token',
      )
      ..currentSession = const AuthSession(
        id: 19,
        name: 'Logistics Operator',
        email: 'operator@example.test',
        role: AccountRole.logistics,
      );

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
