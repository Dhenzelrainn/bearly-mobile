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
    'manual handoff acceptance requires explicit confirmation and refreshes server state',
    (tester) async {
      final requests = <http.Request>[];
      var lookups = 0;
      final auth = _authService((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {'scan_method': 'manual'});
          return http.Response(
            jsonEncode(_handoffResponse('BRLY-L3B-001')),
            200,
          );
        }
        lookups++;
        return http.Response(
          jsonEncode(
            _lookup(
              waybill: 'BRLY-L3B-001',
              handoffEligible: lookups == 1,
              handoffStatus: lookups == 1 ? 'sent' : 'accepted',
              handoffEligibilityCode: lookups == 1
                  ? 'eligible'
                  : 'already_accepted',
              hasHandoff: true,
              logisticsProviderName: 'Victoria Logistics',
              receivingProviderName: 'Pila Logistics',
              receivingCenterName: 'Pila Sorting Center',
              receivingCenterCode: 'SC-PILA',
            ),
          ),
          200,
        );
      });

      await tester.pumpWidget(_app(auth, handoffEnabled: true));
      await tester.enterText(
        find.byKey(const ValueKey('logistics-waybill-input')),
        'BRLY-L3B-001',
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET']);
      expect(find.text('Victoria Logistics'), findsWidgets);
      expect(find.text('Waybill Snapshot Bear'), findsOneWidget);
      expect(find.text('Pila Logistics'), findsWidgets);
      expect(find.text('Pila Sorting Center (SC-PILA)'), findsOneWidget);
      final accept = find.byKey(const ValueKey('logistics-confirm-handoff'));
      expect(accept, findsOneWidget);
      await tester.ensureVisible(accept);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET']);
      expect(
        find.byKey(const ValueKey('logistics-handoff-confirm-dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('BRLY-L3B-001'), findsWidgets);
      await tester.tap(
        find.byKey(const ValueKey('logistics-handoff-confirm-dialog')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(
        requests[1].url.path,
        '/api/mobile/logistics/waybills/BRLY-L3B-001/accept-handoff',
      );
      expect(
        requests[1].headers['authorization'],
        'Bearer logistics-test-token',
      );
      expect(find.text('Accepted'), findsWidgets);
      expect(
        find.textContaining('server confirms this handoff was accepted'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logistics-confirm-handoff')),
        findsNothing,
      );
    },
  );

  testWidgets('camera-scanned handoff records camera scan method', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var lookups = 0;
    final auth = _authService((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {'scan_method': 'camera'});
        return http.Response(
          jsonEncode(_handoffResponse('BRLY-L3B-CAMERA')),
          200,
        );
      }
      lookups++;
      return http.Response(
        jsonEncode(
          _lookup(
            waybill: 'BRLY-L3B-CAMERA',
            handoffEligible: lookups == 1,
            handoffStatus: lookups == 1 ? 'sent' : 'accepted',
            handoffEligibilityCode: lookups == 1
                ? 'eligible'
                : 'already_accepted',
            hasHandoff: true,
            logisticsProviderName: 'Victoria Logistics',
            receivingProviderName: 'Pila Logistics',
            receivingCenterName: 'Pila Sorting Center',
            receivingCenterCode: 'SC-PILA',
          ),
        ),
        200,
      );
    });

    await tester.pumpWidget(
      _app(
        auth,
        handoffEnabled: true,
        scannerPreviewBuilder: (context, callbacks) => Center(
          child: ElevatedButton(
            key: const ValueKey('emit-handoff-scan'),
            onPressed: () => callbacks.onBarcodeDetected('BRLY-L3B-CAMERA'),
            child: const Text('Simulate handoff scan'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('logistics-scan-waybill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emit-handoff-scan')));
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('logistics-waybill-input')),
          )
          .controller!
          .text,
      'BRLY-L3B-CAMERA',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();
    final accept = find.byKey(const ValueKey('logistics-confirm-handoff'));
    await tester.ensureVisible(accept);
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-handoff-confirm-dialog')),
    );
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
  });

  testWidgets('ineligible handoffs never expose the acceptance action', (
    tester,
  ) async {
    final auth = _authService(
      (_) async => http.Response(
        jsonEncode(
          _lookup(
            handoffEligible: false,
            handoffEligibilityCode: 'destination_zone_uncovered',
          ),
        ),
        200,
      ),
    );

    await tester.pumpWidget(_app(auth, handoffEnabled: true));
    await tester.enterText(
      find.byKey(const ValueKey('logistics-waybill-input')),
      'BRLY-L3B-UNCOVERED',
    );
    await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
    await tester.pumpAndSettle();

    expect(find.textContaining('no active zone covering'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('logistics-confirm-handoff')),
      findsNothing,
    );
  });

  testWidgets(
    'uncertain handoff response requires a fresh lookup before another submission',
    (tester) async {
      final requests = <http.Request>[];
      var lookups = 0;
      final auth = _authService((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response('server error', 500);
        }
        lookups++;
        return http.Response(
          jsonEncode(
            _lookup(
              waybill: 'BRLY-L3B-UNCERTAIN',
              handoffEligible: lookups == 1,
              handoffStatus: lookups == 1 ? 'sent' : 'accepted',
              handoffEligibilityCode: lookups == 1
                  ? 'eligible'
                  : 'already_accepted',
              hasHandoff: true,
              logisticsProviderName: 'Victoria Logistics',
              receivingProviderName: 'Pila Logistics',
              receivingCenterName: 'Pila Sorting Center',
              receivingCenterCode: 'SC-PILA',
            ),
          ),
          200,
        );
      });

      await tester.pumpWidget(_app(auth, handoffEnabled: true));
      await tester.enterText(
        find.byKey(const ValueKey('logistics-waybill-input')),
        'BRLY-L3B-UNCERTAIN',
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();
      final accept = find.byKey(const ValueKey('logistics-confirm-handoff'));
      await tester.ensureVisible(accept);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-handoff-confirm-dialog')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(
        find.textContaining('result is uncertain'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .join(' | '),
      );
      expect(
        find.byKey(const ValueKey('logistics-confirm-handoff')),
        findsNothing,
      );

      final refresh = find.byKey(const ValueKey('logistics-lookup-waybill'));
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(
        find.byKey(const ValueKey('logistics-confirm-handoff')),
        findsNothing,
      );
      expect(find.textContaining('already been accepted'), findsWidgets);
    },
  );

  testWidgets(
    'handoff confirmation prevents a second tap while POST is pending',
    (tester) async {
      final requests = <http.Request>[];
      final response = Completer<http.Response>();
      var lookup = 0;
      final auth = _authService((request) async {
        requests.add(request);
        if (request.method == 'POST') return response.future;
        lookup++;
        return http.Response(
          jsonEncode(
            _lookup(
              waybill: 'BRLY-L3B-PENDING',
              handoffEligible: lookup == 1,
              handoffStatus: lookup == 1 ? 'sent' : 'accepted',
              handoffEligibilityCode: lookup == 1
                  ? 'eligible'
                  : 'already_accepted',
              hasHandoff: true,
              logisticsProviderName: 'Victoria Logistics',
              receivingProviderName: 'Pila Logistics',
              receivingCenterName: 'Pila Sorting Center',
              receivingCenterCode: 'SC-PILA',
            ),
          ),
          200,
        );
      });

      await tester.pumpWidget(_app(auth, handoffEnabled: true));
      await tester.enterText(
        find.byKey(const ValueKey('logistics-waybill-input')),
        'BRLY-L3B-PENDING',
      );
      await tester.tap(find.byKey(const ValueKey('logistics-lookup-waybill')));
      await tester.pumpAndSettle();
      final accept = find.byKey(const ValueKey('logistics-confirm-handoff'));
      await tester.ensureVisible(accept);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-handoff-confirm-dialog')),
      );
      await tester.pump();
      await tester.pump();

      final pendingButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('logistics-confirm-handoff')),
      );
      expect(pendingButton.onPressed, isNull);
      expect(requests.map((request) => request.method), ['GET', 'POST']);

      response.complete(
        http.Response(jsonEncode(_handoffResponse('BRLY-L3B-PENDING')), 200),
      );
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
    },
  );

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
    'legacy receipt lookup is read-only and directs operators to parcel intake',
    (tester) async {
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

      expect(requests.map((request) => request.method), ['GET']);
      expect(
        find.textContaining('Waybill-wide receipt is retired'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logistics-confirm-receipt')),
        findsNothing,
      );
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

  testWidgets(
    'invalid, unauthorized, and server lookup errors show clear states',
    (tester) async {
      for (final scenario in [
        (422, 'Enter a valid waybill or barcode value and try again.'),
        (
          403,
          'This Logistics account cannot perform waybill lookups right now.',
        ),
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
        await tester.tap(
          find.byKey(const ValueKey('logistics-lookup-waybill')),
        );
        await tester.pumpAndSettle();
        expect(find.text(scenario.$2), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

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
}

Widget _app(
  AuthService auth, {
  WaybillScannerPreviewBuilder? scannerPreviewBuilder,
  bool receiptEnabled = false,
  bool handoffEnabled = false,
}) => MaterialApp(
  home: LogisticsWaybillLookupPage(
    repository: LogisticsRepository(authService: auth),
    scannerPreviewBuilder: scannerPreviewBuilder,
    receiptEnabled: receiptEnabled,
    handoffEnabled: handoffEnabled,
  ),
);

Map<String, Object?> _lookup({
  String waybill = 'BRLY-L2-001',
  bool receiptEligible = false,
  bool handoffEligible = false,
  String parcelStatus = 'out_for_delivery',
  String shipmentStatus = 'out_for_delivery',
  String receiptCode = 'invalid_state',
  String handoffEligibilityCode = 'not_pending',
  bool hasHandoff = false,
  String handoffStatus = 'sent',
  String logisticsProviderName = 'Victoria Logistics',
  String receivingProviderName = 'Victoria Logistics',
  String receivingCenterName = 'Victoria Sorting Center',
  String receivingCenterCode = 'SC-3',
}) => {
  'data': {
    'waybill': waybill,
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
    'logistics_provider': {'id': 3, 'name': logisticsProviderName},
    'receiving_logistics_provider': {
      'id': 1,
      'name': receivingProviderName,
      'status': 'active',
    },
    'current_sorting_center': null,
    'receiving_sorting_center': {
      'id': 3,
      'name': receivingCenterName,
      'code': receivingCenterCode,
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
    'handoff_acceptance_eligibility': {
      'eligible': handoffEligible,
      'code': handoffEligible ? 'eligible' : handoffEligibilityCode,
      'message': handoffEligible
          ? 'This incoming city handoff is eligible for acceptance.'
          : handoffEligibilityCode == 'destination_zone_uncovered'
          ? 'The destination Sorting Center has no active zone covering every parcel.'
          : handoffEligibilityCode == 'already_accepted'
          ? 'This city handoff has already been accepted into your Sorting Center.'
          : 'There is no eligible incoming City Handoff for this waybill.',
    },
    'handoff': hasHandoff
        ? {
            'status': handoffStatus,
            'from_provider': logisticsProviderName,
            'to_provider': receivingProviderName,
          }
        : null,
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
        'products': [
          {
            'name': 'Waybill Snapshot Bear',
            'variant': 'Cocoa / Medium',
            'quantity': 2,
            'image_url': 'https://images.bearly.test/waybill.jpg',
          },
        ],
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

Map<String, Object?> _handoffResponse(String waybill) => {
  'message': 'Incoming city handoff accepted.',
  'data': {
    'waybill': waybill,
    'shipment': {
      'reference': 'SHP-L3B-001',
      'status': 'at_sorting_center',
      'purpose': 'outbound',
    },
    'logistics_provider': {'id': 3, 'name': 'Victoria Logistics'},
    'receiving_logistics_provider': {
      'id': 1,
      'name': 'Pila Logistics',
      'status': 'active',
    },
    'receiving_sorting_center': {
      'id': 1,
      'name': 'Pila Sorting Center',
      'code': 'SC-PILA',
      'status': 'active',
      'address': 'Pila',
    },
    'handoff': {
      'status': 'accepted',
      'from_provider': 'Victoria Logistics',
      'to_provider': 'Pila Logistics',
      'accepted_at': '2026-10-31T08:00:00Z',
    },
    'parcels': [
      {
        'reference': 'PCL-L3B-001',
        'status': 'received',
        'current_sorting_center': {
          'id': 1,
          'name': 'Pila Sorting Center',
          'code': 'SC-PILA',
          'status': 'active',
          'address': 'Pila',
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
