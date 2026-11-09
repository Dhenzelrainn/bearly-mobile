import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_courier_runs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows initial loading until Courier runs are returned', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await tester.pumpWidget(_app((_) => response.future));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(http.Response(jsonEncode(_emptyPayload()), 200));
    await tester.pumpAndSettle();
    expect(
      find.text('No active Courier runs are assigned to you.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the empty state and refreshes the active run list', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      _app((request) async {
        expect(request.url.path, '/api/mobile/rider/courier-runs');
        requests++;
        return http.Response(jsonEncode(_emptyPayload()), 200);
      }),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No active Courier runs are assigned to you.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, 250));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retryable API error state', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      _app((request) async {
        requests++;
        return http.Response(
          jsonEncode({'message': 'Courier access is not available.'}),
          requests == 1 ? 503 : 200,
        );
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Courier access is not available.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(
      find.text('No active Courier runs are assigned to you.'),
      findsOneWidget,
    );
  });

  testWidgets('loads the next Courier run page on demand', (tester) async {
    final requestedPages = <String>[];
    await tester.pumpWidget(
      _app((request) async {
        final page = request.url.queryParameters['page'] ?? '1';
        requestedPages.add(page);
        return http.Response(
          jsonEncode(_pagePayload('assigned', page: page)),
          200,
        );
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('LH-TEST-1'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('LH-TEST-2'), findsOneWidget);
    expect(requestedPages, ['1', '2']);
  });

  testWidgets(
    'loads run detail and server actions on a narrow large-text screen',
    (tester) async {
      final oldSize = tester.view.physicalSize;
      final oldRatio = tester.view.devicePixelRatio;
      tester.view
        ..physicalSize = const Size(320, 860)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..physicalSize = oldSize
          ..devicePixelRatio = oldRatio;
      });

      var status = 'assigned';
      var getRunCount = 0;
      Future<http.Response> repositoryResponse(http.Request request) async {
        if (request.url.path.endsWith('/courier-runs')) {
          return http.Response(jsonEncode(_pagePayload(status)), 200);
        }
        if (request.method == 'POST') {
          status = 'loading';
          return http.Response(jsonEncode({'data': _runPayload(status)}), 200);
        }
        getRunCount++;
        return http.Response(jsonEncode({'data': _runPayload(status)}), 200);
      }

      await tester.pumpWidget(
        _app(repositoryResponse, textScaler: const TextScaler.linear(1.35)),
      );
      await tester.pumpAndSettle();
      expect(find.text('LH-TEST-1'), findsOneWidget);

      await tester.tap(find.text('LH-TEST-1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Origin: Origin Logistics'), findsOneWidget);
      expect(
        find.textContaining('Destination: Destination Logistics'),
        findsOneWidget,
      );
      expect(find.text('WB-TEST-1'), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('PARCEL-TEST-1'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Start loading'), findsOneWidget);

      await tester.tap(find.text('Start loading'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Confirm that you are at the origin facility and ready to load this manifest.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Confirm all cargo loaded'), findsOneWidget);
      expect(getRunCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(
  Future<http.Response> Function(http.Request) handler, {
  TextScaler? textScaler,
}) {
  final authService =
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
  return MaterialApp(
    home: RiderCourierRunsPage(
      repository: RiderRepository(authService: authService),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler ?? MediaQuery.of(context).textScaler),
      child: child!,
    ),
  );
}

Map<String, Object?> _emptyPayload() => {
  'data': <Object?>[],
  'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
};

Map<String, Object?> _pagePayload(String status, {String page = '1'}) => {
  'data': [
    _runPayload(
      status,
      runNo: page == '1' ? 'LH-TEST-1' : 'LH-TEST-2',
      id: page == '1' ? 41 : 42,
    ),
  ],
  'meta': {'current_page': int.parse(page), 'last_page': 2, 'total': 2},
};

Map<String, Object?> _runPayload(
  String status, {
  String runNo = 'LH-TEST-1',
  int id = 41,
}) => {
  'id': id,
  'run_no': runNo,
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
  'available_actions': status == 'assigned'
      ? [
          {'key': 'start_loading', 'label': 'Start loading'},
        ]
      : status == 'loading'
      ? [
          {'key': 'loaded', 'label': 'Confirm all cargo loaded'},
        ]
      : <Object?>[],
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
