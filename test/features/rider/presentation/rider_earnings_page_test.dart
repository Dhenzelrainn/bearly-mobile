import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_earnings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows real ledger summary, records, and loads another page', (
    tester,
  ) async {
    final requestedPages = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RiderEarningsPage(
          repository: _repository((request) async {
            requestedPages.add(request.url.queryParameters['page']);
            return http.Response.bytes(
              utf8.encode(
                jsonEncode(
                  _earningsPayload(
                    page: request.url.queryParameters['page'] == '2' ? 2 : 1,
                  ),
                ),
              ),
              200,
            );
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1,300.00'), findsWidgets);
    expect(find.text('Recorded ledger total'), findsOneWidget);
    expect(find.text('Available for payout'), findsOneWidget);
    expect(find.text('LH-14'), findsOneWidget);
    expect(find.textContaining('Posted'), findsWidgets);
    expect(find.text('Load more'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Load more'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(requestedPages, ['1', '2']);
    expect(find.text('LH-15'), findsOneWidget);
    expect(find.text('Showing 2 of 2 records'), findsOneWidget);
  });

  testWidgets('shows Courier daily pay separately from the shared ledger', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderEarningsPage(
          repository: _repository(
            (_) async => http.Response.bytes(
              utf8.encode(jsonEncode(_earningsPayload(workType: 'courier'))),
              200,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Courier daily earnings'), findsOneWidget);
    expect(find.text('Qualifying workdays'), findsOneWidget);
    expect(find.text('Daily rate'), findsOneWidget);
    expect(find.textContaining('Courier Daily'), findsOneWidget);
  });

  testWidgets('shows a valid empty state and supports pull to refresh', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderEarningsPage(
          repository: _repository((_) async {
            requests++;
            return http.Response.bytes(
              utf8.encode(jsonEncode(_earningsPayload(items: []))),
              200,
            );
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No earnings have been recorded for this account yet.'),
      findsOneWidget,
    );
    expect(requests, 1);

    await tester.drag(find.byType(ListView).first, const Offset(0, 450));
    await tester.pumpAndSettle();
    expect(requests, 2);
  });

  testWidgets('shows an error and recovers when retry succeeds', (
    tester,
  ) async {
    var shouldFail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderEarningsPage(
          repository: _repository((_) async {
            if (shouldFail) return http.Response('{}', 503);
            return http.Response.bytes(
              utf8.encode(jsonEncode(_earningsPayload())),
              200,
            );
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load earnings'), findsOneWidget);
    shouldFail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Recent earnings'), findsOneWidget);
    expect(find.textContaining('Could not load earnings'), findsNothing);
  });
}

RiderRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  final service =
      AuthService(
          apiClient: ApiClient(
            httpClient: MockClient(handler),
            baseUri: Uri.parse('http://127.0.0.1:8000'),
          ),
          tokenStore: _MemoryTokenStore()..token = 'earnings-token',
        )
        ..currentSession = const AuthSession(
          id: 15,
          name: 'Rider Earnings',
          email: 'earnings@example.test',
          role: AccountRole.rider,
        );
  return RiderRepository(authService: service);
}

Map<String, Object?> _earningsPayload({
  String workType = 'local',
  int page = 1,
  List<Map<String, Object?>>? items,
}) => {
  'data': {
    'work_type': workType,
    'currency': 'PHP',
    'summary': {
      'today': {'amount_minor': 65000, 'amount': '₱650.00', 'entries': 1},
      'week': {'amount_minor': 130000, 'amount': '₱1,300.00', 'entries': 2},
      'month': {'amount_minor': 130000, 'amount': '₱1,300.00', 'entries': 2},
      'active_total_minor': 130000,
      'active_total': '₱1,300.00',
      'active_entries': 2,
      'pickup_total_minor': 0,
      'pickup_total': '₱0.00',
      'delivery_total_minor': 130000,
      'delivery_total': '₱1,300.00',
      'delivery_pending_minor': 0,
      'delivery_pending': '₱0.00',
      'courier_daily_minor': workType == 'courier' ? 65000 : 0,
      'courier_daily': workType == 'courier' ? '₱650.00' : '₱0.00',
      'combined_total_minor': 130000,
      'combined_total': '₱1,300.00',
      'payout_eligible_minor': 65000,
      'payout_eligible': '₱650.00',
      'payout_paid_minor': 65000,
      'payout_paid': '₱650.00',
      'payout_status': 'Ready for payout',
    },
    'courier_daily': workType == 'courier'
        ? {
            'rate_minor': 65000,
            'rate': '₱650.00',
            'today_work_date': '2026-11-06',
            'qualifying_days': 2,
            'total_minor': 65000,
            'total': '₱650.00',
            'eligible_minor': 65000,
            'eligible': '₱650.00',
            'paid_minor': 0,
            'paid': '₱0.00',
          }
        : null,
    'items':
        items ??
        (page == 2
            ? [_entry(id: 15, job: 'LH-15')]
            : [
                _entry(
                  id: 14,
                  job: 'LH-14',
                  type: workType == 'courier' ? 'courier_daily' : 'delivery',
                ),
              ]),
    'meta': {
      'current_page': page,
      'last_page': items == null ? 2 : 1,
      'per_page': 20,
      'total': items?.length ?? 2,
      'next_page': page == 1 && items == null ? 2 : null,
    },
  },
};

Map<String, Object?> _entry({
  required int id,
  required String job,
  String type = 'courier_daily',
}) => {
  'id': id,
  'earned_at': 'Nov 6, 2026 · 6:00 PM',
  'earned_at_iso': '2026-11-06T18:00:00+08:00',
  'work_date': 'Nov 6, 2026',
  'work_date_label': 'Nov 6, 2026',
  'job': job,
  'source': 'Courier line-haul run $job',
  'type': type,
  'type_label': type == 'courier_daily' ? 'Courier Daily' : 'Delivery',
  'amount_minor': 65000,
  'amount': '₱650.00',
  'status': 'posted',
  'status_label': 'Posted',
  'posted_at': 'Nov 6, 2026 · 6:01 PM',
  'paid_at': '—',
  'description': 'Daily ledger earning',
  'linehaul_run_no': job,
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
