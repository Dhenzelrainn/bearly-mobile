import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_cash_custody_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows loading state until the server responds', (tester) async {
    final response = Completer<http.Response>();
    final auth = _auth((_) => response.future);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(http.Response(jsonEncode(_response()), 200));
    await tester.pumpAndSettle();
    expect(find.text('Victoria Logistics'), findsOneWidget);
  });

  testWidgets('shows persisted COD and refund cash records and their history', (
    tester,
  ) async {
    final auth = _auth(
      (_) async => http.Response(jsonEncode(_response()), 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cash Custody'), findsOneWidget);
    expect(find.text('Victoria Logistics'), findsOneWidget);
    expect(
      find.text(
        'Amounts and statuses reflect recorded transactions. Authorized cash receipt and remittance actions update custody records. Payment reconciliation is handled separately by Finance.',
      ),
      findsOneWidget,
    );
    expect(find.text('COD records: 1'), findsOneWidget);
    expect(find.text('Active refund cash: 1'), findsOneWidget);
    expect(find.text('COD-123'), findsOneWidget);
    expect(find.textContaining('₱205.00'), findsOneWidget);
    expect(find.text('Disputed'), findsOneWidget);
    await tester.tap(find.text('COD-123'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PAY-12'), findsOneWidget);
    expect(find.textContaining('Cash Collected From Buyer'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('RCP-44'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('RCP-44'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RCP-44'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ACK-44'), findsWidgets);
    expect(find.textContaining('Assigned To Rider'), findsWidgets);
    expect(find.text('Receive cash'), findsNothing);
    expect(find.text('Assign Rider'), findsNothing);
  });

  testWidgets('formats large COD amounts with grouped peso values', (
    tester,
  ) async {
    final auth = _auth(
      (_) async => http.Response(
        jsonEncode(
          _response(amountDueMinor: 5005000, amountCollectedMinor: 6999000),
        ),
        200,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collected ₱69,990.00 / due ₱50,050.00'), findsOneWidget);
    expect(find.text('Recorded discrepancy ₱19,940.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports empty history, refresh, and narrow large-text layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    var requests = 0;
    final auth = _auth((_) async {
      requests++;
      return http.Response(jsonEncode(_response(empty: true)), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(150, 210), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.scrollUntilVisible(
      find.text('No COD collection records for this provider.'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('No COD collection records for this provider.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('No active refund cash records for this provider.'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('No active refund cash records for this provider.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retryable error state', (tester) async {
    var requests = 0;
    final auth = _auth((_) async {
      requests++;
      return requests == 1
          ? http.Response('{"message":"unavailable"}', 503)
          : http.Response(jsonEncode(_response(empty: true)), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Cash custody information could not be loaded.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('No COD collection records for this provider.'),
      findsOneWidget,
    );
    expect(requests, 2);
  });

  testWidgets('cash records remain usable on a narrow large-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final auth = _auth(
      (_) async => http.Response(jsonEncode(_response()), 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('COD-123'),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('COD-123'), findsOneWidget);
  });

  testWidgets(
    'receipt and remittance dialogs avoid narrow large-text overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      Future<void> checkDialog({
        required String status,
        required String actionLabel,
        required String dialogTitle,
      }) async {
        final auth = _auth(
          (_) async => http.Response(
            jsonEncode(
              _response(
                status: status,
                canReceive: status == 'collected',
                canRemit: status == 'received_by_logistics',
              ),
            ),
            200,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: LogisticsCashCustodyPage(
              repository: LogisticsRepository(authService: auth),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('COD-123'),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('COD-123'));
        await tester.tap(find.text('COD-123'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(actionLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(actionLabel));
        await tester.pumpAndSettle();

        expect(find.text(dialogTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await checkDialog(
        status: 'collected',
        actionLabel: 'Receive Rider cash',
        dialogTitle: 'Confirm COD cash received',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await checkDialog(
        status: 'received_by_logistics',
        actionLabel: 'Remit cash to Finance',
        dialogTitle: 'Confirm Finance handoff',
      );
    },
  );

  testWidgets('loads the next COD page on request', (tester) async {
    final auth = _auth((request) async {
      final page = int.parse(request.url.queryParameters['cod_page']!);
      return http.Response(
        jsonEncode(_response(codPage: page, paginate: true)),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Load more COD records'));
    await tester.tap(find.text('Load more COD records'));
    await tester.pumpAndSettle();
    expect(find.text('COD-SECOND'), findsOneWidget);
  });

  testWidgets(
    'confirms COD receipt and Finance remittance then refreshes state',
    (tester) async {
      var status = 'collected';
      var postCount = 0;
      final auth = _auth((request) async {
        if (request.method == 'POST') {
          postCount++;
          status = request.url.path.endsWith('/receive')
              ? 'received_by_logistics'
              : 'remitted_to_finance';
          return http.Response(jsonEncode(_actionResponse(status)), 200);
        }
        return http.Response(
          jsonEncode(
            _response(
              status: status,
              canReceive: status == 'collected',
              canRemit: status == 'received_by_logistics',
            ),
          ),
          200,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: LogisticsCashCustodyPage(
            repository: LogisticsRepository(authService: auth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('COD-123'));
      await tester.pumpAndSettle();
      expect(find.text('Receive Rider cash'), findsOneWidget);
      expect(find.text('Remit cash to Finance'), findsNothing);
      expect(find.text('Reconcile with Finance'), findsNothing);
      await tester.tap(find.text('Receive Rider cash'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm COD cash received'), findsOneWidget);
      expect(find.text('COD due: ₱200.00'), findsOneWidget);
      expect(find.text('Rider recorded: ₱205.00'), findsOneWidget);
      expect(
        find.text(
          'Count the cash physically received from the Rider. The acknowledged amount must match the Rider-recorded collection. Any difference between the COD due and Rider-collected amount remains subject to Finance review.',
        ),
        findsOneWidget,
      );
      final receiveConfirm = find.byKey(
        const ValueKey('cod-action-submit-receive-6'),
      );
      expect(tester.widget<FilledButton>(receiveConfirm).onPressed, isNull);
      await tester.tap(
        find.byKey(const ValueKey('cod-action-confirm-receive-6')),
      );
      await tester.pumpAndSettle();
      await tester.tap(receiveConfirm);
      await tester.pumpAndSettle();
      expect(find.text('Remit cash to Finance'), findsOneWidget);
      expect(find.text('COD receipt recorded: CODH-123.'), findsOneWidget);
      expect(postCount, 1);

      await tester.tap(find.text('Remit cash to Finance'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Finance handoff'), findsOneWidget);
      expect(
        find.textContaining('Finance must reconcile it separately.'),
        findsOneWidget,
      );
      final remitConfirm = find.byKey(
        const ValueKey('cod-action-submit-remit-6'),
      );
      expect(tester.widget<FilledButton>(remitConfirm).onPressed, isNull);
      await tester.tap(
        find.byKey(const ValueKey('cod-action-confirm-remit-6')),
      );
      await tester.pumpAndSettle();
      await tester.tap(remitConfirm);
      await tester.pumpAndSettle();
      expect(find.text('Remitted To Finance'), findsOneWidget);
      expect(
        find.text('Finance Remittance reference: L2F-123'),
        findsOneWidget,
      );
      expect(find.text('Reconcile with Finance'), findsNothing);
      expect(postCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refreshes after an ambiguous mutation without retrying it', (
    tester,
  ) async {
    var gets = 0;
    var posts = 0;
    final auth = _auth((request) async {
      if (request.method == 'POST') {
        posts++;
        throw http.ClientException('connection interrupted');
      }
      gets++;
      final received = gets > 1;
      return http.Response(
        jsonEncode(
          _response(
            status: received ? 'received_by_logistics' : 'collected',
            canReceive: !received,
            canRemit: received,
          ),
        ),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COD-123'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive Rider cash'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cod-action-confirm-receive-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cod-action-submit-receive-6')));
    await tester.pumpAndSettle();

    expect(posts, 1);
    expect(gets, 2);
    expect(find.text('Remit cash to Finance'), findsOneWidget);
    expect(
      find.textContaining('check the current state before trying again'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('refreshes stale state and displays a conflict without retrying', (
    tester,
  ) async {
    var gets = 0;
    var posts = 0;
    final auth = _auth((request) async {
      if (request.method == 'POST') {
        posts++;
        return http.Response(
          jsonEncode({'message': 'The action is no longer available.'}),
          409,
        );
      }
      gets++;
      final received = gets > 1;
      return http.Response(
        jsonEncode(
          _response(
            status: received ? 'received_by_logistics' : 'collected',
            canReceive: !received,
            canRemit: received,
          ),
        ),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COD-123'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive Rider cash'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cod-action-confirm-receive-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cod-action-submit-receive-6')));
    await tester.pumpAndSettle();

    expect(posts, 1);
    expect(gets, 2);
    expect(find.text('Remit cash to Finance'), findsOneWidget);
    expect(
      find.text(
        'The COD collection changed or this action is no longer available. Cash Custody was refreshed.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables stale cash actions if refresh fails after a timeout', (
    tester,
  ) async {
    var gets = 0;
    var posts = 0;
    final auth = _auth((request) async {
      if (request.method == 'POST') {
        posts++;
        throw http.ClientException('connection interrupted');
      }
      gets++;
      if (gets > 1) return http.Response('unavailable', 503);
      return http.Response(
        jsonEncode(_response(status: 'collected', canReceive: true)),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COD-123'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive Rider cash'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cod-action-confirm-receive-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cod-action-submit-receive-6')));
    await tester.pumpAndSettle();

    expect(posts, 1);
    expect(gets, 2);
    expect(
      find.textContaining('latest state could not be loaded'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('cod-action-receive-6')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows server validation errors and refreshes cash custody', (
    tester,
  ) async {
    var gets = 0;
    var posts = 0;
    final auth = _auth((request) async {
      if (request.method == 'POST') {
        posts++;
        return http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'received_amount': ['The count must match collected cash.'],
            },
          }),
          422,
        );
      }
      gets++;
      return http.Response(
        jsonEncode(_response(status: 'disputed', canReceive: true)),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsCashCustodyPage(
          repository: LogisticsRepository(authService: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COD-123'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive Rider cash'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cod-action-confirm-receive-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cod-action-submit-receive-6')));
    await tester.pumpAndSettle();

    expect(posts, 1);
    expect(gets, 2);
    expect(
      find.textContaining('The count must match collected cash.'),
      findsOneWidget,
    );
    expect(find.text('Receive Rider cash'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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

Map<String, Object?> _response({
  bool empty = false,
  int codPage = 1,
  bool paginate = false,
  String status = 'disputed',
  bool canReceive = true,
  bool canRemit = false,
  int amountDueMinor = 20000,
  int amountCollectedMinor = 20500,
}) => {
  'data': {
    'currency': 'PHP',
    'provider': {'id': 3, 'name': 'Victoria Logistics'},
    'summary': {
      'cod_collection_count': empty ? 0 : 1,
      'active_refund_cash_count': empty ? 0 : 1,
    },
    'cod_collections': {
      'data': empty
          ? []
          : [
              {
                'id': codPage + 5,
                'collection_no': codPage == 1 ? 'COD-123' : 'COD-SECOND',
                'status': status,
                'amount_due_minor': amountDueMinor,
                'amount_collected_minor': amountCollectedMinor,
                'discrepancy_minor': amountCollectedMinor - amountDueMinor,
                'amount_received_by_logistics_minor': status == 'collected'
                    ? null
                    : amountCollectedMinor,
                'amount_remitted_to_finance_minor':
                    status == 'remitted_to_finance'
                    ? amountCollectedMinor
                    : null,
                'amount_reconciled_minor': null,
                'actions': {'can_receive': canReceive, 'can_remit': canRemit},
                'rider_name': 'Rider One',
                'payment': {
                  'payment_no': 'PAY-12',
                  'status': 'pending',
                  'paid_at': null,
                },
                'allocations': [
                  {
                    'order_no': 'ORD-10',
                    'seller_order_no': 'SO-10',
                    'payment_no': 'PAY-12',
                    'amount_due_minor': 20000,
                    'amount_collected_minor': 20000,
                    'amount_reconciled_minor': null,
                  },
                ],
                'references': {
                  'logistics': status == 'collected' ? null : 'CODH-123',
                  'finance_remittance': status == 'remitted_to_finance'
                      ? 'L2F-123'
                      : null,
                  'finance': null,
                },
                'timestamps': {'collected_at': '2026-11-09T10:00:00+00:00'},
                'history': [
                  {
                    'event_type': 'cash_collected_from_buyer',
                    'from_role': null,
                    'to_role': 'rider',
                    'amount_minor': amountCollectedMinor,
                    'reference': 'CODH-123',
                    'occurred_at': '2026-11-09T10:00:00+00:00',
                  },
                ],
              },
            ],
      'meta': {
        'current_page': codPage,
        'last_page': empty || !paginate ? 1 : 2,
        'per_page': 20,
        'total': empty
            ? 0
            : paginate
            ? 2
            : 1,
      },
    },
    'refund_cash': {
      'data': empty
          ? []
          : [
              {
                'id': 4,
                'payout_no': 'RCP-44',
                'refund_no': 'RFD-44',
                'return_no': 'RET-44',
                'status': 'assigned_to_rider',
                'amount_minor': 12500,
                'rider_name': 'Rider Two',
                'acknowledgment_reference': 'ACK-44',
                'timestamps': {'assigned_at': '2026-11-09T11:00:00+00:00'},
                'history': [
                  {
                    'event_type': 'assigned_to_rider',
                    'from_status': 'received_by_logistics',
                    'to_status': 'assigned_to_rider',
                    'amount_minor': 12500,
                    'reference': 'ACK-44',
                    'occurred_at': '2026-11-09T11:00:00+00:00',
                  },
                ],
              },
            ],
      'meta': {
        'current_page': 1,
        'last_page': 1,
        'per_page': 20,
        'total': empty ? 0 : 1,
      },
    },
  },
};

Map<String, Object?> _actionResponse(String status) => {
  'data': {
    'collection': {
      'id': 6,
      'collection_no': 'COD-123',
      'status': status,
      'amount_due_minor': 20000,
      'amount_collected_minor': 20500,
      'amount_received_by_logistics_minor': 20500,
      'amount_remitted_to_finance_minor': status == 'remitted_to_finance'
          ? 20500
          : null,
      'discrepancy_minor': 500,
      'payment_status': 'pending',
      'references': {
        'logistics': 'CODH-123',
        'finance_remittance': status == 'remitted_to_finance'
            ? 'L2F-123'
            : null,
      },
      'timestamps': {
        'logistics_received_at': '2026-11-09T10:00:00+00:00',
        'remitted_to_finance_at': status == 'remitted_to_finance'
            ? '2026-11-09T11:00:00+00:00'
            : null,
      },
    },
  },
  'message': 'COD action recorded.',
};
