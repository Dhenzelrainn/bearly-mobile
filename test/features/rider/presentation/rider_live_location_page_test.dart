import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_device_location.dart';
import 'package:bearly_mobile/features/rider/data/rider_location_repository.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_live_location_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('granted foreground permission starts and stops sharing', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final repository = RiderLocationRepository(
      authService: _authService((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': _mapData()}), 200);
        }
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'data': _location(sharing: true)}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {'sharing': false},
          }),
          200,
        );
      }),
    );
    final device = _FakeDeviceLocation();

    await tester.pumpWidget(
      MaterialApp(
        home: RiderLiveLocationPage(
          repository: repository,
          deviceLocation: device,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Assigned destinations'), findsOneWidget);
    expect(find.text('Store pickup'), findsOneWidget);
    expect(find.textContaining('not configured in Laravel'), findsOneWidget);
    expect(find.textContaining('Santa Rosa, Laguna'), findsOneWidget);

    await tester.tap(find.text('Start Sharing'));
    await tester.pumpAndSettle();
    expect(device.requestCount, 1);
    expect(find.text('Sharing live location'), findsOneWidget);
    expect(find.textContaining('GPS accuracy ±9 m'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));

    final stopButton = find.ancestor(
      of: find.text('Stop Sharing'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(stopButton, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(stopButton).onPressed, isNotNull);
    await tester.ensureVisible(stopButton);
    await tester.tap(stopButton);
    await tester.pumpAndSettle();
    expect(
      requests.where((request) => request.method == 'DELETE'),
      hasLength(1),
    );
    expect(find.text('Start Sharing'), findsOneWidget);
  });

  testWidgets('denied device permission shows guidance and sends no location', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final repository = RiderLocationRepository(
      authService: _authService((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': _mapData()}), 200);
        }
        return http.Response('{}', 200);
      }),
    );
    final device = _FakeDeviceLocation(
      error: const RiderDeviceLocationException(
        'Location permission was denied.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RiderLiveLocationPage(
          repository: repository,
          deviceLocation: device,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Sharing'));
    await tester.pumpAndSettle();

    expect(find.text('Location permission was denied.'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('disabled GPS shows location settings guidance', (tester) async {
    final requests = <http.Request>[];
    final repository = RiderLocationRepository(
      authService: _authService((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': _mapData()}), 200);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RiderLiveLocationPage(
          repository: repository,
          deviceLocation: _FakeDeviceLocation(
            error: const RiderDeviceLocationException(
              'Turn on Location Services on your device, then try again.',
              action: RiderLocationSettingsAction.location,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Sharing'));
    await tester.pumpAndSettle();

    expect(
      find.text('Turn on Location Services on your device, then try again.'),
      findsOneWidget,
    );
    expect(find.text('Open location settings'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('shows stale server location without reporting it as live', (
    tester,
  ) async {
    final mapData = _mapData();
    mapData['current_location'] = {
      ..._location(sharing: true),
      'freshness_state': 'stale',
      'sharing': false,
    };
    final repository = RiderLocationRepository(
      authService: _authService((request) async {
        return http.Response(jsonEncode({'data': mapData}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RiderLiveLocationPage(
          repository: repository,
          deviceLocation: _FakeDeviceLocation(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last shared location is stale'), findsOneWidget);
    expect(find.text('Start Sharing'), findsOneWidget);
  });

  testWidgets('server rejection displays the existing availability rule', (
    tester,
  ) async {
    final methods = <String>[];
    final repository = RiderLocationRepository(
      authService: _authService((request) async {
        methods.add(request.method);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': _mapData()}), 200);
        }
        if (request.method == 'DELETE') {
          return http.Response(
            jsonEncode({
              'data': {'sharing': false},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'message':
                'Set your Rider availability to Available before sharing your location.',
          }),
          409,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RiderLiveLocationPage(
          repository: repository,
          deviceLocation: _FakeDeviceLocation(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Sharing'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Set your Rider availability to Available before sharing your location.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start Sharing'), findsOneWidget);
    expect(methods, containsAllInOrder(['GET', 'POST', 'DELETE']));
  });

  testWidgets(
    'backgrounding stops location reporting and clears the server fix',
    (tester) async {
      final methods = <String>[];
      final repository = RiderLocationRepository(
        authService: _authService((request) async {
          methods.add(request.method);
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'data': _mapData()}), 200);
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'data': _location(sharing: true)}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {'sharing': false},
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RiderLiveLocationPage(
            repository: repository,
            deviceLocation: _FakeDeviceLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Sharing live location'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(methods, containsAllInOrder(['GET', 'POST', 'DELETE']));
      expect(find.text('Start Sharing'), findsOneWidget);
    },
  );

  testWidgets(
    'Courier map labels line-haul destination without local actions',
    (tester) async {
      final repository = RiderLocationRepository(
        authService: _authService((request) async {
          return http.Response(
            jsonEncode({'data': _mapData(workType: 'courier')}),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RiderLiveLocationPage(
            repository: repository,
            deviceLocation: _FakeDeviceLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Line-haul destination'), findsOneWidget);
      expect(find.text('Pickup jobs'), findsNothing);
      expect(find.text('Delivery jobs'), findsNothing);
    },
  );
}

Map<String, Object?> _mapData({String workType = 'local'}) => {
  'work_type': workType,
  'current_location': _location(sharing: false),
  'destinations': [
    {
      'id': 'PU-100',
      'kind': workType == 'courier' ? 'linehaul_destination' : 'pickup',
      'title': workType == 'courier' ? 'Line-haul destination' : 'Store pickup',
      'reference': workType == 'courier' ? 'LHR-100' : '',
      'address': 'Santa Rosa, Laguna',
      'status': 'assigned',
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
  'accuracy_meters': sharing ? 9 : null,
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

class _FakeDeviceLocation implements RiderDeviceLocationSource {
  _FakeDeviceLocation({this.error});

  final RiderDeviceLocationException? error;
  int requestCount = 0;

  @override
  Future<RiderDevicePosition> requestForegroundPosition() async {
    requestCount++;
    if (error case final error?) throw error;
    return RiderDevicePosition(
      latitude: 14.3121,
      longitude: 121.1112,
      accuracyMeters: 9,
      timestamp: DateTime.utc(2026, 11, 8),
    );
  }

  @override
  Stream<RiderDevicePosition> watchForegroundPosition() => const Stream.empty();

  @override
  Future<void> openSettings(RiderLocationSettingsAction action) async {}
}
