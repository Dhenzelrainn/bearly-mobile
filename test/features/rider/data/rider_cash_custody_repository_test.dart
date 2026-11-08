import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_cash_custody_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'loads Rider cash custody from the authenticated read endpoint',
    () async {
      final requests = <http.Request>[];
      final auth = _authService((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_payload), 200);
      });

      final custody = await RiderCashCustodyRepository(
        authService: auth,
      ).load();

      expect(requests.single.url.path, '/api/mobile/rider/cash-custody');
      expect(requests.single.headers['authorization'], 'Bearer test-token');
      expect(custody.summary.codCollectedMinor, 12000);
      expect(custody.summary.codHandoffPendingMinor, 0);
      expect(custody.codCollections.single.collectionNo, 'COD-100');
      expect(custody.codCollections.single.amountReconciledMinor, 12000);
      expect(custody.codCollections.single.events.single.reference, 'FIN-100');
      expect(custody.refundCash.single.status, 'cash_with_rider');
      expect(custody.summary.refundCashWithRiderMinor, 3500);
    },
  );

  test('rejects invalid response structures', () async {
    final auth = _authService(
      (_) async => http.Response(jsonEncode({'data': []}), 200),
    );
    await expectLater(
      RiderCashCustodyRepository(authService: auth).load(),
      throwsFormatException,
    );
  });
}

final _payload = {
  'data': {
    'currency': 'PHP',
    'summary': {
      'cod_collected_minor': 12000,
      'cod_handoff_pending_minor': 0,
      'refund_cash_with_rider_minor': 3500,
    },
    'cod_collections': [
      {
        'id': 1,
        'collection_no': 'COD-100',
        'amount_due_minor': 12000,
        'amount_collected_minor': 12000,
        'discrepancy_minor': 0,
        'amount_received_by_logistics_minor': 12000,
        'amount_remitted_to_finance_minor': 12000,
        'amount_reconciled_minor': 12000,
        'status': 'reconciled',
        'collected_at': '2026-11-07T10:00:00+08:00',
        'logistics_reference': 'CODH-100',
        'logistics_received_at': '2026-11-07T11:00:00+08:00',
        'finance_remittance_reference': 'L2F-100',
        'remitted_to_finance_at': '2026-11-07T12:00:00+08:00',
        'finance_reference': 'FIN-100',
        'reconciled_at': '2026-11-07T13:00:00+08:00',
        'events': [
          {
            'event_type': 'cash_reconciled_by_finance',
            'from_role': 'logistics',
            'to_role': 'admin',
            'amount_minor': 12000,
            'reference': 'FIN-100',
            'note': null,
            'occurred_at': '2026-11-07T13:00:00+08:00',
          },
        ],
      },
    ],
    'refund_cash': [
      {
        'id': 2,
        'payout_no': 'RCP-100',
        'amount_minor': 3500,
        'status': 'cash_with_rider',
        'acknowledgment_reference': 'ACK-100',
        'assigned_at': '2026-11-07T09:00:00+08:00',
        'received_by_rider_at': '2026-11-07T09:30:00+08:00',
        'started_at': null,
        'last_attempt_at': null,
        'cash_returned_to_logistics_at': null,
        'delivered_at': null,
        'logistics_verified_at': null,
        'completed_at': null,
        'events': [],
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
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'test-token',
      )
      ..currentSession = const AuthSession(
        id: 42,
        name: 'Test Rider',
        email: 'rider@example.test',
        role: AccountRole.rider,
      );

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}
