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
    'requests provider-scoped parcels with Web intake filters and paging',
    () async {
      final requests = <http.Request>[];
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_pageResponse), 200);
        }),
      );

      final page = await repository.incomingParcels(
        status: 'awaiting_intake',
        search: 'BRLY-L10',
        destination: 'San Pablo City',
        page: 2,
        perPage: 10,
      );

      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.path,
        '/api/mobile/logistics/incoming-parcels',
      );
      expect(requests.single.url.queryParameters, {
        'status': 'awaiting_intake',
        'search': 'BRLY-L10',
        'destination': 'San Pablo City',
        'page': '2',
        'per_page': '10',
      });
      expect(page.providerName, 'Victoria Logistics');
      expect(page.currentPage, 2);
      expect(page.lastPage, 4);
      expect(page.total, 38);
      expect(page.parcels.single.waybill, 'BRLY-L10-001');
      expect(page.parcels.single.expectedPieceCount, 3);
      expect(page.parcels.single.receivedPieceCount, 1);
      expect(page.parcels.single.remainingPieceCount, 2);
      expect(page.parcels.single.status, 'awaiting_intake');
    },
  );

  test('loads detail and provider-scoped parcel intake history', () async {
    final requests = <http.Request>[];
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_detailResponse), 200);
      }),
    );

    final parcel = await repository.incomingParcel('BRLY-L10 001');

    expect(requests.single.method, 'GET');
    expect(
      requests.single.url.path,
      '/api/mobile/logistics/incoming-parcels/BRLY-L10%20001',
    );
    expect(parcel.waybill, 'BRLY-L10-001');
    expect(parcel.pieces.single.parcel, 'PCL-L10-001');
    expect(parcel.pieces.single.currentSortingCenter?.code, 'SC-VIC-3');
    expect(
      parcel.pieces.single.intakeHistory.single.event,
      'received_at_center',
    );
    expect(parcel.pieces.single.intakeHistory.single.scanMethod, 'camera');
  });
}

const _pageResponse = {
  'data': {
    'provider': {'id': 3, 'name': 'Victoria Logistics'},
    'parcels': [
      {
        'waybill': 'BRLY-L10-001',
        'shipment_reference': 'SHP-L10-001',
        'shipment_status': 'picked_up',
        'purpose': 'outbound',
        'purpose_label': 'Buyer delivery',
        'status': 'awaiting_intake',
        'expected_piece_count': 3,
        'parcel_record_count': 3,
        'received_piece_count': 1,
        'remaining_piece_count': 2,
        'received_at': '2026-11-09T08:00:00Z',
        'seller': 'North Shop',
        'received_from': 'Rider A',
        'destination': 'San Pablo City, Laguna',
        'current_sorting_centers': [
          {
            'id': 3,
            'name': 'Victoria Center',
            'code': 'SC-VIC-3',
            'status': 'active',
          },
        ],
        'parcel_statuses': ['picked_up', 'received'],
      },
    ],
    'pagination': {
      'current_page': 2,
      'last_page': 4,
      'per_page': 10,
      'total': 38,
    },
    'filters': {
      'status': 'awaiting_intake',
      'search': 'BRLY-L10',
      'destination': 'San Pablo City',
    },
  },
};

const _detailResponse = {
  'data': {
    'parcel': {
      'waybill': 'BRLY-L10-001',
      'shipment_reference': 'SHP-L10-001',
      'shipment_status': 'at_sorting_center',
      'purpose': 'outbound',
      'purpose_label': 'Buyer delivery',
      'status': 'received',
      'expected_piece_count': 1,
      'parcel_record_count': 1,
      'received_piece_count': 1,
      'remaining_piece_count': 0,
      'received_at': '2026-11-09T08:00:00Z',
      'seller': 'North Shop',
      'received_from': 'Rider A',
      'destination': 'San Pablo City, Laguna',
      'current_sorting_centers': [
        {
          'id': 3,
          'name': 'Victoria Center',
          'code': 'SC-VIC-3',
          'status': 'active',
        },
      ],
      'parcel_statuses': ['received'],
    },
    'pieces': [
      {
        'parcel': 'PCL-L10-001',
        'piece_sequence': 1,
        'status': 'received',
        'weight_kg': '1.00',
        'size_class': 'small',
        'current_sorting_center': {
          'id': 3,
          'name': 'Victoria Center',
          'code': 'SC-VIC-3',
          'status': 'active',
        },
        'intake_history': [
          {
            'event': 'received_at_center',
            'from_status': 'picked_up',
            'to_status': 'received',
            'scan_method': 'camera',
            'occurred_at': '2026-11-09T08:00:00Z',
            'sorting_center': {'name': 'Victoria Center', 'code': 'SC-VIC-3'},
          },
        ],
      },
    ],
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
