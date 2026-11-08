import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_location_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads map data and posts the authenticated device fix', () async {
    final requests = <http.Request>[];
    final repository = RiderLocationRepository(
      authService: _authService((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': _mapData()}), 200);
        }
        return http.Response(
          jsonEncode({'data': _location(sharing: true)}),
          200,
        );
      }),
    );

    final map = await repository.loadMapData();
    final fix = await repository.updateLocation(
      latitude: 14.3121,
      longitude: 121.1112,
      accuracyMeters: 8.5,
    );

    expect(map.workType, 'local');
    expect(map.destinations.single.kind, 'pickup');
    expect(map.destinations.single.latitude, 14.3121);
    expect(map.providerConfigured, isFalse);
    expect(fix.sharing, isTrue);
    expect(fix.accuracyMeters, 8.5);
    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'GET /api/mobile/rider/map',
      'POST /api/mobile/rider/location',
    ]);
    expect(jsonDecode(requests.last.body), {
      'latitude': 14.3121,
      'longitude': 121.1112,
      'accuracy_meters': 8.5,
    });
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer rider-token',
      ),
      isTrue,
    );
  });

  test('stops sharing through authenticated delete', () async {
    late http.Request request;
    final repository = RiderLocationRepository(
      authService: _authService((value) async {
        request = value;
        return http.Response(
          jsonEncode({
            'data': {'sharing': false},
          }),
          200,
        );
      }),
    );

    await repository.stopSharing();

    expect(request.method, 'DELETE');
    expect(request.url.path, '/api/mobile/rider/location');
    expect(request.headers['authorization'], 'Bearer rider-token');
  });

  test('Courier map data retains only its line-haul destination', () async {
    final repository = RiderLocationRepository(
      authService: _authService((request) async {
        return http.Response(
          jsonEncode({
            'data': {
              ..._mapData(),
              'work_type': 'courier',
              'destinations': [
                {
                  'id': '12',
                  'kind': 'linehaul_destination',
                  'title': 'Line-haul destination',
                  'reference': 'LHR-12',
                  'address': 'Destination sorting center',
                  'status': 'departed',
                  'latitude': 14.6,
                  'longitude': 121.0,
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final map = await repository.loadMapData();

    expect(map.workType, 'courier');
    expect(map.destinations.single.kind, 'linehaul_destination');
    expect(map.destinations.single.reference, 'LHR-12');
  });
}

Map<String, Object?> _mapData() => {
  'work_type': 'local',
  'current_location': _location(sharing: false),
  'destinations': [
    {
      'id': 'PU-100',
      'kind': 'pickup',
      'title': 'Store pickup',
      'address': 'Santa Rosa, Laguna',
      'status': 'Assigned',
      'latitude': 14.3121,
      'longitude': 121.1112,
    },
  ],
  'map': {
    'tile_url': null,
    'attribution': 'OpenStreetMap contributors',
    'provider_configured': false,
  },
  'stale_after_seconds': 180,
};

Map<String, Object?> _location({required bool sharing}) => {
  'sharing': sharing,
  'latitude': sharing ? 14.3121 : null,
  'longitude': sharing ? 121.1112 : null,
  'accuracy_meters': sharing ? 8.5 : null,
  'last_seen_at': sharing ? '2026-11-08T08:00:00Z' : null,
  'freshness_state': sharing ? 'fresh' : 'missing',
  'gps_quality': sharing ? 'usable' : 'unknown',
  'max_usable_accuracy_meters': 100,
};

AuthService _authService(Future<http.Response> Function(http.Request) handler) {
  final service = AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('http://127.0.0.1:8000'),
    ),
    tokenStore: _MemoryTokenStore()..token = 'rider-token',
  );
  service.currentSession = const AuthSession(
    id: 1,
    name: 'Rider One',
    email: 'rider@example.test',
    role: AccountRole.rider,
  );
  return service;
}

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
