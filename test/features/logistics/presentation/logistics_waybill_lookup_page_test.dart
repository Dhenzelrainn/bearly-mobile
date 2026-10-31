import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_waybill_lookup_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_waybill_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'manual waybill lookup displays only server returned read-only data',
    (tester) async {
      final requests = <http.Request>[];
      final auth = _authService((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_lookup()), 200);
      });

      await tester.pumpWidget(_app(auth));
      await tester.enterText(
        find.byKey(const ValueKey('logistics-waybill-input')),
        'BRLY-L2-001',
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.path,
        '/api/mobile/logistics/waybills/BRLY-L2-001',
      );
      expect(
        requests.single.headers['authorization'],
        'Bearer logistics-test-token',
      );
      expect(
        find.byKey(const ValueKey('logistics-waybill-result')),
        findsOneWidget,
      );
      expect(find.text('SHP-L2-001'), findsOneWidget);
      expect(find.text('Out For Delivery'), findsWidgets);
      expect(
        find.textContaining('Last recorded at Victoria Sorting Center'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Center intake is historical'),
        findsOneWidget,
      );
      expect(
        find.textContaining('return to the Sorting Center'),
        findsOneWidget,
      );
      expect(find.text('Receive Parcel'), findsNothing);
      expect(find.text('Accept Handoff'), findsNothing);
      expect(find.text('Mark Sorted'), findsNothing);
      expect(find.text('Dispatch'), findsNothing);
    },
  );

  testWidgets(
    'camera scan preserves the exact value and requires explicit lookup',
    (tester) async {
      var requests = 0;
      final auth = _authService((_) async {
        requests++;
        return http.Response(jsonEncode(_lookup()), 200);
      });

      await tester.pumpWidget(
        _app(
          auth,
          scannerPreviewBuilder: (context, callbacks) => Center(
            child: ElevatedButton(
              key: const ValueKey('emit-duplicate-scans'),
              onPressed: () {
                callbacks.onBarcodeDetected('brly-CaseSensitive-01');
                callbacks.onBarcodeDetected('BRLY-WRONG-SECOND-SCAN');
              },
              child: const Text('Simulate barcode'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('logistics-scan-waybill')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emit-duplicate-scans')));
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('logistics-waybill-input')),
      );
      expect(input.controller!.text, 'brly-CaseSensitive-01');
      expect(requests, 0);

      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();
      expect(requests, 1);
    },
  );

  testWidgets(
    'camera-scanned receipt remains explicit and records camera method',
    (tester) async {
      final requests = <http.Request>[];
      final auth = _authService((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {'scan_method': 'camera'});
          return http.Response(jsonEncode(_receiptResponse()), 200);
        }
        return http.Response(jsonEncode(_lookup(receiptEligible: true)), 200);
      });

      await tester.pumpWidget(
        _app(
          auth,
          receiptEnabled: true,
          scannerPreviewBuilder: (context, callbacks) => Center(
            child: ElevatedButton(
              key: const ValueKey('emit-receipt-scan'),
              onPressed: () => callbacks.onBarcodeDetected('BRLY-L2-001'),
              child: const Text('Simulate barcode'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('logistics-scan-waybill')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emit-receipt-scan')));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);

      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.method), ['GET']);
      final confirmButton = find.byKey(
        const ValueKey('logistics-confirm-receipt'),
      );
      await tester.ensureVisible(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-receipt-confirm-dialog')),
      );
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
    },
  );

  testWidgets('empty manual lookup is rejected locally without a request', (
    tester,
  ) async {
    var requests = 0;
    final auth = _authService((_) async {
      requests++;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(_app(auth));
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(
      find.text('Enter or scan a waybill before looking it up.'),
      findsOneWidget,
    );
  });

  testWidgets('not-found response does not disclose another provider parcel', (
    tester,
  ) async {
    final auth = _authService(
      (_) async => http.Response('{"message":"Not found"}', 404),
    );

    await tester.pumpWidget(_app(auth));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-PRIVATE',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No parcel with that waybill is available to your Logistics account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('invalid, unauthorized, and server errors show clear states', (
    tester,
  ) async {
    for (final scenario in [
      (422, 'Enter a valid waybill or barcode value and try again.'),
      (403, 'This Logistics account cannot perform waybill lookups right now.'),
      (503, 'The server could not complete the lookup. Try again shortly.'),
    ]) {
      final auth = _authService(
        (_) async => http.Response('{"message":"Unavailable"}', scenario.$1),
      );

      await tester.pumpWidget(_app(auth));
      await tester.enterText(
        find.byKey(const ValueKey('logistics-waybill-input')),
        'BRLY-TEST',
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();
      expect(find.text(scenario.$2), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('transport errors show retryable network state', (tester) async {
    final auth = _authService((_) async {
      throw http.ClientException('offline');
    });

    await tester.pumpWidget(_app(auth));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-NETWORK',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not reach Bearly. Check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('camera permission error returns to manual entry', (
    tester,
  ) async {
    final auth = _authService((_) async => http.Response('{}', 404));

    await tester.pumpWidget(
      _app(
        auth,
        scannerPreviewBuilder: (context, callbacks) => Center(
          child: ElevatedButton(
            onPressed: () =>
                callbacks.onCameraError('Camera permission was denied.'),
            child: const Text('Deny camera'),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-MANUAL-KEEP',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-scan-waybill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deny camera'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Camera permission was denied'), findsOneWidget);
    await tester.tap(find.text('Return to manual entry'));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('logistics-waybill-input')),
    );
    expect(input.controller!.text, 'BRLY-MANUAL-KEEP');
    expect(find.text('Read-only parcel lookup'), findsOneWidget);
  });

  testWidgets('pending request disables lookup until its response completes', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;
    final auth = _authService((_) {
      requests++;
      return response.future;
    });

    await tester.pumpWidget(_app(auth));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-SLOW',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('logistics-lookup-waybill')),
    );
    expect(button.onPressed, isNull);
    expect(requests, 1);

    response.complete(http.Response(jsonEncode(_lookup()), 200));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(
      find.byKey(const ValueKey('logistics-waybill-result')),
      findsOneWidget,
    );
  });

  testWidgets(
    'eligible receipt requires confirmation and refreshes server state',
    (tester) async {
      final requests = <http.Request>[];
      var lookupCount = 0;
      final auth = _authService((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/mobile/logistics/waybills/BRLY-L2-001/receive',
          );
          expect(
            request.headers['authorization'],
            'Bearer logistics-test-token',
          );
          expect(jsonDecode(request.body), {'scan_method': 'manual'});
          return http.Response(jsonEncode(_receiptResponse()), 200);
        }
        lookupCount++;
        return http.Response(
          jsonEncode(
            _lookup(
              receiptEligible: lookupCount == 1,
              parcelStatus: lookupCount == 1 ? 'picked_up' : 'received',
              shipmentStatus: lookupCount == 1
                  ? 'picked_up'
                  : 'at_sorting_center',
              receiptCode: lookupCount == 1 ? 'eligible' : 'already_received',
            ),
          ),
          200,
        );
      });

      await tester.pumpWidget(_app(auth, receiptEnabled: true));
      await tester.enterText(
        find.byKey(const ValueKey('logistics-waybill-input')),
        'BRLY-L2-001',
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();

      expect(find.text('Victoria Sorting Center (SC-3)'), findsOneWidget);
      final confirmButton = find.byKey(
        const ValueKey('logistics-confirm-receipt'),
      );
      await tester.ensureVisible(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(find.text('Confirm incoming parcel receipt'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('logistics-receipt-confirm-dialog')),
      );
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(
        find.text(
          'The server confirms this parcel was received at the Sorting Center.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logistics-confirm-receipt')),
        findsNothing,
      );
    },
  );

  testWidgets('canceling receipt confirmation sends no mutation', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = _authService((request) async {
      requests.add(request);
      return http.Response(jsonEncode(_lookup(receiptEligible: true)), 200);
    });

    await tester.pumpWidget(_app(auth, receiptEnabled: true));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-L2-001',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();
    final confirmButton = find.byKey(
      const ValueKey('logistics-confirm-receipt'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logistics-receipt-cancel')));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(
      find.byKey(const ValueKey('logistics-confirm-receipt')),
      findsOneWidget,
    );
  });

  testWidgets('ineligible parcels never show an actionable receipt button', (
    tester,
  ) async {
    final auth = _authService(
      (_) async => http.Response(jsonEncode(_lookup()), 200),
    );
    await tester.pumpWidget(_app(auth, receiptEnabled: true));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-L2-001',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Receipt'), findsNothing);
    expect(
      find.textContaining('not eligible for ordinary receipt'),
      findsOneWidget,
    );
  });

  testWidgets('uncertain receipt requires a fresh lookup before another post', (
    tester,
  ) async {
    var getRequests = 0;
    var postRequests = 0;
    final auth = _authService((request) async {
      if (request.method == 'POST') {
        postRequests++;
        throw http.ClientException('connection lost after send');
      }
      getRequests++;
      return http.Response(jsonEncode(_lookup(receiptEligible: true)), 200);
    });

    await tester.pumpWidget(_app(auth, receiptEnabled: true));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-L2-001',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();
    final confirmButton = find.byKey(
      const ValueKey('logistics-confirm-receipt'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-receipt-confirm-dialog')),
    );
    await tester.pumpAndSettle();

    expect(getRequests, 1);
    expect(postRequests, 1);
    expect(find.textContaining('result is uncertain'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('logistics-confirm-receipt')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();

    expect(getRequests, 2);
    expect(postRequests, 1);
    expect(
      find.byKey(const ValueKey('logistics-confirm-receipt')),
      findsOneWidget,
    );
  });

  testWidgets('receipt button disables while the mutation is pending', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var postRequests = 0;
    final auth = _authService((request) async {
      if (request.method == 'POST') {
        postRequests++;
        return response.future;
      }
      return http.Response(jsonEncode(_lookup(receiptEligible: true)), 200);
    });

    await tester.pumpWidget(_app(auth, receiptEnabled: true));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-L2-001',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();
    final confirmButton = find.byKey(
      const ValueKey('logistics-confirm-receipt'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-receipt-confirm-dialog')),
    );
    await tester.pump();

    final pendingButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('logistics-confirm-receipt')),
    );
    expect(pendingButton.onPressed, isNull);
    expect(postRequests, 1);

    response.complete(http.Response(jsonEncode(_receiptResponse()), 200));
    await tester.pumpAndSettle();
    expect(postRequests, 1);
  });

  testWidgets(
    'receipt conflicts, validation, and authorization errors are clear',
    (tester) async {
      for (final scenario in [
        (409, 'The server reports a parcel state conflict.'),
        (422, 'The receipt request was invalid.'),
        (403, 'This Logistics account cannot receive parcels right now.'),
      ]) {
        var posts = 0;
        final auth = _authService((request) async {
          if (request.method == 'POST') {
            posts++;
            return http.Response('{"message":"Rejected"}', scenario.$1);
          }
          return http.Response(jsonEncode(_lookup(receiptEligible: true)), 200);
        });

        await tester.pumpWidget(_app(auth, receiptEnabled: true));
        await tester.enterText(
          find.byKey(const ValueKey('logistics-waybill-input')),
          'BRLY-L2-001',
        );
        await tester.tap(
          find.byKey(const ValueKey('logistics-lookup-waybill')),
        );
        await tester.pumpAndSettle();
        final confirmButton = find.byKey(
          const ValueKey('logistics-confirm-receipt'),
        );
        await tester.ensureVisible(confirmButton);
        await tester.pumpAndSettle();
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('logistics-receipt-confirm-dialog')),
        );
        await tester.pumpAndSettle();

        expect(posts, 1);
        expect(find.textContaining(scenario.$2), findsOneWidget);
        if (scenario.$1 == 409) {
          expect(
            find.byKey(const ValueKey('logistics-confirm-receipt')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('logistics-lookup-waybill')),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'receipt timeout is uncertain and requires lookup reconciliation',
    (tester) async {
      var posts = 0;
      var gets = 0;
      final auth = _authService((request) async {
        if (request.method == 'POST') {
          posts++;
          throw TimeoutException('timed out');
        }
        gets++;
        return http.Response(jsonEncode(_lookup(receiptEligible: true)), 200);
      });

      await tester.pumpWidget(_app(auth, receiptEnabled: true));
      await tester.enterText(
        find.byKey(const ValueKey('logistics-waybill-input')),
        'BRLY-L2-001',
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();
      final confirmButton = find.byKey(
        const ValueKey('logistics-confirm-receipt'),
      );
      await tester.ensureVisible(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-receipt-confirm-dialog')),
      );
      await tester.pumpAndSettle();

      expect(posts, 1);
      expect(gets, 1);
      expect(find.textContaining('result is uncertain'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('logistics-confirm-receipt')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();
      expect(gets, 2);
      expect(posts, 1);
      expect(
        find.byKey(const ValueKey('logistics-confirm-receipt')),
        findsOneWidget,
      );
    },
  );
}

Widget _app(
  AuthService auth, {
  WaybillScannerPreviewBuilder? scannerPreviewBuilder,
  bool receiptEnabled = false,
}) => MaterialApp(
  home: LogisticsWaybillLookupPage(
    repository: LogisticsRepository(authService: auth),
    scannerPreviewBuilder: scannerPreviewBuilder,
    receiptEnabled: receiptEnabled,
  ),
);

Map<String, Object?> _lookup({
  bool receiptEligible = false,
  String parcelStatus = 'out_for_delivery',
  String shipmentStatus = 'out_for_delivery',
  String receiptCode = 'invalid_state',
}) => {
  'data': {
    'waybill': 'BRLY-L2-001',
    'shipment': {
      'reference': 'SHP-L2-001',
      'status': shipmentStatus,
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
    'receiving_sorting_center': {
      'id': 3,
      'name': 'Victoria Sorting Center',
      'code': 'SC-3',
      'status': 'active',
      'address': 'Victoria, Laguna',
    },
    'receipt_eligibility': {
      'eligible': receiptEligible,
      'code': receiptCode,
      'message': receiptEligible
          ? 'Eligible for ordinary receipt at this Sorting Center.'
          : 'This parcel is not eligible for ordinary receipt in its current state.',
    },
    'handoff': null,
    'parcels': [
      {
        'reference': 'PCL-L2-001',
        'status': parcelStatus,
        'terminal': false,
        'current_sorting_center': null,
        'last_recorded_center': {
          'id': 3,
          'name': 'Victoria Sorting Center',
          'code': 'SC-3',
          'status': 'active',
          'address': 'Victoria, Laguna',
        },
        'center_intake_recorded_at': '2026-10-30T10:00:00Z',
      },
    ],
    'terminal': false,
    'next_step_guidance': {
      'eligibility': 'requires_confirmation',
      'message':
          'Verify any physical return to the Sorting Center before intake.',
    },
  },
};

Map<String, Object?> _receiptResponse() => {
  'message': 'Parcel received at sorting center.',
  'data': {
    'waybill': 'BRLY-L2-001',
    'shipment': {'reference': 'SHP-L2-001', 'status': 'at_sorting_center'},
    'receiving_sorting_center': {
      'id': 3,
      'name': 'Victoria Sorting Center',
      'code': 'SC-3',
      'status': 'active',
      'address': 'Victoria, Laguna',
    },
    'parcels': [
      {
        'reference': 'PCL-L2-001',
        'status': 'received',
        'current_sorting_center': {
          'id': 3,
          'name': 'Victoria Sorting Center',
          'code': 'SC-3',
          'status': 'active',
          'address': 'Victoria, Laguna',
        },
      },
    ],
  },
};

AuthService _authService(
  Future<http.Response> Function(http.Request) handler,
) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8012'),
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
