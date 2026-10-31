import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_delivery_monitoring_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows loading and then provider-scoped delivery batches', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final auth = _authService((request) {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/mobile/logistics/delivery-monitoring');
      return response.future;
    });

    await tester.pumpWidget(_app(auth));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(http.Response(jsonEncode(_listResponse()), 200));
    await tester.pumpAndSettle();

    expect(find.text('PB Sorting Center'), findsOneWidget);
    expect(find.text('Assigned to Rider'), findsOneWidget);
    expect(find.textContaining('Rider: Mark Carlo A. Andasan'), findsOneWidget);
    expect(find.textContaining('PILA-02 · Pila / Pinagbayanan'), findsOneWidget);
    expect(find.textContaining('Parcels: 1'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('shows empty monitoring state', (tester) async {
    final auth = _authService(
      (_) async => http.Response(jsonEncode(_listResponse(deliveries: [])), 200),
    );
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    expect(find.text('No delivery batches are available yet.'), findsOneWidget);
  });

  testWidgets('read error can be retried without making a mutation request', (
    tester,
  ) async {
    var requests = 0;
    final auth = _authService((request) async {
      expect(request.method, 'GET');
      requests++;
      return requests == 1
          ? http.Response('{"message":"Unavailable"}', 503)
          : http.Response(jsonEncode(_listResponse()), 200);
    });
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load delivery monitoring'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('DSP-20261031-ZS0TJXHV'), findsOneWidget);
  });

  testWidgets('manual refresh reloads the list and detail shows statuses and timeline', (
    tester,
  ) async {
    var listRequests = 0;
    var detailRequests = 0;
    final auth = _authService((request) async {
      expect(request.method, 'GET');
      if (request.url.path == '/api/mobile/logistics/delivery-monitoring') {
        listRequests++;
        return http.Response(
          jsonEncode(_listResponse(progress: listRequests - 1)),
          200,
        );
      }
      expect(
        request.url.path,
        '/api/mobile/logistics/delivery-monitoring/DSP-20261031-ZS0TJXHV',
      );
      detailRequests++;
      return http.Response(jsonEncode(_detailResponse()), 200);
    });

    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh delivery monitoring'));
    await tester.pumpAndSettle();
    expect(listRequests, 2);
    expect(find.text('1%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monitoring-batch-DSP-20261031-ZS0TJXHV')));
    await tester.pumpAndSettle();
    expect(detailRequests, 1);
    expect(find.text('Out for Delivery'), findsOneWidget);
    expect(find.textContaining('BRLY-ULD904RGCHZK1SIDLUND'), findsOneWidget);
    expect(find.textContaining('SHP-20261031-LONG-SHIPMENT-REFERENCE'), findsOneWidget);
    expect(find.text('Parcel status: Out for Delivery'), findsOneWidget);
    expect(find.text('Shipment status: Out for Delivery'), findsOneWidget);
    expect(find.text('Assigned to rider'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Released for delivery'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Released for delivery'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Latest recorded parcel status.'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Latest recorded parcel status.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh delivery details'));
    await tester.pumpAndSettle();
    expect(detailRequests, 2);
  });

  testWidgets('batch list and details fit narrow widths with larger text', (
    tester,
  ) async {
    for (final width in [320, 360, 393]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width.toDouble(), 820);
      final auth = _authService((request) async => http.Response(
        jsonEncode(
          request.url.path.endsWith('/delivery-monitoring')
              ? _listResponse()
              : _detailResponse(longIdentifiers: true),
        ),
        200,
      ));

      await tester.pumpWidget(_app(auth, textScale: 1.35));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('monitoring-batch-DSP-20261031-ZS0TJXHV')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery Details'), findsOneWidget);
      expect(find.textContaining('BRLY-'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(AuthService auth, {double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: LogisticsDeliveryMonitoringPage(
    repository: LogisticsRepository(authService: auth),
  ),
);

AuthService _authService(
  Future<http.Response> Function(http.Request) handler,
) => AuthService(
  apiClient: ApiClient(
    httpClient: MockClient(handler),
    baseUri: Uri.parse('http://127.0.0.1:8000'),
  ),
  tokenStore: _MemoryTokenStore()..token = 'logistics-monitoring-token',
)..currentSession = const AuthSession(
  id: 19,
  name: 'Logistics Operator',
  email: 'operator@example.test',
  role: AccountRole.logistics,
);

Map<String, Object?> _listResponse({int progress = 0, List<Object?>? deliveries}) => {
  'data': {
    'provider': {'id': 3, 'name': 'PB Sorting Center'},
    'deliveries': deliveries ?? [
      {
        'reference': 'DSP-20261031-ZS0TJXHV',
        'rider': 'Mark Carlo A. Andasan',
        'zone': {'code': 'PILA-02', 'name': 'Pila / Pinagbayanan'},
        'parcel_count': 1,
        'progress': progress,
        'status': 'ASSIGNED_TO_RIDER',
        'status_label': 'Assigned to Rider',
        'last_update': 'Released for delivery · Oct 31, 8:00 PM',
      },
    ],
  },
};

Map<String, Object?> _detailResponse({bool longIdentifiers = false}) => {
  'data': {
    'provider': {'id': 3, 'name': 'PB Sorting Center'},
    'sorting_center': {'id': 1, 'name': 'PB Sorting Center', 'code': 'SC-1'},
    'delivery': {
      'reference': 'DSP-20261031-ZS0TJXHV',
      'dispatch_status': 'dispatched',
      'rider': 'Mark Carlo A. Andasan',
      'zone': {'code': 'PILA-02', 'name': 'Pila / Pinagbayanan'},
      'parcel_count': 1,
      'progress': 0,
      'status': 'OUT_FOR_DELIVERY',
      'status_label': 'Out for Delivery',
      'last_update': 'Latest parcel status',
      'assigned_at': '2026-10-31T12:00:00Z',
      'dispatched_at': '2026-10-31T12:05:00Z',
    },
    'parcels': [
      {
        'id': 91,
        'reference': longIdentifiers
            ? 'PCL-6WLXGU2SQ0TDWEIA1MZH-EXTENDED-IDENTIFIER-1234567890'
            : 'PCL-6WLXGU2SQ0TDWEIA1MZH',
        'waybill': longIdentifiers
            ? 'BRLY-ULD904RGCHZK1SIDLUND-EXTENDED-WAYBILL-1234567890'
            : 'BRLY-ULD904RGCHZK1SIDLUND',
        'status': 'out_for_delivery',
        'last_event_at': '2026-10-31T12:10:00Z',
        'shipment': {
          'reference': 'SHP-20261031-LONG-SHIPMENT-REFERENCE',
          'status': 'out_for_delivery',
        },
      },
    ],
    'timeline': [
      {
        'time': 'Oct 31, 8:00 PM',
        'label': 'Assigned to rider',
        'detail': 'Dispatch manifest assigned to Mark Carlo A. Andasan.',
        'occurred_at': '2026-10-31T12:00:00Z',
      },
      {
        'time': 'Oct 31, 8:05 PM',
        'label': 'Released for delivery',
        'detail': '1 parcel released from the sorting center.',
        'occurred_at': '2026-10-31T12:05:00Z',
      },
      {
        'time': 'Oct 31, 8:10 PM',
        'label': 'PCL-6WLXGU2SQ0TDWEIA1MZH: Out For Delivery',
        'detail': 'Latest recorded parcel status.',
        'occurred_at': '2026-10-31T12:10:00Z',
      },
    ],
  },
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
