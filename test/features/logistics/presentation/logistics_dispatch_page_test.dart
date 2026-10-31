import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_dispatch_page.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Logistics dashboard opens the delivery dispatch board', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      return switch (request.url.path) {
        '/api/mobile/logistics/dashboard' => http.Response(
          jsonEncode(_dashboard()),
          200,
        ),
        '/api/mobile/logistics/dispatch-board' => http.Response(
          jsonEncode(_board()),
          200,
        ),
        _ => http.Response('{}', 404),
      };
    });

    await tester.pumpWidget(_home(auth));
    await tester.pumpAndSettle();
    final entry = find.byKey(
      const ValueKey('logistics-open-delivery-dispatch'),
    );
    await tester.scrollUntilVisible(
      entry,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.url.path), [
      '/api/mobile/logistics/dashboard',
      '/api/mobile/logistics/dispatch-board',
    ]);
    expect(find.text('Delivery Dispatch'), findsOneWidget);
    expect(find.text('PILA-02 · Pila / Pinagbayanan'), findsOneWidget);
    expect(find.text('BRLY-L5-001'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('logistics-dispatch-rider-2')),
      findsOneWidget,
    );
  });

  testWidgets(
    'dispatch requires explicit confirmation and cancellation sends no POST',
    (tester) async {
      final requests = <http.Request>[];
      final auth = _auth((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_board()), 200);
      });

      await tester.pumpWidget(_dispatch(auth));
      await tester.pumpAndSettle();
      await _chooseRider(tester);
      final action = find.byKey(const ValueKey('logistics-dispatch-zone-2'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('logistics-dispatch-confirm-dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('BRLY-L5-001'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET']);
    },
  );

  testWidgets(
    'confirmed dispatch posts only selected identifiers and refreshes board',
    (tester) async {
      final requests = <http.Request>[];
      var boardReads = 0;
      final auth = _auth((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/mobile/logistics/dispatch/zones/2/dispatch',
          );
          expect(jsonDecode(request.body), {'rider_profile_id': 9});
          return http.Response(jsonEncode(_dispatchResult()), 200);
        }
        boardReads++;
        return http.Response(
          jsonEncode(boardReads == 1 ? _board() : _board(zones: const [])),
          200,
        );
      });

      await tester.pumpWidget(_dispatch(auth));
      await tester.pumpAndSettle();
      await _chooseRider(tester);
      final action = find.byKey(const ValueKey('logistics-dispatch-zone-2'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-confirm-dispatch')),
      );
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      expect(
        find.textContaining('Server confirmed DSP-L5-001'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Could not dispatch these parcels. Check the board and try again.',
        ),
        findsNothing,
      );
      expect(
        find.text('No sorted parcels are ready for delivery dispatch.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'confirmed dispatch stays successful when the follow-up board read fails',
    (tester) async {
      final requests = <http.Request>[];
      final auth = _auth((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(jsonEncode(_dispatchResult()), 200);
        }
        if (requests.where((item) => item.method == 'GET').length == 1) {
          return http.Response(jsonEncode(_board()), 200);
        }
        return http.Response(
          jsonEncode({'message': 'temporary read error'}),
          503,
        );
      });

      await tester.pumpWidget(_dispatch(auth));
      await tester.pumpAndSettle();
      await _submitConfirmedDispatch(tester);

      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      expect(
        find.textContaining('Server confirmed DSP-L5-001'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Dispatch was confirmed as DSP-L5-001, but the board could not be refreshed.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Could not dispatch these parcels. Check the board and try again.',
        ),
        findsNothing,
      );
      expect(find.textContaining('result is uncertain'), findsNothing);
    },
  );

  testWidgets('confirmed POST rejection shows an error without success', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'message': 'The selected Rider is no longer eligible.',
            'errors': {
              'rider_profile_id': ['The selected Rider is no longer eligible.'],
            },
          }),
          422,
        );
      }
      return http.Response(jsonEncode(_board()), 200);
    });

    await tester.pumpWidget(_dispatch(auth));
    await tester.pumpAndSettle();
    await _submitConfirmedDispatch(tester);

    expect(requests.map((request) => request.method), ['GET', 'POST']);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(
      find.text('The selected Rider is no longer eligible.'),
      findsOneWidget,
    );
    expect(find.textContaining('Server confirmed'), findsNothing);
    expect(find.textContaining('result is uncertain'), findsNothing);
  });

  testWidgets('manual refresh after successful dispatch preserves its result', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response(jsonEncode(_dispatchResult()), 200);
      }
      final getCount = requests.where((item) => item.method == 'GET').length;
      return http.Response(
        jsonEncode(getCount == 1 ? _board() : _board(zones: const [])),
        200,
      );
    });

    await tester.pumpWidget(_dispatch(auth));
    await tester.pumpAndSettle();
    await _submitConfirmedDispatch(tester);
    expect(find.textContaining('Server confirmed DSP-L5-001'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh dispatch board'));
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'GET',
      'GET',
    ]);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(find.textContaining('Server confirmed DSP-L5-001'), findsOneWidget);
    expect(
      find.text(
        'Could not dispatch these parcels. Check the board and try again.',
      ),
      findsNothing,
    );
  });

  testWidgets('no eligible Rider is clearly reported', (tester) async {
    final auth = _auth(
      (request) async => http.Response(
        jsonEncode(_board(zones: [_zone(riders: const [])])),
        200,
      ),
    );

    await tester.pumpWidget(_dispatch(auth));
    await tester.pumpAndSettle();
    expect(
      find.text('No eligible Rider has capacity for this entire zone batch.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('logistics-confirm-dispatch')),
      findsNothing,
    );
  });

  for (final (width, textScale) in [(320.0, 1.0), (360.0, 1.3), (393.0, 1.5)]) {
    testWidgets(
      'dispatch card and review dialog fit at ${width.toInt()}px with text scale $textScale',
      (tester) async {
        const waybill =
            'BRLY-ULD904RGCHZK1SIDLUND-EXTRA-LONG-IDENTIFIER-KEEP-FULL';
        const parcelReference = 'PCL-6WLXGU2SQOTDWEIA1MZH-EXTRA-LONG';
        const shipmentReference = 'SHP-Y1UO5AHT0PL4XMRVFPYV-EXTRA-LONG';
        const riderName = 'Mark Carlo Alfonso de la Cruz Andasan Rivera';
        const riderLabel = '$riderName · 3 of 10 capacity available';
        final requests = <http.Request>[];
        final auth = _auth((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              _board(
                zones: [
                  _zone(
                    waybill: waybill,
                    parcelReference: parcelReference,
                    shipmentReference: shipmentReference,
                    riders: [_rider(name: riderName, capacity: 10, load: 7)],
                  ),
                ],
              ),
            ),
            200,
          );
        });

        await _pumpDispatchAtSize(
          tester,
          auth,
          width: width,
          textScale: textScale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(waybill), findsOneWidget);
        expect(find.textContaining(parcelReference), findsOneWidget);
        expect(find.textContaining(shipmentReference), findsOneWidget);

        final riderField = find.byKey(
          const ValueKey('logistics-dispatch-rider-2'),
        );
        await tester.ensureVisible(riderField);
        await tester.pumpAndSettle();
        await tester.tap(riderField);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(riderLabel), findsOneWidget);
        await tester.tap(find.text(riderLabel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final selectedNameFinder = find.byKey(
          const ValueKey('logistics-dispatch-rider-name-2-9'),
        );
        final selectedName = tester.widget<Text>(selectedNameFinder);
        expect(selectedName.data, riderName);
        expect(selectedName.maxLines, 1);
        expect(selectedName.overflow, TextOverflow.ellipsis);
        expect(selectedName.semanticsLabel, riderName);
        final selectedParagraphFinder = find.descendant(
          of: selectedNameFinder,
          matching: find.byType(RichText),
        );
        expect(
          tester
              .renderObject<RenderParagraph>(selectedParagraphFinder)
              .didExceedMaxLines,
          isTrue,
        );
        final capacityFinder = find.byKey(
          const ValueKey('logistics-dispatch-rider-capacity-2'),
        );
        expect(find.text('3 of 10 capacity available'), findsOneWidget);
        expect(
          tester.getTopLeft(capacityFinder).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(riderField).dy),
        );

        final reviewButton = find.byKey(
          const ValueKey('logistics-dispatch-zone-2'),
        );
        await tester.ensureVisible(reviewButton);
        await tester.pumpAndSettle();
        await tester.tap(reviewButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('logistics-dispatch-confirm-dialog')),
          findsOneWidget,
        );
        final dialog = find.byKey(
          const ValueKey('logistics-dispatch-confirm-dialog'),
        );
        expect(
          find.descendant(of: dialog, matching: find.text(riderName)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.text(waybill)),
          findsOneWidget,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(requests.map((request) => request.method), ['GET']);
      },
    );
  }

  testWidgets(
    'uncertain dispatch blocks resubmission until a fresh board read',
    (tester) async {
      final requests = <http.Request>[];
      var boardReads = 0;
      final auth = _auth((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'message': 'server error'}), 500);
        }
        boardReads++;
        return http.Response(jsonEncode(_board()), 200);
      });

      await tester.pumpWidget(_dispatch(auth));
      await tester.pumpAndSettle();
      await _chooseRider(tester);
      final action = find.byKey(const ValueKey('logistics-dispatch-zone-2'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-confirm-dispatch')),
      );
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      expect(find.textContaining('result is uncertain'), findsOneWidget);
      expect(find.textContaining('Server confirmed'), findsNothing);
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      await tester.tap(
        find.byKey(
          const ValueKey('logistics-refresh-after-uncertain-dispatch'),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(boardReads, 2);
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
    },
  );

  testWidgets('dispatch action disables while the server request is pending', (
    tester,
  ) async {
    final pendingPost = Completer<http.Response>();
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      if (request.method == 'POST') return pendingPost.future;
      return http.Response(jsonEncode(_board()), 200);
    });

    await tester.pumpWidget(_dispatch(auth));
    await tester.pumpAndSettle();
    await _chooseRider(tester);
    final action = find.byKey(const ValueKey('logistics-dispatch-zone-2'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logistics-confirm-dispatch')));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    expect(requests.map((request) => request.method), ['GET', 'POST']);

    pendingPost.complete(http.Response(jsonEncode(_dispatchResult()), 200));
    await tester.pumpAndSettle();
    expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
  });
}

