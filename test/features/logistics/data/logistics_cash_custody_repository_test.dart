import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads scoped COD and refund cash records using minor units', () async {
    http.Request? received;
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        received = request;
        return http.Response(jsonEncode(_response), 200);
      }),
    );

    final data = await repository.cashCustody(
      codPage: 2,
      refundPage: 3,
      perPage: 10,
    );

    expect(received!.url.path, '/api/mobile/logistics/cash-custody');
    expect(received!.url.queryParameters, {
      'cod_page': '2',
      'refund_page': '3',
      'per_page': '10',
    });
    expect(received!.headers['authorization'], 'Bearer logistics-test-token');
    expect(data.providerName, 'Victoria Logistics');
    expect(data.codCollectionCount, 21);
    expect(data.activeRefundCashCount, 4);
    expect(data.codCollections.items.single.amountCollectedMinor, 20500);
    expect(data.codCollections.items.single.discrepancyMinor, 500);
    expect(data.codCollections.items.single.paymentStatus, 'pending');
    expect(data.codCollections.items.single.canReceive, isTrue);
    expect(data.codCollections.items.single.canRemit, isFalse);
    expect(
      data.codCollections.items.single.allocations.single.amountDueMinor,
      20000,
    );
    expect(
      data.codCollections.items.single.history.single.reference,
      'CODH-123',
    );
    expect(data.refundCash.items.single.amountMinor, 12500);
    expect(data.refundCash.items.single.history.single.to, 'assigned_to_rider');
  });

  test('rejects invalid pagination before sending an API request', () async {
    var requests = 0;
    final repository = LogisticsRepository(
      authService: _auth((_) async {
        requests++;
        return http.Response(jsonEncode(_response), 200);
      }),
    );

    await expectLater(repository.cashCustody(codPage: 0), throwsArgumentError);
    await expectLater(
      repository.cashCustody(refundPage: 0),
      throwsArgumentError,
    );
    await expectLater(repository.cashCustody(perPage: 51), throwsArgumentError);
    expect(requests, 0);
  });

  test(
    'posts authenticated receive and remittance actions in minor-safe form',
    () async {
      final requests = <http.Request>[];
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          requests.add(request);
          final isRemittance = request.url.path.endsWith('/remit');
          return http.Response(
            jsonEncode(_actionResponse(remitted: isRemittance)),
            200,
          );
        }),
      );

      final received = await repository.receiveCodCash(
        collectionId: 6,
        actualAmount: '205.00',
      );
      final remitted = await repository.remitCodCash(
        collectionId: 6,
        actualAmount: '205.00',
      );

      expect(requests.map((request) => request.method), ['POST', 'POST']);
      expect(
        requests[0].url.path,
        '/api/mobile/logistics/cash-custody/cod/6/receive',
      );
      expect(
        requests[1].url.path,
        '/api/mobile/logistics/cash-custody/cod/6/remit',
      );
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer logistics-test-token');
        expect(jsonDecode(request.body), {
          'actual_amount': '205.00',
          'confirmed': true,
        });
      }
      expect(received.status, 'received_by_logistics');
      expect(received.logisticsReference, 'CODH-123');
      expect(received.paymentStatus, 'pending');
      expect(remitted.status, 'remitted_to_finance');
      expect(remitted.financeRemittanceReference, 'L2F-123');
      expect(remitted.paymentStatus, 'pending');
    },
  );

  test('rejects malformed cash amounts before sending a mutation', () async {
    var requests = 0;
    final repository = LogisticsRepository(
      authService: _auth((_) async {
        requests++;
        return http.Response(jsonEncode(_response), 200);
      }),
    );

    await expectLater(
      repository.receiveCodCash(collectionId: 6, actualAmount: '205.001'),
      throwsArgumentError,
    );
    await expectLater(
      repository.remitCodCash(collectionId: 0, actualAmount: '205.00'),
      throwsArgumentError,
    );
    expect(requests, 0);
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

final _response = {
  'data': {
    'currency': 'PHP',
    'provider': {'id': 3, 'name': 'Victoria Logistics'},
    'summary': {'cod_collection_count': 21, 'active_refund_cash_count': 4},
    'cod_collections': {
      'data': [
        {
          'id': 6,
          'collection_no': 'COD-123',
          'status': 'disputed',
          'amount_due_minor': 20000,
          'amount_collected_minor': 20500,
          'discrepancy_minor': 500,
          'actions': {'can_receive': true, 'can_remit': false},
          'amount_received_by_logistics_minor': null,
          'amount_remitted_to_finance_minor': null,
          'amount_reconciled_minor': null,
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
            'logistics': 'CODH-123',
            'finance_remittance': null,
            'finance': null,
          },
          'timestamps': {
            'collected_at': '2026-11-09T10:00:00+00:00',
            'logistics_received_at': null,
            'remitted_to_finance_at': null,
            'reconciled_at': null,
          },
          'history': [
            {
              'event_type': 'cash_collected_from_buyer',
              'from_role': null,
              'to_role': 'rider',
              'amount_minor': 20500,
              'reference': 'CODH-123',
              'occurred_at': '2026-11-09T10:00:00+00:00',
            },
          ],
        },
      ],
      'meta': {'current_page': 2, 'last_page': 3, 'per_page': 10, 'total': 21},
    },
    'refund_cash': {
      'data': [
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
      'meta': {'current_page': 3, 'last_page': 4, 'per_page': 10, 'total': 4},
    },
  },
};

Map<String, Object?> _actionResponse({bool remitted = false}) => {
  'data': {
    'collection': {
      'id': 6,
      'collection_no': 'COD-123',
      'status': remitted ? 'remitted_to_finance' : 'received_by_logistics',
      'amount_due_minor': 20000,
      'amount_collected_minor': 20500,
      'amount_received_by_logistics_minor': 20500,
      'amount_remitted_to_finance_minor': remitted ? 20500 : null,
      'discrepancy_minor': 500,
      'payment_status': 'pending',
      'references': {
        'logistics': 'CODH-123',
        'finance_remittance': remitted ? 'L2F-123' : null,
      },
      'timestamps': {
        'logistics_received_at': '2026-11-09T10:00:00+00:00',
        'remitted_to_finance_at': remitted ? '2026-11-09T11:00:00+00:00' : null,
      },
    },
  },
  'message': 'COD action recorded.',
};
