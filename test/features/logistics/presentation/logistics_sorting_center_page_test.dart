import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_sorting_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'dashboard opens read-only Sorting Center with zones and readiness',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final auth = _authService((request) async {
        requests.add(request);
        if (request.url.path == '/api/mobile/logistics/dashboard') {
          return http.Response(jsonEncode(_dashboard()), 200);
        }
        if (request.url.path ==
            '/api/mobile/logistics/sorting-center/workspace') {
          return http.Response(jsonEncode(_workspace()), 200);
        }
        return http.Response('{}', 404);
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
      final open = find.byKey(const ValueKey('logistics-open-sorting-center'));
      await tester.scrollUntilVisible(
        open,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(open);
      await tester.pumpAndSettle();

      expect(requests, hasLength(2));
      expect(
        requests.last.url.path,
        '/api/mobile/logistics/sorting-center/workspace',
      );
      expect(requests.last.url.queryParameters, {
        'status': 'awaiting_sorting',
        'page': '1',
        'per_page': '20',
      });
      expect(find.text('Pila Sorting Center'), findsOneWidget);
      expect(find.text('Parcel P-100 · Piece 1 of 2'), findsOneWidget);
      expect(find.textContaining('P-100-B'), findsOneWidget);
      expect(find.text('Sorting Snapshot Bear'), findsOneWidget);
      expect(find.text('Mark parcel sorted'), findsNothing);
      expect(
        find.byKey(const ValueKey('sorting-center-open-queue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('sorting-center-open-dispatch')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('sorting-center-zones')));
      await tester.pumpAndSettle();
      expect(find.text('PILA-02 · Pila / Pinagbayanan'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('sorting-center-dispatch-readiness')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Other-zone Local Rider candidates'),
        findsOneWidget,
      );
      expect(find.textContaining('Rider A'), findsOneWidget);
    },
  );

  testWidgets(
    'operational links open existing screens and refresh workspace on return',
    (tester) async {
      var workspaceReads = 0;
      final auth = _authService((request) async {
        if (request.url.path ==
            '/api/mobile/logistics/sorting-center/workspace') {
          workspaceReads++;
          return http.Response(jsonEncode(_workspace()), 200);
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => LogisticsSortingCenterPage(
              repository: LogisticsRepository(authService: auth),
              onOpenSortingQueue: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Existing Sorting Queue')),
                  ),
                ),
              ),
              onOpenDispatchBoard: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Existing Dispatch Board'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(workspaceReads, 1);

      await tester.tap(find.byKey(const ValueKey('sorting-center-open-queue')));
      await tester.pumpAndSettle();
      expect(find.text('Existing Sorting Queue'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(workspaceReads, 2);

      await tester.tap(
        find.byKey(const ValueKey('sorting-center-open-dispatch')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Existing Dispatch Board'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(workspaceReads, 3);
    },
  );

  testWidgets(
    'status, search, pagination and refresh use the read API filters',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final auth = _authService((request) async {
        requests.add(request);
        final query = request.url.queryParameters;
        final status = query['status'] ?? 'awaiting_sorting';
        final page = int.tryParse(query['page'] ?? '') ?? 1;
        final record = switch ((status, query['search'], page)) {
          ('sorted', 'WB-SEARCH', 2) => _parcel(reference: 'P-PAGE-2'),
          ('sorted', 'WB-SEARCH', _) => _parcel(
            status: 'sorted',
            reference: 'P-SEARCHED',
          ),
          ('sorted', _, 2) => _parcel(reference: 'P-PAGE-2'),
          ('sorted', _, _) => _parcel(status: 'sorted', reference: 'P-SORTED'),
          (_, _, 2) => _parcel(reference: 'P-PAGE-2'),
          _ => _parcel(),
        };
        return http.Response(
          jsonEncode(
            _workspace(
              parcels: [record],
              status: status,
              search: query['search'] ?? '',
              currentPage: page,
              lastPage: 2,
              hasMore: page == 1,
            ),
          ),
          200,
        );
      });

      await tester.pumpWidget(_sortingPage(auth));
      await tester.pumpAndSettle();
      expect(find.text('Parcel P-100 · Piece 1 of 2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('sorting-center-status-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sorted').last);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['status'], 'sorted');
      expect(find.textContaining('P-SORTED'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('sorting-center-search')),
        'WB-SEARCH',
      );
      await tester.tap(
        find.byKey(const ValueKey('sorting-center-search-submit')),
      );
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['search'], 'WB-SEARCH');
      expect(find.textContaining('P-SEARCHED'), findsOneWidget);

      final nextPage = find.byKey(const ValueKey('sorting-center-next-page'));
      await tester.scrollUntilVisible(
        nextPage,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(nextPage);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['page'], '2');
      expect(requests.last.url.queryParameters['search'], 'WB-SEARCH');
      expect(find.textContaining('P-PAGE-2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('logistics-refresh-sorting-center')),
      );
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['page'], '2');
    },
  );

  testWidgets('no active center presents a structured setup empty state', (
    tester,
  ) async {
    final auth = _authService((request) async {
      return http.Response(jsonEncode(_workspace(setupRequired: true)), 200);
    });
    await tester.pumpWidget(_sortingPage(auth));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Exactly one active Sorting Center must be assigned to this provider before sorting operations are available.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('workspace API error exposes retry state', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var reads = 0;
    final auth = _authService((request) async {
      reads++;
      return http.Response(
        reads == 1 ? '{}' : jsonEncode(_workspace()),
        reads == 1 ? 503 : 200,
      );
    });
    await tester.pumpWidget(_sortingPage(auth));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load the Sorting Center'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Parcel P-100 · Piece 1 of 2'), findsOneWidget);
  });
}

Widget _sortingPage(AuthService auth) => MaterialApp(
  home: LogisticsSortingCenterPage(
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

Map<String, Object?> _workspace({
  List<Map<String, Object?>>? parcels,
  String status = 'awaiting_sorting',
  String search = '',
  int currentPage = 1,
  int lastPage = 1,
  bool hasMore = false,
  bool setupRequired = false,
}) => {
  'data': {
    'provider': {'id': 1, 'name': 'Pila Logistics', 'status': 'active'},
    'sorting_center': setupRequired
        ? null
        : {
            'id': 2,
            'name': 'Pila Sorting Center',
            'code': 'SC-1',
            'status': 'active',
            'address': 'Pila, Laguna',
          },
    'setup_required': setupRequired,
    if (setupRequired)
      'setup_message':
          'Exactly one active Sorting Center must be assigned to this provider before sorting operations are available.',
    'zones': setupRequired
        ? []
        : [
            {
              'id': 42,
              'code': 'PILA-02',
              'name': 'Pila / Pinagbayanan',
              'status': 'active',
              'coverage': 'Laguna / Pila · Pinagbayanan',
            },
          ],
    'metrics': {'awaiting_sorting': 3, 'sorted': 2, 'exceptions': 1},
    'filters': {'status': status, 'search': search},
    'parcels': parcels ?? [_parcel()],
    'pagination': {
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': 20,
      'total': lastPage > 1 ? 21 : (parcels ?? [_parcel()]).length,
      'has_more_pages': hasMore,
    },
    'dispatch_readiness': setupRequired
        ? null
        : {
            'provider': {'id': 1, 'name': 'Pila Logistics', 'status': 'active'},
            'sorting_center': {
              'id': 2,
              'name': 'Pila Sorting Center',
              'code': 'SC-1',
              'status': 'active',
              'address': 'Pila, Laguna',
            },
            'zones': [
              {
                'id': 42,
                'zone': 'PILA-02',
                'area': 'Pila / Pinagbayanan',
                'coverage': 'Laguna / Pila · Pinagbayanan',
                'ready': 2,
                'routing_issues': 0,
                'parcels': [],
                'riders': [],
                'nearby_riders': [
                  {
                    'id': 77,
                    'name': 'Rider A',
                    'zone_code': 'PILA-03',
                    'remaining': 4,
                    'distance_label': null,
                    'gps_status_label': 'GPS unavailable',
                    'is_recommended': false,
                  },
                ],
                'proximity_status': 'destination_pin_missing',
                'proximity_message':
                    'Distances are hidden when a destination pin is unavailable.',
              },
            ],
          },
  },
};

Map<String, Object?> _parcel({
  String status = 'received',
  String reference = 'P-100',
}) => {
  'id': 100,
  'reference': reference,
  'waybill': 'WB-100',
  'shipment_reference': 'SHP-100',
  'purpose': 'outbound',
  'status': status,
  'piece_sequence': 1,
  'piece_count': 2,
  'products': [
    {
      'name': 'Sorting Snapshot Bear',
      'variant': 'Brown / Medium',
      'quantity': 1,
      'image_url': null,
    },
  ],
  'destination': {
    'barangay': 'Pinagbayanan',
    'city_municipality': 'Pila',
    'province': 'Laguna',
  },
  'current_zone': null,
  'current_zone_detail': null,
  'matching_zones': [
    {
      'id': 42,
      'code': 'PILA-02',
      'name': 'Pila / Pinagbayanan',
      'coverage': 'Laguna / Pila · Pinagbayanan',
    },
  ],
  'pieces': [
    {
      'reference': 'P-100',
      'sequence': 1,
      'status': status,
      'current_zone': null,
    },
    {
      'reference': 'P-100-B',
      'sequence': 2,
      'status': 'received',
      'current_zone': null,
    },
  ],
  'sorting_history': [
    {
      'event': 'received_at_center',
      'from_status': 'picked_up',
      'to_status': 'received',
      'sorting_center': 'SC-1',
      'sorting_zone': null,
      'occurred_at': '2026-11-09T02:00:00Z',
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
