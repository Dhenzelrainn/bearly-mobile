import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_city_handoffs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('filters remain usable at normal phone width', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      final view = request.url.queryParameters['view'] ?? 'incoming';
      return http.Response(
        jsonEncode(view == 'runs' ? _runPage() : _handoffPage(view: view)),
        200,
      );
    });

    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('logistics-city-handoffs-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('logistics-city-handoffs-status-incoming')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('logistics-city-handoffs-search')),
      findsOneWidget,
    );

    await tester.tap(find.text('Outgoing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courier Runs'));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['view'], 'runs');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow screen and large text keep filters usable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final auth = _auth((request) async {
        requests.add(request);
        final view = request.url.queryParameters['view'] ?? 'incoming';
        return http.Response(
          jsonEncode(view == 'runs' ? _runPage() : _handoffPage(view: view)),
          200,
        );
      });

      await tester.pumpWidget(_app(auth, textScale: 1.5));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('logistics-city-handoffs-view-scroll')),
        findsOneWidget,
      );
      expect(find.text('Incoming'), findsOneWidget);
      expect(find.text('Outgoing'), findsOneWidget);
      expect(find.text('Courier Runs'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('logistics-city-handoffs-view-scroll')),
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('logistics-city-handoffs-tab-runs')),
      );
      await tester.tap(
        find.byKey(const ValueKey('logistics-city-handoffs-tab-runs')),
      );
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['view'], 'runs');

      await tester.tap(
        find.byKey(const ValueKey('logistics-city-handoffs-status-runs')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed').last);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['status'], 'completed');

      await tester.enterText(
        find.byKey(const ValueKey('logistics-city-handoffs-search')),
        'LHR-001',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['search'], 'LHR-001');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows a loading state while City Handoffs are fetched', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final auth = _auth((_) => response.future);
    await tester.pumpWidget(_app(auth));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(
      http.Response(jsonEncode(_handoffPage(items: const [])), 200),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No incoming City Handoffs match these filters.'),
      findsOneWidget,
    );
  });

  testWidgets('shows incoming eligibility, parcel identifiers and history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _auth(
      (_) async => http.Response(jsonEncode(_handoffPage()), 200),
    );
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    expect(find.text('City Handoffs'), findsOneWidget);
    expect(find.text('BRLY-CITY-001'), findsOneWidget);
    expect(find.textContaining('Origin Logistics'), findsOneWidget);
    expect(find.textContaining('Destination Logistics'), findsWidgets);
    expect(
      find.textContaining('Wait until the assigned Courier run'),
      findsOneWidget,
    );
    expect(find.text('Accept incoming handoff'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('logistics-city-handoff-details-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('PCL-CITY-001'), findsOneWidget);
    expect(find.text('Departed'), findsWidgets);
    expect(find.textContaining('Courier One'), findsWidgets);
  });

  testWidgets('Courier Runs tab shows manifest and assigned Courier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(
          request.url.queryParameters['view'] == 'runs'
              ? _runPage()
              : _handoffPage(),
        ),
        200,
      );
    });
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courier Runs'));
    await tester.pumpAndSettle();

    expect(requests.last.url.queryParameters['view'], 'runs');
    expect(requests.last.url.queryParameters['status'], 'active');
    expect(find.text('LHR-001'), findsOneWidget);
    expect(find.textContaining('Courier One'), findsOneWidget);
    await tester.tap(find.text('LHR-001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BRLY-CITY-001'));
    await tester.pumpAndSettle();
    expect(find.text('BRLY-CITY-001'), findsOneWidget);
    expect(find.text('PCL-CITY-001'), findsOneWidget);
  });

  testWidgets('status search and pagination reload the read-only endpoint', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(
          _handoffPage(
            page: request.url.queryParameters['page'] == '2' ? 2 : 1,
          ),
        ),
        200,
      );
    });
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('logistics-city-handoffs-search')),
      'BRLY-CITY',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['search'], 'BRLY-CITY');

    await tester.tap(
      find.byKey(const ValueKey('logistics-city-handoffs-next')),
    );
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['page'], '2');

    await tester.drag(
      find.byKey(const ValueKey('logistics-city-handoffs-list')),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['page'], '1');
    expect(requests, hasLength(4));
  });

  testWidgets('empty, error and retry states are clear', (tester) async {
    var attempts = 0;
    final auth = _auth((_) async {
      attempts++;
      if (attempts == 1) return http.Response('unavailable', 503);
      return http.Response(jsonEncode(_handoffPage(items: const [])), 200);
    });
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    expect(find.text('City Handoffs could not be loaded.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('logistics-city-handoffs-retry')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No incoming City Handoffs match these filters.'),
      findsOneWidget,
    );
  });

  testWidgets('outgoing view shows eligible courier options as advisory', (
    tester,
  ) async {
    final auth = _auth(
      (request) async => http.Response(
        jsonEncode(
          _handoffPage(
            view: request.url.queryParameters['view'] ?? 'incoming',
            couriers: const [
              {
                'id': 5,
                'name': 'Available Courier',
                'vehicle_type': 'Van',
                'parcel_capacity': 10,
              },
            ],
          ),
        ),
        200,
      ),
    );
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outgoing'));
    await tester.pumpAndSettle();
    expect(find.text('Currently available verified Couriers'), findsOneWidget);
    expect(find.text('Available Courier'), findsOneWidget);
    expect(find.textContaining('rechecks each Courier'), findsOneWidget);
  });
}

