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
    'requests filtered, paginated incoming handoffs and parses eligibility',
    () async {
      late http.Request request;
      final repository = LogisticsRepository(
        authService: _auth((value) async {
          request = value;
          return http.Response(jsonEncode(_handoffResponse), 200);
        }),
      );

      final page = await repository.cityHandoffs(
        view: 'incoming',
        status: 'sent',
        search: 'BRLY-CITY',
        page: 2,
        perPage: 10,
      );

      expect(request.method, 'GET');
      expect(request.url.path, '/api/mobile/logistics/city-handoffs');
      expect(request.url.queryParameters, {
        'view': 'incoming',
        'status': 'sent',
        'search': 'BRLY-CITY',
        'page': '2',
        'per_page': '10',
      });
      expect(page.providerName, 'Destination Logistics');
      expect(page.activeCenterName, 'Destination SC');
      expect(page.items.single.waybill, 'BRLY-CITY-001');
      expect(page.items.single.origin.providerName, 'Origin Logistics');
      expect(page.items.single.parcels.single.reference, 'PCL-CITY-001');
      expect(page.items.single.acceptanceEligibility?.eligible, false);
      expect(
        page.items.single.acceptanceEligibility?.code,
        'courier_not_arrived',
      );
      expect(page.items.single.run?.courierName, 'Courier One');
      expect(page.items.single.history.single.event, 'departed');
      expect(page.pagination.currentPage, 2);
      expect(page.pagination.hasPrevious, true);
      expect(page.pagination.hasNext, true);
    },
  );

  test(
    'parses provider-scoped run manifests and verified courier options',
    () async {
      final repository = LogisticsRepository(
        authService: _auth(
          (request) async => http.Response(jsonEncode(_runResponse), 200),
        ),
      );

      final page = await repository.cityHandoffs(
        view: 'runs',
        status: 'active',
      );

      expect(page.runs.single.runNo, 'LHR-001');
      expect(page.runs.single.courier.workType, 'courier');
      expect(page.runs.single.shipments.single.waybill, 'BRLY-CITY-001');
      expect(
        page.runs.single.shipments.single.parcels.single.reference,
        'PCL-CITY-001',
      );
      expect(page.pagination.total, 1);
    },
  );

  test(
    'rejects invalid City Handoffs filters before making a request',
    () async {
      final repository = LogisticsRepository(
        authService: _auth((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        repository.cityHandoffs(view: 'runs', status: 'sent'),
        throwsArgumentError,
      );
      await expectLater(
        repository.cityHandoffs(perPage: 51),
        throwsArgumentError,
      );
    },
  );
}

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://bearly.test'),
        ),
        tokenStore: _TokenStore()..token = 'city-handoffs-token',
      )
      ..currentSession = const AuthSession(
        id: 1,
        name: 'City Handoff Logistics',
        email: 'handoffs@example.test',
        role: AccountRole.logistics,
      );

class _TokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> clear() async {}

  @override
  Future<void> write(String value) async => token = value;
}

Map<String, Object?> get _handoffResponse => {
  'data': {
    'provider': {'id': 2, 'name': 'Destination Logistics'},
    'active_sorting_center': {
      'id': 2,
      'name': 'Destination SC',
      'code': 'SC-D',
    },
    'view': 'incoming',
    'items': [
      {
        'id': 1,
        'direction': 'incoming',
        'status': 'sent',
        'stage': 'departed',
        'waybill': 'BRLY-CITY-001',
        'shipment': {
          'reference': 'SHP-CITY-001',
          'status': 'handoff_pending',
          'purpose': 'outbound',
        },
        'origin': {
          'provider': {'id': 1, 'name': 'Origin Logistics'},
          'sorting_center': {'id': 1, 'name': 'Origin SC', 'code': 'SC-O'},
        },
        'destination': {
          'provider': {'id': 2, 'name': 'Destination Logistics'},
          'sorting_center': null,
        },
        'parcel_count': 1,
        'parcels': [
          {
            'reference': 'PCL-CITY-001',
            'status': 'in_transit',
            'current_sorting_center': null,
          },
        ],
        'run': {
          'id': 1,
          'run_no': 'LHR-001',
          'status': 'departed',
          'assigned_at': '2026-11-09T00:00:00Z',
          'loaded_at': '2026-11-09T00:10:00Z',
          'departed_at': '2026-11-09T00:20:00Z',
          'arrived_at': null,
          'courier': {
            'id': 3,
            'name': 'Courier One',
            'work_type': 'courier',
            'vehicle_type': 'Van',
            'parcel_capacity': 10,
          },
        },
        'acceptance_eligibility': {
          'eligible': false,
          'code': 'courier_not_arrived',
          'message': 'Wait until the assigned Courier run is marked Arrived.',
        },
        'sent_at': '2026-11-09T00:20:00Z',
        'accepted_at': null,
        'history': [
          {
            'event': 'departed',
            'from_status': 'loaded',
            'to_status': 'departed',
            'occurred_at': '2026-11-09T00:20:00Z',
            'actor': 'Courier One',
          },
        ],
      },
    ],
    'available_couriers': [],
    'filters': {'status': 'sent', 'search': 'BRLY-CITY'},
    'pagination': {
      'current_page': 2,
      'last_page': 3,
      'per_page': 10,
      'total': 21,
    },
  },
};

Map<String, Object?> get _runResponse => {
  'data': {
    'provider': {'id': 1, 'name': 'Origin Logistics'},
    'active_sorting_center': {'id': 1, 'name': 'Origin SC', 'code': 'SC-O'},
    'view': 'runs',
    'items': [
      {
        'id': 1,
        'run_no': 'LHR-001',
        'status': 'departed',
        'status_label': 'Departed',
        'origin': {
          'provider': {'id': 1, 'name': 'Origin Logistics'},
          'sorting_center': {'id': 1, 'name': 'Origin SC', 'code': 'SC-O'},
        },
        'destination': {
          'provider': {'id': 2, 'name': 'Destination Logistics'},
        },
        'courier': {
          'id': 3,
          'name': 'Courier One',
          'work_type': 'courier',
          'vehicle_type': 'Van',
          'parcel_capacity': 10,
        },
        'manifest': {
          'shipment_count': 1,
          'parcel_count': 1,
          'shipments': [
            {
              'reference': 'SHP-CITY-001',
              'waybill': 'BRLY-CITY-001',
              'status': 'handoff_pending',
              'purpose': 'outbound',
              'handoff_status': 'sent',
              'parcel_count': 1,
              'parcels': [
                {'reference': 'PCL-CITY-001', 'status': 'in_transit'},
              ],
            },
          ],
        },
        'assigned_at': '2026-11-09T00:00:00Z',
        'loaded_at': '2026-11-09T00:10:00Z',
        'departed_at': '2026-11-09T00:20:00Z',
        'arrived_at': null,
        'completed_at': null,
        'history': [],
      },
    ],
    'available_couriers': [],
    'filters': {'status': 'active', 'search': null},
    'pagination': {
      'current_page': 1,
      'last_page': 1,
      'per_page': 20,
      'total': 1,
    },
  },
};
