import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_sorting_queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('dashboard opens queue with server-provided matching zones', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _authService((request) async {
      requests.add(request);
      return switch (request.url.path) {
        '/api/mobile/logistics/dashboard' => http.Response(
          jsonEncode(_dashboard()),
          200,
        ),
        '/api/mobile/logistics/sorting-queue' => http.Response(
          jsonEncode(_queue()),
          200,
        ),
        _ => http.Response('{}', 404),
      };
    });

    await tester.pumpWidget(_home(auth));
    await tester.pumpAndSettle();
    final openQueue = find.byKey(
      const ValueKey('logistics-open-sorting-queue'),
    );
    await tester.scrollUntilVisible(
      openQueue,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(openQueue);
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.url.path), [
      '/api/mobile/logistics/dashboard',
      '/api/mobile/logistics/sorting-queue',
    ]);
    expect(find.text('Sorting Queue'), findsOneWidget);
    expect(find.text('BRLY-L4-001'), findsOneWidget);
    expect(find.text('Pinagbayanan, Pila, Laguna'), findsOneWidget);
    expect(find.text('Sorting Snapshot Bear'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('logistics-sorting-zone-42')));
    await tester.pumpAndSettle();
    expect(find.text('PILA-02 · Pila / Pinagbayanan'), findsOneWidget);
  });

  testWidgets('sorting requires confirmation and refreshes server state', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var queueReads = 0;
    final auth = _authService((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        expect(
          request.url.path,
          '/api/mobile/logistics/sorting/parcels/42/sort',
        );
        expect(jsonDecode(request.body), {'sorting_zone_id': 2});
        return http.Response(jsonEncode(_sortResult()), 200);
      }
      queueReads++;
      return http.Response(
        jsonEncode(queueReads == 1 ? _queue() : _queue(parcels: const [])),
        200,
      );
    });

    await tester.pumpWidget(_sortingPage(auth));
    await tester.pumpAndSettle();
    await _selectZone(tester);
    final sort = find.byKey(const ValueKey('logistics-sort-parcel-42'));
    await tester.ensureVisible(sort);
    await tester.pumpAndSettle();
    await tester.tap(sort);
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET']);
    expect(
      find.byKey(const ValueKey('logistics-sorting-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('BRLY-L4-001'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('logistics-confirm-sort')));
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
    expect(
      find.text('Server confirmed PCL-L4-001 is sorted into PILA-02.'),
      findsOneWidget,
    );
    expect(
      find.text('No received parcels are waiting at this center.'),
      findsOneWidget,
    );
  });

  testWidgets('uncertain sort response requires a fresh read before retry', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _authService((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'message': 'server error'}), 500);
      }
      return http.Response(jsonEncode(_queue()), 200);
    });

    await tester.pumpWidget(_sortingPage(auth));
    await tester.pumpAndSettle();
    await _selectZone(tester);
    await tester.tap(find.byKey(const ValueKey('logistics-sort-parcel-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logistics-confirm-sort')));
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET', 'POST']);
    expect(find.textContaining('result is uncertain'), findsOneWidget);
    final sort = tester.widget<FilledButton>(
      find.byKey(const ValueKey('logistics-sort-parcel-42')),
    );
    expect(sort.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('logistics-refresh-after-uncertain-sort')),
    );
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
    final refreshedSort = tester.widget<FilledButton>(
      find.byKey(const ValueKey('logistics-sort-parcel-42')),
    );
    expect(refreshedSort.onPressed, isNotNull);
  });

  testWidgets('sort button disables while the server request is pending', (
    tester,
  ) async {
    final pendingPost = Completer<http.Response>();
    final requests = <http.Request>[];
    final auth = _authService((request) async {
      requests.add(request);
      if (request.method == 'POST') return pendingPost.future;
      return http.Response(jsonEncode(_queue()), 200);
    });

    await tester.pumpWidget(_sortingPage(auth));
    await tester.pumpAndSettle();
    await _selectZone(tester);
    await tester.tap(find.byKey(const ValueKey('logistics-sort-parcel-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logistics-confirm-sort')));
    await tester.pump();
    await tester.pump();

    final pendingButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('logistics-sort-parcel-42')),
    );
    expect(pendingButton.onPressed, isNull);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));

    pendingPost.complete(http.Response(jsonEncode(_sortResult()), 200));
    await tester.pumpAndSettle();
    expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
  });

  testWidgets('queue read errors provide a retry action', (tester) async {
    var reads = 0;
    final auth = _authService((request) async {
      reads++;
      return http.Response(
        reads == 1 ? '{}' : jsonEncode(_queue()),
        reads == 1 ? 503 : 200,
      );
    });

    await tester.pumpWidget(_sortingPage(auth));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load the sorting queue'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('BRLY-L4-001'), findsOneWidget);
  });
}