Widget _app(AuthService auth, {double textScale = 1}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: LogisticsCityHandoffsWorkspacePage(
        repository: LogisticsRepository(authService: auth),
      ),
    ),
  ),
);

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
        name: 'City Handoffs Operator',
        email: 'city-handoffs@example.test',
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

Map<String, Object?> _handoffPage({
  String view = 'incoming',
  List<Map<String, Object?>>? items,
  List<Map<String, Object?>> couriers = const [],
  int page = 1,
}) => {
  'data': {
    'provider': {'id': 2, 'name': 'Destination Logistics'},
    'active_sorting_center': {
      'id': 2,
      'name': 'Destination SC',
      'code': 'SC-D',
    },
    'view': view,
    'items':
        items ??
        [
          {
            'id': 1,
            'direction': view,
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
              'loaded_at': null,
              'departed_at': '2026-11-09T00:10:00Z',
              'arrived_at': null,
              'courier': {
                'id': 5,
                'name': 'Courier One',
                'work_type': 'courier',
                'vehicle_type': 'Van',
                'parcel_capacity': 10,
              },
            },
            'acceptance_eligibility': {
              'eligible': false,
              'code': 'courier_not_arrived',
              'message':
                  'Wait until the assigned Courier run is marked Arrived.',
            },
            'sent_at': '2026-11-09T00:10:00Z',
            'accepted_at': null,
            'history': [
              {
                'event': 'departed',
                'from_status': 'loaded',
                'to_status': 'departed',
                'occurred_at': '2026-11-09T00:10:00Z',
                'actor': 'Courier One',
              },
            ],
          },
        ],
    'available_couriers': couriers,
    'filters': {'status': view == 'runs' ? 'active' : 'sent', 'search': null},
    'pagination': {
      'current_page': page,
      'last_page': 2,
      'per_page': 20,
      'total': 21,
    },
  },
};

Map<String, Object?> _runPage() => {
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
          'id': 5,
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
        'loaded_at': null,
        'departed_at': '2026-11-09T00:10:00Z',
        'arrived_at': null,
        'completed_at': null,
        'history': [
          {
            'event': 'departed',
            'from_status': 'loaded',
            'to_status': 'departed',
            'occurred_at': '2026-11-09T00:10:00Z',
            'actor': 'Courier One',
          },
        ],
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
