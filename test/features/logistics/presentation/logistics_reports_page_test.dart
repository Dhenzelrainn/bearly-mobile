import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('renders Web report values and supports refresh', (tester) async {
    var requests = 0;
    final auth = _auth((request) async {
      expect(request.url.path, '/api/mobile/logistics/reports');
      requests++;
      return _json(_reports());
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsReportsPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operations summary'), findsOneWidget);
    expect(find.text('Parcel throughput'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('81.5%'), findsOneWidget);
    expect(find.text('42m'), findsOneWidget);
    expect(find.text('2026-11-01 to 2026-11-07 · Asia/Manila'), findsOneWidget);
    await tester.dragFrom(const Offset(160, 220), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.scrollUntilVisible(
      find.text('Daily parcel throughput'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Daily parcel throughput'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Delivery status breakdown'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delivery status breakdown'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Rider performance'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rider performance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Report Rider One'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Assigned parcels: 11'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('period selector submits the selected calendar range', (
    tester,
  ) async {
    http.Request? reportRequest;
    final auth = _auth((request) async {
      reportRequest = request;
      return _json(_reports());
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsReportsPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('logistics-reports-period-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom date range').last);
    await tester.pumpAndSettle();
    expect(find.text('Select report dates'), findsOneWidget);
    expect(find.text('Apply range'), findsOneWidget);
    final dialogContext = tester.element(find.byType(DateRangePickerDialog));
    Navigator.of(dialogContext).pop(
      DateTimeRange(start: DateTime(2026, 11, 2), end: DateTime(2026, 11, 6)),
    );
    await tester.pumpAndSettle();
    expect(reportRequest!.url.queryParameters, {
      'from': '2026-11-02',
      'to': '2026-11-06',
    });
    await tester.tap(
      find.byKey(const ValueKey('logistics-reports-period-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latest 7 days').last);
    await tester.pumpAndSettle();
    expect(reportRequest!.url.queryParameters, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error states can be retried', (tester) async {
    var requests = 0;
    final auth = _auth((_) async {
      requests++;
      if (requests == 1) {
        return http.Response('{"message":"Unavailable"}', 503);
      }
      return _json(_reports(empty: true));
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsReportsPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reports unavailable'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No operational activity was recorded for this period.'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('No operational activity was recorded for this period.'),
      findsOneWidget,
    );
    expect(requests, 2);
  });

  testWidgets('shows loading and remains usable on narrow large-text screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final pending = Completer<http.Response>();
    final auth = _auth((_) => pending.future);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!,
        ),
        home: LogisticsReportsPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('reports-loading')), findsOneWidget);

    pending.complete(_json(_reports()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Report Rider One'),
      170,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _reports({bool empty = false}) => {
  'data': {
    'period': {
      'from': '2026-11-01',
      'to': '2026-11-07',
      'timezone': 'Asia/Manila',
    },
    'summary': {
      'parcel_throughput': empty ? 0 : 17,
      'delivered_parcels': empty ? 0 : 9,
      'success_rate_percent': empty ? 0 : 81.5,
      'resolved_delivery_outcomes': empty ? 0 : 11,
      'average_sort_time': empty ? '—' : '42m',
    },
    'daily_throughput': empty
        ? []
        : [
            {'label': 'Nov 1', 'parcel_count': 17},
          ],
    'delivery_status_breakdown': empty
        ? []
        : [
            {'label': 'Delivered', 'value': 9, 'share': 75.0},
            {'label': 'Out for Delivery', 'value': 3, 'share': 25.0},
          ],
    'rider_performance': empty
        ? []
        : [
            {
              'name': 'Report Rider One',
              'assigned': 11,
              'delivered': 9,
              'failed': 2,
              'rate': '81.8%',
            },
          ],
  },
};

http.Response _json(Object value, {int statusCode = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
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