Future<void> _chooseRider(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('logistics-dispatch-rider-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rider Mark · 3 of 5 capacity available').last);
  await tester.pumpAndSettle();
}

Future<void> _submitConfirmedDispatch(WidgetTester tester) async {
  await _chooseRider(tester);
  final action = find.byKey(const ValueKey('logistics-dispatch-zone-2'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('logistics-confirm-dispatch')));
  await tester.pumpAndSettle();
}

Widget _home(AuthService auth) => MaterialApp(
  home: LogisticsHomePage(
    authService: auth,
    repository: LogisticsRepository(authService: auth),
  ),
);

Widget _dispatch(AuthService auth) => MaterialApp(
  home: LogisticsDispatchPage(
    repository: LogisticsRepository(authService: auth),
  ),
);

Future<void> _pumpDispatchAtSize(
  WidgetTester tester,
  AuthService auth, {
  required double width,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 820);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 820),
          textScaler: TextScaler.linear(textScale),
        ),
        child: LogisticsDispatchPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    ),
  );
}

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'l5-test-token',
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
      'sorted_ready': 1,
      'dispatched_shipments': 0,
      'active_routes': 0,
      'sorting_exceptions': 0,
      'pending_pickup_requests': 0,
      'incoming_handoffs': 0,
    },
    'incoming': {'handoffs': [], 'parcels': []},
  },
};

