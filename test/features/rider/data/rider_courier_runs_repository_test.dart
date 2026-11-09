import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'loads paginated run data using the shared Courier Mobile endpoint',
    () async {
      final requests = <http.Request>[];
      final repository = RiderRepository(
        authService: _authService((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_pagePayload()), 200);
        }),
      );

      final result = await repository.courierRuns(
        view: 'history',
        page: 2,
        perPage: 10,
      );

      expect(result.runs.single.runNo, 'LH-TEST-1');
      expect(result.runs.single.manifestCount, 1);
      expect(result.runs.single.parcelCount, 1);
      expect(result.currentPage, 2);
      expect(result.lastPage, 3);
      expect(result.hasMore, isTrue);
      expect(requests.single.url.path, '/api/mobile/rider/courier-runs');
      expect(requests.single.url.queryParameters, {
        'view': 'history',
        'page': '2',
        'per_page': '10',
      });
      expect(requests.single.headers['authorization'], 'Bearer courier-token');
    },
  );

  test(
    'loads run detail and posts only supported server action paths',
    () async {
      final requests = <http.Request>[];
      final repository = RiderRepository(
        authService: _authService((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'data': _runPayload()}), 200);
          }
          return http.Response(
            jsonEncode({
              'data': _runPayload(status: 'loading', next: 'loaded'),
            }),
            200,
          );
        }),
      );

      final detail = await repository.courierRunDetail(41);
      final updated = await repository.performCourierRunAction(
        41,
        'start_loading',
      );

      expect(detail.availableActions.single.key, 'start_loading');
      expect(updated.status, 'loading');
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'GET /api/mobile/rider/courier-runs/41',
          'POST /api/mobile/rider/courier-runs/41/start-loading',
        ],
      );
      expect(requests.last.body, isEmpty);
    },
  );

  test('does not send unknown run actions or invalid pagination', () async {
    var requested = false;
    final repository = RiderRepository(
      authService: _authService((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      repository.performCourierRunAction(41, 'accept_destination'),
      throwsArgumentError,
    );
    await expectLater(repository.courierRuns(perPage: 99), throwsArgumentError);
    expect(requested, isFalse);
  });
}

AuthService _authService(
  Future<http.Response> Function(http.Request) handler,
) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'courier-token',
      )
      ..currentSession = const AuthSession(
        id: 82,
        name: 'Courier Test',
        email: 'courier@example.test',
        role: AccountRole.rider,
      );

Map<String, Object?> _pagePayload() => {
  'data': [_runPayload()],
  'meta': {'current_page': 2, 'last_page': 3, 'total': 21},
};

Map<String, Object?> _runPayload({
  String status = 'assigned',
  String next = 'start_loading',
}) => {
  'id': 41,
  'run_no': 'LH-TEST-1',
  'status': status,
  'status_before_exception': null,
  'origin': {'provider': 'Origin Logistics', 'sorting_center': 'SC-A'},
  'destination': {'provider': 'Destination Logistics'},
  'assigned_at': '2026-11-09T08:00:00+08:00',
  'loaded_at': null,
  'departed_at': null,
  'arrived_at': null,
  'completed_at': null,
  'manifest': {
    'shipment_count': 1,
    'parcel_count': 1,
    'shipments': [
      {
        'shipment_no': 'SHP-TEST-1',
        'waybill_no': 'WB-TEST-1',
        'status': 'at_sorting_center',
        'parcels': [
          {
            'parcel_no': 'PARCEL-TEST-1',
            'status': 'received',
            'current_sorting_center': 'SC-A',
          },
        ],
      },
    ],
  },
  'events': [],
  'available_actions': [
    {
      'key': next,
      'label': next == 'loaded' ? 'Confirm all cargo loaded' : 'Start loading',
    },
  ],
};

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
