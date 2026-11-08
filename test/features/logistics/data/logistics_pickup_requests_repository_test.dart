import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'loads provider pickup requests with server status and page filters',
    () async {
      http.Request? received;
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          received = request;
          return http.Response(jsonEncode(_listResponse), 200);
        }),
      );

      final page = await repository.pickupRequests(
        status: 'verified',
        page: 2,
        perPage: 10,
      );

      expect(received!.url.path, '/api/mobile/logistics/pickup-requests');
      expect(received!.url.queryParameters, {
        'page': '2',
        'per_page': '10',
        'status': 'verified',
      });
      expect(received!.headers['authorization'], 'Bearer logistics-test-token');
      expect(page.currentPage, 2);
      expect(page.lastPage, 4);
      expect(page.total, 37);
      expect(page.hasMore, isTrue);
      expect(page.requests.single.reference, 'PU-2026-001');
      expect(page.requests.single.statusLabel, 'Verified');
      expect(page.requests.single.sellerOrderReferences, ['SO-100']);
    },
  );

  test(
    'loads scoped pickup details and parses history and candidates',
    () async {
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          expect(request.url.path, '/api/mobile/logistics/pickup-requests/42');
          return http.Response(jsonEncode(_detailResponse), 200);
        }),
      );

      final pickup = await repository.pickupRequest(42);

      expect(pickup.isReturnPickup, isFalse);
      expect(pickup.pickupLocation, '12 Seller Street, San Roque, Sample City');
      expect(pickup.assignedRider!.name, 'Local Rider');
      expect(pickup.parcels.single.waybill, 'WB-100');
      expect(pickup.eligibleRiderCandidates.single.recommended, isTrue);
      expect(pickup.history.map((event) => event.event), [
        'submitted',
        'verified',
      ]);
    },
  );

  test(
    'sends verify, reject, assign and replacement actions to scoped routes',
    () async {
      final requests = <http.Request>[];
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_detailResponse), 200);
        }),
      );

      await repository.verifyPickupRequest(42);
      await repository.rejectPickupRequest(
        42,
        reason: '  Missing parcel labels.  ',
      );
      await repository.assignPickupRequest(
        42,
        riderProfileId: 18,
        notes: '  Call on arrival.  ',
      );
      await repository.replacePickupRequestRider(
        42,
        riderProfileId: 19,
        reason: '  Coverage changed today.  ',
      );

      expect(requests.map((request) => request.method), everyElement('POST'));
      expect(requests.map((request) => request.url.path), [
        '/api/mobile/logistics/pickup-requests/42/verify',
        '/api/mobile/logistics/pickup-requests/42/reject',
        '/api/mobile/logistics/pickup-requests/42/assign',
        '/api/mobile/logistics/pickup-requests/42/replace-rider',
      ]);
      expect(jsonDecode(requests[0].body), isEmpty);
      expect(jsonDecode(requests[1].body), {
        'cancellation_reason': 'Missing parcel labels.',
      });
      expect(jsonDecode(requests[2].body), {
        'rider_profile_id': 18,
        'notes': 'Call on arrival.',
      });
      expect(jsonDecode(requests[3].body), {
        'rider_profile_id': 19,
        'reason': 'Coverage changed today.',
      });
    },
  );
}

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

final _listResponse = {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'pickup_requests': [_pickupJson],
  },
  'meta': {'current_page': 2, 'last_page': 4, 'per_page': 10, 'total': 37},
};

final _detailResponse = {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'pickup_request': _pickupJson,
  },
};

final _pickupJson = {
  'id': 42,
  'reference': 'PU-2026-001',
  'status': 'verified',
  'status_label': 'Verified',
  'pickup_type': 'outbound',
  'store': {'name': 'Sample Store'},
  'seller_order_references': ['SO-100'],
  'parcel_count': 1,
  'total_weight_kg': 1.25,
  'pickup_location': '12 Seller Street, San Roque, Sample City',
  'requested_date': '2026-11-08',
  'window_start': '2026-11-08T09:00:00Z',
  'window_end': '2026-11-08T11:00:00Z',
  'created_at': '2026-11-07T12:00:00Z',
  'verified_at': '2026-11-07T13:00:00Z',
  'assigned_rider': {
    'profile_id': 17,
    'name': 'Local Rider',
    'assignment_status': 'assigned',
    'assigned_at': '2026-11-07T13:30:00Z',
  },
  'seller_instructions': 'Use the loading bay.',
  'rejection_reason': null,
  'parcels': [
    {
      'reference': 'P-100',
      'piece_number': 1,
      'status': 'ready_for_pickup',
      'weight_kg': 1.25,
      'waybill': 'WB-100',
      'shipment': {
        'reference': 'SHIP-100',
        'seller_order_references': ['SO-100'],
      },
    },
  ],
  'eligible_rider_candidates': [
    {
      'profile_id': 18,
      'name': 'Recommended Rider',
      'vehicle': 'Motorcycle',
      'service_area': 'North Zone',
      'active_jobs': 1,
      'recommended': true,
      'recommendation_reason': 'Recommended · same service area',
      'distance_label': '2.0 km away',
    },
  ],
  'history': [
    {
      'event': 'submitted',
      'label': 'Request submitted',
      'occurred_at': '2026-11-07T12:00:00Z',
      'detail': null,
    },
    {
      'event': 'verified',
      'label': 'Request verified',
      'occurred_at': '2026-11-07T13:00:00Z',
      'detail': null,
    },
  ],
};