Map<String, Object?> _zone({
  List<Map<String, Object?>>? riders,
  String waybill = 'BRLY-L5-001',
  String parcelReference = 'PCL-L5-001',
  String shipmentReference = 'SHP-L5-001',
}) => {
  'id': 2,
  'zone': 'PILA-02',
  'area': 'Pila / Pinagbayanan',
  'coverage': 'Laguna / Pila · Pinagbayanan',
  'ready': 1,
  'routing_issues': 0,
  'riders': riders ?? [_rider()],
  'parcels': [
    {
      'id': 12,
      'reference': parcelReference,
      'waybill': waybill,
      'shipment_reference': shipmentReference,
      'status': 'sorted',
    },
  ],
};

Map<String, Object?> _rider({
  String name = 'Rider Mark',
  int capacity = 5,
  int load = 2,
}) => {
  'id': 9,
  'name': name,
  'load': load,
  'capacity': capacity,
  'remaining': capacity - load,
};

Map<String, Object?> _board({List<Map<String, Object?>>? zones}) => {
  'data': {
    'provider': {'id': 1, 'name': 'Pila Logistics', 'status': 'active'},
    'sorting_center': {
      'id': 2,
      'name': 'Pila Sorting Center',
      'code': 'SC-1',
      'status': 'active',
      'address': 'Pila, Laguna',
    },
    'zones': zones ?? [_zone()],
  },
};

Map<String, Object?> _dispatchResult() => {
  'message': 'Delivery dispatch confirmed.',
  'data': {
    'dispatch_batch': {
      'id': 35,
      'reference': 'DSP-L5-001',
      'status': 'dispatched',
      'rider': {'id': 9, 'name': 'Rider Mark'},
      'sorting_center': {'id': 2, 'name': 'Pila Sorting Center'},
      'zone': {'id': 2, 'code': 'PILA-02', 'name': 'Pila / Pinagbayanan'},
      'parcels': [
        {
          'id': 12,
          'reference': 'PCL-L5-001',
          'waybill': 'BRLY-L5-001',
          'shipment_reference': 'SHP-L5-001',
          'status': 'dispatched',
          'shipment_status': 'dispatched',
        },
      ],
    },
    'refreshed_dispatch_board': {
      'provider': {'id': 1, 'name': 'Pila Logistics', 'status': 'active'},
      'sorting_center': {
        'id': 2,
        'name': 'Pila Sorting Center',
        'code': 'SC-1',
        'status': 'active',
        'address': 'Pila, Laguna',
      },
      'zones': [],
    },
  },
};
