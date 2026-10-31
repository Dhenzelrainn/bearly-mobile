import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('loads provider, center, metrics, and refreshes server data', (
    tester,
  ) async {
    var requests = 0;
    final auth = _authService((request) async {
      expect(request.url.path, '/api/mobile/logistics/dashboard');
      expect(request.headers['authorization'], 'Bearer logistics-test-token');
      requests++;
      return http.Response(
        jsonEncode(_dashboard(receivedToday: requests)),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsHomePage(
          authService: auth,
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Victoria Logistics'), findsOneWidget);
    expect(find.text('Victoria Sorting Center'), findsOneWidget);
    expect(find.text('Received today'), findsOneWidget);
    expect(requests, 1);

    final receivedCard = find
        .ancestor(of: find.text('Received today'), matching: find.byType(Card))
        .first;
    expect(
      find.descendant(of: receivedCard, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Refresh dashboard'));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(
      find.descendant(of: receivedCard, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('dashboard opens the read-only waybill lookup page', (
    tester,
  ) async {
    final auth = _authService(
      (_) async => http.Response(jsonEncode(_dashboard()), 200),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsHomePage(
          authService: auth,
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('logistics-open-waybill-lookup')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read-only parcel lookup'), findsOneWidget);
    expect(find.text('Scan with camera'), findsOneWidget);
    expect(find.text('Look up'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-open-incoming-handoff')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Incoming City Handoff'), findsOneWidget);
    expect(
      find.textContaining('accept only a handoff addressed'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-open-incoming-receipt')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Incoming Parcel Receipt'), findsOneWidget);
    expect(find.text('Read-only parcel lookup'), findsNothing);
  });

  testWidgets('dashboard opens provider delivery monitoring', (tester) async {
    final auth = _authService((request) async {
      if (request.url.path == '/api/mobile/logistics/dashboard') {
        return http.Response(jsonEncode(_dashboard()), 200);
      }
      expect(request.method, 'GET');
      expect(request.url.path, '/api/mobile/logistics/delivery-monitoring');
      return http.Response(
        jsonEncode({
          'data': {
            'provider': {'id': 3, 'name': 'Victoria Logistics'},
            'deliveries': [],
          },
        }),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsHomePage(
          authService: auth,
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('logistics-open-delivery-monitoring')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('logistics-open-delivery-monitoring')));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Monitoring'), findsOneWidget);
    expect(find.text('No delivery batches are available yet.'), findsOneWidget);
  });

  testWidgets(
    'dashboard labels current status separately from historical intake',
    (tester) async {
      final auth = _authService(
        (_) async => http.Response(
          jsonEncode(
            _dashboard(
              parcels: const [
                {
                  'waybill': 'BRLY-DELIVERED-HISTORY',
                  'purpose': 'buyer_delivery',
                  'parcel_statuses': ['delivered'],
                  'intake_recorded': true,
                  'parcel_count': 1,
                },
              ],
            ),
          ),
          200,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LogisticsHomePage(
            authService: auth,
            repository: LogisticsRepository(authService: auth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('BRLY-DELIVERED-HISTORY'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Parcel records at this center'), findsOneWidget);
      expect(find.textContaining('Delivered · 1 parcel(s)'), findsOneWidget);
      expect(
        find.textContaining('center intake recorded previously'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows setup-required and empty states when no active center exists',
    (tester) async {
      final auth = _authService(
        (_) async => http.Response(
          jsonEncode(
            _dashboard(
              sortingCenter: null,
              setupRequired: true,
              handoffs: const [],
              parcels: const [],
            ),
          ),
          200,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LogisticsHomePage(
            authService: auth,
            repository: LogisticsRepository(authService: auth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sorting center setup required'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No incoming handoffs are waiting.'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No incoming handoffs are waiting.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No parcel records are currently listed at your center.'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('No parcel records are currently listed at your center.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows a retry control after a read-only dashboard error', (
    tester,
  ) async {
    var requests = 0;
    final auth = _authService((_) async {
      requests++;
      return requests == 1
          ? http.Response('{"message":"Unavailable"}', 503)
          : http.Response(jsonEncode(_dashboard()), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsHomePage(
          authService: auth,
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not load your Logistics dashboard'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Victoria Logistics'), findsOneWidget);
  });

  testWidgets('expired session shows sign-in again and clears the token', (
    tester,
  ) async {
    final store = _MemoryTokenStore()..token = 'logistics-test-token';
    final auth = _authService(
      (_) async => http.Response('{"message":"Unauthenticated"}', 401),
      tokenStore: store,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsHomePage(
          authService: auth,
          repository: LogisticsRepository(authService: auth),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Login destination')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('session is no longer authorized'),
      findsOneWidget,
    );
    expect(store.token, isNull);
    await tester.tap(find.text('Sign in again'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
  });
}

Map<String, Object?> _dashboard({
  int receivedToday = 0,
  Object? sortingCenter = const {
    'id': 3,
    'name': 'Victoria Sorting Center',
    'code': 'SC-VIC-3',
    'status': 'active',
    'address': 'Victoria, Laguna',
  },
  bool setupRequired = false,
  List<Map<String, Object?>> handoffs = const [
    {
      'waybill': 'BRLY-TEST-001',
      'from_provider': 'South Laguna Logistics',
      'purpose': 'buyer_delivery',
      'parcel_count': 2,
    },
  ],
  List<Map<String, Object?>> parcels = const [
    {
      'waybill': 'BRLY-TEST-002',
      'purpose': 'buyer_delivery',
      'parcel_statuses': ['received'],
      'intake_recorded': true,
      'parcel_count': 1,
    },
  ],
}) => {
  'data': {
    'provider': {'id': 3, 'name': 'Victoria Logistics', 'status': 'active'},
    'sorting_center': sortingCenter,
    'setup_required': setupRequired,
    'metrics': {
      'received_today': receivedToday,
      'awaiting_sorting': 2,
      'sorted_ready': 1,
      'dispatched_shipments': 4,
      'active_routes': 1,
      'sorting_exceptions': 0,
      'pending_pickup_requests': 0,
      'incoming_handoffs': handoffs.length,
    },
    'incoming': {'handoffs': handoffs, 'parcels': parcels},
  },
};

AuthService _authService(
  Future<http.Response> Function(http.Request) handler, {
  _MemoryTokenStore? tokenStore,
}) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore:
            tokenStore ?? (_MemoryTokenStore()..token = 'logistics-test-token'),
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
