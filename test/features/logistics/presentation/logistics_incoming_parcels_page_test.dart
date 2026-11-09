import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_incoming_parcels_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_waybill_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('dashboard opens the Incoming Parcels workspace', (tester) async {
    final paths = <String>[];
    final auth = _auth((request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode(
          request.url.path == '/api/mobile/logistics/dashboard'
              ? _dashboard
              : _pageResponse(),
        ),
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
    await tester.tap(
      find.byKey(const ValueKey('logistics-open-incoming-parcels')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incoming Parcels'), findsOneWidget);
    expect(
      find.text('No incoming parcels match these filters.'),
      findsOneWidget,
    );
    expect(paths, contains('/api/mobile/logistics/incoming-parcels'));
  });

  testWidgets('dashboard intake action opens the single-parcel workspace', (
    tester,
  ) async {
    final auth = _auth((request) async {
      return http.Response(
        jsonEncode(
          request.url.path == '/api/mobile/logistics/dashboard'
              ? _dashboard
              : _pageResponse(),
        ),
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
    await tester.tap(
      find.byKey(const ValueKey('logistics-open-incoming-receipt')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incoming Parcels'), findsOneWidget);
    expect(find.text('Receive one parcel'), findsNothing);
  });

  testWidgets(
    'shows loading and empty states and refreshes with pull gesture',
    (tester) async {
      final response = Completer<http.Response>();
      var requests = 0;
      final auth = _auth((request) async {
        requests++;
        if (requests == 1) return response.future;
        return http.Response(jsonEncode(_pageResponse()), 200);
      });

      await tester.pumpWidget(_page(auth));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      response.complete(http.Response(jsonEncode(_pageResponse()), 200));
      await tester.pumpAndSettle();
      expect(
        find.text('No incoming parcels match these filters.'),
        findsOneWidget,
      );

      await tester.drag(find.byType(ListView).last, const Offset(0, 260));
      await tester.pumpAndSettle();
      expect(requests, 2);
    },
  );

  testWidgets('shows an error state and retries the list request', (
    tester,
  ) async {
    var requests = 0;
    final auth = _auth((request) async {
      requests++;
      if (requests == 1) {
        return http.Response(jsonEncode({'message': 'unavailable'}), 503);
      }
      return http.Response(jsonEncode(_pageResponse()), 200);
    });

    await tester.pumpWidget(_page(auth));
    await tester.pumpAndSettle();
    expect(
      find.text('Incoming parcels could not be loaded. Try again shortly.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(
      find.text('No incoming parcels match these filters.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'applies Web intake status filters and displays parcel summaries',
    (tester) async {
      final queries = <Map<String, String>>[];
      final auth = _auth((request) async {
        if (request.url.path == '/api/mobile/logistics/incoming-parcels') {
          queries.add(request.url.queryParameters);
          return http.Response(
            jsonEncode(_pageResponse(parcels: [_parcel()])),
            200,
          );
        }
        return http.Response(jsonEncode(_dashboard), 200);
      });

      await tester.pumpWidget(_page(auth));
      await tester.pumpAndSettle();
      expect(find.text('BRLY-L10-001'), findsOneWidget);
      expect(find.textContaining('1 of 3 pieces received'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('logistics-incoming-status-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Awaiting Intake').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-incoming-apply-filters')),
      );
      await tester.pumpAndSettle();

      expect(queries.last['status'], 'awaiting_intake');
      expect(find.text('BRLY-L10-001'), findsOneWidget);
      expect(find.textContaining('North Shop'), findsOneWidget);
      expect(find.textContaining('San Pablo City, Laguna'), findsOneWidget);
    },
  );

  testWidgets('details include history and the scanner stays read-only', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _auth((request) async {
      requests.add(request);
      if (request.url.path == '/api/mobile/logistics/incoming-parcels') {
        return http.Response(
          jsonEncode(_pageResponse(parcels: [_parcel()])),
          200,
        );
      }
      if (request.url.path ==
          '/api/mobile/logistics/incoming-parcels/BRLY-L10-001') {
        return http.Response(jsonEncode(_detailResponse), 200);
      }
      if (request.url.path == '/api/mobile/logistics/waybills/BRLY-L10-001') {
        return http.Response(jsonEncode(_waybillLookup), 200);
      }
      throw StateError('Unexpected request ${request.url}');
    });

    await tester.pumpWidget(_page(auth));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('incoming-parcel-BRLY-L10-001')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 of 3 pieces received'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Parcel pieces'), findsOneWidget);
    expect(find.text('Received at Sorting Center'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('logistics-incoming-open-readonly-scanner')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read-only parcel lookup'), findsOneWidget);
    expect(find.text('Confirm incoming parcel receipt'), findsNothing);
    expect(find.text('Accept incoming city handoff'), findsNothing);
    final waybillInput = tester.widget<TextField>(
      find.byKey(const ValueKey('logistics-waybill-input')),
    );
    expect(waybillInput.controller?.text, 'BRLY-L10-001');
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET', 'GET', 'GET']);
    expect(find.textContaining('Pila'), findsOneWidget);
  });

  testWidgets(
    'receives exactly the scanned parcel after server eligibility and confirmation',
    (tester) async {
      final requests = <http.Request>[];
      var received = false;
      final auth = _auth((request) async {
        requests.add(request);
        if (request.url.path == '/api/mobile/logistics/incoming-parcels') {
          return http.Response(
            jsonEncode(_pageResponse(parcels: [_parcel()])),
            200,
          );
        }
        if (request.url.path.endsWith('/receive')) {
          received = true;
          return http.Response(jsonEncode(_receiptResponse), 200);
        }
        if (request.url.path ==
            '/api/mobile/logistics/incoming-parcels/BRLY-L10-001') {
          return http.Response(
            jsonEncode(_intakeDetailResponse(received: received)),
            200,
          );
        }
        throw StateError('Unexpected request ${request.url}');
      });

      await tester.pumpWidget(_page(auth));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('incoming-parcel-BRLY-L10-001')),
      );
      await tester.pumpAndSettle();

      final barcode = find.byKey(
        const ValueKey('logistics-piece-barcode-input'),
      );
      await tester.ensureVisible(barcode);
      await tester.enterText(barcode, 'PCL-L10-002');
      await tester.tap(
        find.byKey(const ValueKey('logistics-select-piece-barcode')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Selected piece 2: PCL-L10-002.'), findsOneWidget);
      expect(
        find.text('Eligible for ordinary receipt at this Sorting Center.'),
        findsOneWidget,
      );

      final sizeField = find.byKey(
        const ValueKey('logistics-piece-size-class'),
      );
      await tester.ensureVisible(sizeField);
      await tester.tap(sizeField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Small').last);
      await tester.pumpAndSettle();
      final confirm = find.byKey(
        const ValueKey('logistics-confirm-piece-intake'),
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-piece-receipt-confirm-dialog')),
      );
      await tester.pumpAndSettle();

      final post = requests.singleWhere((request) => request.method == 'POST');
      expect(
        post.url.path,
        '/api/mobile/logistics/incoming-parcels/BRLY-L10-001/pieces/PCL-L10-002/receive',
      );
      expect(jsonDecode(post.body), {
        'scan_method': 'manual',
        'size_class': 'small',
      });
      expect(requests.map((request) => request.method), [
        'GET',
        'GET',
        'POST',
        'GET',
      ]);
      await tester.drag(find.byType(ListView).last, const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 pieces received · 1 remaining'), findsOneWidget);
      expect(find.text('0 of 2 pieces received · 2 remaining'), findsNothing);
      await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bearly confirmed intake for PCL-L10-002'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manual barcode must exactly match a piece before intake actions appear',
    (tester) async {
      final auth = _auth((request) async {
        if (request.url.path == '/api/mobile/logistics/incoming-parcels') {
          return http.Response(
            jsonEncode(_pageResponse(parcels: [_parcel()])),
            200,
          );
        }
        return http.Response(jsonEncode(_intakeDetailResponse()), 200);
      });

      await tester.pumpWidget(_page(auth));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('incoming-parcel-BRLY-L10-001')),
      );
      await tester.pumpAndSettle();
      final barcode = find.byKey(
        const ValueKey('logistics-piece-barcode-input'),
      );
      await tester.ensureVisible(barcode);
      await tester.enterText(barcode, 'PCL-WRONG');
      await tester.tap(
        find.byKey(const ValueKey('logistics-select-piece-barcode')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No Parcel in this Waybill matches that exact barcode.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logistics-piece-size-class')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('logistics-confirm-piece-intake')),
        findsNothing,
      );
    },
  );

  testWidgets('individual camera scan selects the exact server-listed parcel', (
    tester,
  ) async {
    final methods = <String>[];
    final auth = _auth((request) async {
      methods.add(request.method);
      if (request.url.path == '/api/mobile/logistics/incoming-parcels') {
        return http.Response(
          jsonEncode(_pageResponse(parcels: [_parcel()])),
          200,
        );
      }
      return http.Response(jsonEncode(_intakeDetailResponse()), 200);
    });

    await tester.pumpWidget(
      _page(
        auth,
        scannerPreviewBuilder: (context, callbacks) => Center(
          child: ElevatedButton(
            key: const ValueKey('emit-piece-scan'),
            onPressed: () => callbacks.onBarcodeDetected('PCL-L10-002'),
            child: const Text('Simulate parcel barcode'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('incoming-parcel-BRLY-L10-001')),
    );
    await tester.pumpAndSettle();
    final scan = find.byKey(const ValueKey('logistics-scan-piece-barcode'));
    await tester.ensureVisible(scan);
    await tester.tap(scan);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emit-piece-scan')));
    await tester.pumpAndSettle();

    expect(find.text('Selected piece 2: PCL-L10-002.'), findsOneWidget);
    expect(methods, ['GET', 'GET']);
  });

  testWidgets('pending single-piece intake disables repeat submission', (
    tester,
  ) async {
    final receiptResponse = Completer<http.Response>();
    var posts = 0;
    var received = false;
    final auth = _auth((request) async {
      if (request.url.path == '/api/mobile/logistics/incoming-parcels') {
        return http.Response(
          jsonEncode(_pageResponse(parcels: [_parcel()])),
          200,
        );
      }
      if (request.method == 'POST') {
        posts++;
        received = true;
        return receiptResponse.future;
      }
      return http.Response(
        jsonEncode(_intakeDetailResponse(received: received)),
        200,
      );
    });

    await tester.pumpWidget(_page(auth));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('incoming-parcel-BRLY-L10-001')),
    );
    await tester.pumpAndSettle();
    final barcode = find.byKey(const ValueKey('logistics-piece-barcode-input'));
    await tester.ensureVisible(barcode);
    await tester.enterText(barcode, 'PCL-L10-002');
    await tester.tap(
      find.byKey(const ValueKey('logistics-select-piece-barcode')),
    );
    await tester.pumpAndSettle();
    final sizeClass = find.byKey(const ValueKey('logistics-piece-size-class'));
    await tester.ensureVisible(sizeClass);
    await tester.tap(sizeClass);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Small').last);
    await tester.pumpAndSettle();
    final confirm = find.byKey(
      const ValueKey('logistics-confirm-piece-intake'),
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-piece-receipt-confirm-dialog')),
    );
    await tester.pump();

    expect(posts, 1);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(confirm);
    await tester.pump();
    expect(posts, 1);

    receiptResponse.complete(http.Response(jsonEncode(_receiptResponse), 200));
    await tester.pumpAndSettle();
    expect(posts, 1);
  });

  testWidgets(
    'server-ineligible parcel shows its reason without intake controls',
    (tester) async {
      final auth = _auth((request) async {
        if (request.url.path == '/api/mobile/logistics/incoming-parcels') {
          return http.Response(
            jsonEncode(_pageResponse(parcels: [_parcel()])),
            200,
          );
        }
        return http.Response(
          jsonEncode(_intakeDetailResponse(received: true)),
          200,
        );
      });

      await tester.pumpWidget(_page(auth));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('incoming-parcel-BRLY-L10-001')),
      );
      await tester.pumpAndSettle();
      final barcode = find.byKey(
        const ValueKey('logistics-piece-barcode-input'),
      );
      await tester.ensureVisible(barcode);
      await tester.enterText(barcode, 'PCL-L10-002');
      await tester.tap(
        find.byKey(const ValueKey('logistics-select-piece-barcode')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This parcel has already been received at a Sorting Center.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logistics-piece-size-class')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('logistics-confirm-piece-intake')),
        findsNothing,
      );
    },
  );
}

Widget _page(
  AuthService auth, {
  WaybillScannerPreviewBuilder? scannerPreviewBuilder,
}) => MaterialApp(
  home: LogisticsIncomingParcelsPage(
    repository: LogisticsRepository(authService: auth),
    scannerPreviewBuilder: scannerPreviewBuilder,
  ),
);

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

Map<String, Object?> _pageResponse({
  List<Map<String, Object?>> parcels = const [],
}) => {
  'data': {
    'provider': {'id': 3, 'name': 'Victoria Logistics'},
    'parcels': parcels,
    'pagination': {
      'current_page': 1,
      'last_page': 1,
      'per_page': 20,
      'total': parcels.length,
    },
    'filters': {'status': null, 'search': null, 'destination': null},
  },
};

Map<String, Object?> _parcel() => {
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
  'current_sorting_centers': [],
  'parcel_statuses': ['picked_up', 'received'],
};

final _detailResponse = {
  'data': {
    'parcel': _parcel(),
    'pieces': [
      {
        'parcel': 'PCL-L10-001',
        'piece_sequence': 1,
        'status': 'received',
        'weight_kg': '1.0',
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

Map<String, Object?> _intakeDetailResponse({bool received = false}) => {
  'data': {
    'parcel': {
      'waybill': 'BRLY-L10-001',
      'shipment_reference': 'SHP-L10-001',
      'shipment_status': received ? 'picked_up' : 'picked_up',
      'purpose': 'outbound',
      'purpose_label': 'Buyer delivery',
      'status': received ? 'received' : 'awaiting_intake',
      'expected_piece_count': 2,
      'parcel_record_count': 2,
      'received_piece_count': received ? 1 : 0,
      'remaining_piece_count': received ? 1 : 2,
      'received_at': received ? '2026-11-09T08:00:00Z' : null,
      'seller': 'North Shop',
      'received_from': 'Rider A',
      'destination': 'San Pablo City, Laguna',
      'current_sorting_centers': [],
      'parcel_statuses': received
          ? ['created', 'received']
          : ['picked_up', 'created'],
    },
    'receiving_sorting_center': {
      'id': 3,
      'name': 'Victoria Center',
      'code': 'SC-VIC-3',
      'status': 'active',
    },
    'size_classes': ['small', 'bulky'],
    'pieces': [
      {
        'parcel': 'PCL-L10-001',
        'piece_sequence': 1,
        'status': received ? 'picked_up' : 'picked_up',
        'weight_kg': '1.0',
        'size_class': null,
        'receipt_eligibility': {
          'eligible': !received,
          'code': received ? 'eligible' : 'eligible',
          'message': 'Eligible for ordinary receipt at this Sorting Center.',
        },
        'current_sorting_center': null,
        'intake_history': [],
      },
      {
        'parcel': 'PCL-L10-002',
        'piece_sequence': 2,
        'status': received ? 'received' : 'created',
        'weight_kg': '2.0',
        'size_class': received ? 'small' : null,
        'receipt_eligibility': {
          'eligible': !received,
          'code': received ? 'already_received' : 'eligible',
          'message': received
              ? 'This parcel has already been received at a Sorting Center.'
              : 'Eligible for ordinary receipt at this Sorting Center.',
        },
        'current_sorting_center': received
            ? {
                'id': 3,
                'name': 'Victoria Center',
                'code': 'SC-VIC-3',
                'status': 'active',
              }
            : null,
        'intake_history': received
            ? [
                {
                  'event': 'received_at_center',
                  'from_status': 'created',
                  'to_status': 'received',
                  'scan_method': 'manual',
                  'occurred_at': '2026-11-09T08:00:00Z',
                  'sorting_center': {
                    'name': 'Victoria Center',
                    'code': 'SC-VIC-3',
                  },
                },
              ]
            : [],
      },
    ],
  },
};

const _receiptResponse = {
  'data': {
    'waybill': {
      'waybill': 'BRLY-L10-001',
      'shipment_reference': 'SHP-L10-001',
      'shipment_status': 'picked_up',
      'purpose': 'outbound',
      'purpose_label': 'Buyer delivery',
      'status': 'received',
      'expected_piece_count': 2,
      'parcel_record_count': 2,
      'received_piece_count': 1,
      'remaining_piece_count': 1,
      'received_at': '2026-11-09T08:00:00Z',
      'seller': 'North Shop',
      'received_from': 'Rider A',
      'destination': 'San Pablo City, Laguna',
      'current_sorting_centers': [],
      'parcel_statuses': ['created', 'received'],
    },
    'piece': {
      'parcel': 'PCL-L10-002',
      'piece_sequence': 2,
      'status': 'received',
      'weight_kg': '2.0',
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
          'from_status': 'created',
          'to_status': 'received',
          'scan_method': 'manual',
          'occurred_at': '2026-11-09T08:00:00Z',
          'sorting_center': {'name': 'Victoria Center', 'code': 'SC-VIC-3'},
        },
      ],
    },
    'receipt_evidence': {
      'event': 'received_at_center',
      'from_status': 'created',
      'to_status': 'received',
      'scan_method': 'manual',
      'occurred_at': '2026-11-09T08:00:00Z',
      'sorting_center': {'name': 'Victoria Center', 'code': 'SC-VIC-3'},
    },
  },
};

const _waybillLookup = {
  'data': {
    'waybill': 'BRLY-L10-001',
    'shipment': {
      'reference': 'SHP-L10-001',
      'status': 'picked_up',
      'purpose': 'outbound',
    },
    'destination': {
      'barangay': 'San Rafael',
      'city': 'Pila',
      'province': 'Laguna',
    },
    'logistics_provider': {'id': 3, 'name': 'Victoria Logistics'},
    'receiving_logistics_provider': {
      'id': 3,
      'name': 'Victoria Logistics',
      'status': 'active',
    },
    'current_sorting_center': null,
    'receiving_sorting_center': null,
    'receipt_eligibility': {
      'eligible': false,
      'code': 'invalid_state',
      'message': 'Review current parcel status.',
    },
    'handoff_acceptance_eligibility': {
      'eligible': false,
      'code': 'not_pending',
      'message': 'There is no incoming handoff for this waybill.',
    },
    'handoff': null,
    'parcels': [
      {
        'reference': 'PCL-L10-001',
        'status': 'picked_up',
        'terminal': false,
        'current_sorting_center': null,
        'last_recorded_center': null,
        'center_intake_recorded_at': null,
        'products': [],
      },
    ],
    'terminal': false,
    'next_step_guidance': {
      'eligibility': 'requires_confirmation',
      'message': 'Check current parcel status before taking any action.',
    },
  },
};

const _dashboard = {
  'data': {
    'provider': {'id': 3, 'name': 'Victoria Logistics', 'status': 'active'},
    'sorting_center': {
      'id': 3,
      'name': 'Victoria Center',
      'code': 'SC-VIC-3',
      'status': 'active',
      'address': 'Victoria, Laguna',
    },
    'setup_required': false,
    'metrics': {
      'received_today': 0,
      'awaiting_sorting': 0,
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