Future<void> _selectZone(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('logistics-sorting-zone-42')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('PILA-02 · Pila / Pinagbayanan').last);
  await tester.pumpAndSettle();
}

Widget _home(AuthService auth) => MaterialApp(
  home: LogisticsHomePage(
    authService: auth,
    repository: LogisticsRepository(authService: auth),
  ),
);

Widget _sortingPage(AuthService auth) => MaterialApp(
  home: LogisticsSortingQueuePage(
    repository: LogisticsRepository(authService: auth),
  ),
);

AuthService _authService(
  Future<http.Response> Function(http.Request) handler,
) =>
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

Map<String, Object?> _dashboard() => {
  'data': {
    'provider': {'id': 1, 'name': 'Pila Logistics', 'status': 'active'},
    'sorting_center': {
      'id': 2,
      'name': 'Pila Sorting Center',
      'code': 'SC-1',
      'status': 'active',
      'address': 'Pila, Laguna',
    },
    'setup_required': false,
    'metrics': {
      'received_today': 1,
      'awaiting_sorting': 1,
      'sorted_ready': 0,
      'dispatched_shipments': 0,
      'active_routes': 0,
      'sorting_exceptions': 0,
      'pending_pickup_requests': 0,
      'incoming_handoffs': 0,
    },
    'incoming': {'handoffs': [], 'parcels': []},
  },
};

Map<String, Object?> _queue({
  List<Map<String, Object?>> parcels = const [
    {
      'id': 42,
      'reference': 'PCL-L4-001',
      'waybill': 'BRLY-L4-001',
      'shipment_reference': 'SHP-L4-001',
      'status': 'received',
      'destination': {
        'barangay': 'Pinagbayanan',
        'city_municipality': 'Pila',
        'province': 'Laguna',
      },
      'current_zone': null,
      'matching_zones': [
        {
          'id': 2,
          'code': 'PILA-02',
          'name': 'Pila / Pinagbayanan',
          'coverage': 'Laguna / Pila · Pinagbayanan',
        },
      ],
      'can_sort': true,
      'products': [
        {
          'name': 'Sorting Snapshot Bear',
          'variant': 'Honey / Large',
          'quantity': 1,
          'image_url': 'https://images.bearly.test/sorting.jpg',
        },
      ],
    },
  ],
}) => {
  'data': {
    'sorting_center': {
      'id': 2,
      'name': 'Pila Sorting Center',
      'code': 'SC-1',
      'status': 'active',
      'address': 'Pila, Laguna',
    },
    'parcels': parcels,
  },
};

Map<String, Object?> _sortResult() => {
  'message': 'Parcel sorted successfully.',
  'data': {
    'parcel': {
      'id': 42,
      'reference': 'PCL-L4-001',
      'status': 'sorted',
      'current_sorting_center': {
        'id': 2,
        'name': 'Pila Sorting Center',
        'code': 'SC-1',
        'status': 'active',
        'address': 'Pila, Laguna',
      },
      'current_zone': {
        'id': 2,
        'code': 'PILA-02',
        'name': 'Pila / Pinagbayanan',
      },
    },
    'shipment': {'reference': 'SHP-L4-001', 'status': 'sorted'},
  },
};
