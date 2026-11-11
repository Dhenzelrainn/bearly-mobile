import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads server-filtered Local Rider choices for the payout', () async {
    http.Request? received;
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        received = request;
        return http.Response(
          jsonEncode({
            'data': {
              'riders': [
                {'user_id': 31, 'name': 'Approved Local Rider'},
              ],
            },
          }),
          200,
        );
      }),
    );

    final riders = await repository.eligibleRefundCashRiders(payoutId: 44);

    expect(
      received!.url.path,
      '/api/mobile/logistics/cash-custody/refunds/44/eligible-riders',
    );
    expect(received!.headers['authorization'], 'Bearer logistics-test-token');
    expect(riders.single.userId, 31);
    expect(riders.single.name, 'Approved Local Rider');
  });

  test(
    'posts receive, assignment, return, and proof verification contracts',
    () async {
      final requests = <http.Request>[];
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          requests.add(request);
          final status = switch (request.url.path.split('/').last) {
            'assign' => 'assigned_to_rider',
            'verify-receipt' => 'awaiting_finance_completion',
            _ => 'awaiting_rider_assignment',
          };
          return http.Response(jsonEncode(_actionResponse(status)), 200);
        }),
      );

      final received = await repository.receiveRefundCash(
        payoutId: 44,
        expectedAmountMinor: 12500,
        actualAmount: '125.00',
        reference: 'LOG-RECEIPT-44',
      );
      final assigned = await repository.assignRefundCash(
        payoutId: 44,
        riderUserId: 31,
      );
      final returned = await repository.confirmRefundCashReturn(
        payoutId: 44,
        expectedAmountMinor: 12500,
        actualAmount: '125.00',
        reference: 'LOG-RETURN-44',
      );
      final verified = await repository.verifyRefundCashReceipt(
        payoutId: 44,
        verificationNote: 'Signed proof and amount checked.',
      );

      expect(requests.map((request) => request.url.path), [
        '/api/mobile/logistics/cash-custody/refunds/44/receive',
        '/api/mobile/logistics/cash-custody/refunds/44/assign',
        '/api/mobile/logistics/cash-custody/refunds/44/confirm-return',
        '/api/mobile/logistics/cash-custody/refunds/44/verify-receipt',
      ]);
      expect(jsonDecode(requests[0].body), {
        'actual_amount': '125.00',
        'reference': 'LOG-RECEIPT-44',
      });
      expect(jsonDecode(requests[1].body), {'rider_user_id': 31});
      expect(jsonDecode(requests[2].body), {
        'actual_amount': '125.00',
        'reference': 'LOG-RETURN-44',
      });
      expect(jsonDecode(requests[3].body), {
        'verification_note': 'Signed proof and amount checked.',
      });
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer logistics-test-token');
      }
      expect(received.status, 'awaiting_rider_assignment');
      expect(assigned.status, 'assigned_to_rider');
      expect(returned.status, 'awaiting_rider_assignment');
      expect(verified.status, 'awaiting_finance_completion');
    },
  );

  test(
    'rejects mismatched cash, malformed references and short notes locally',
    () async {
      var requests = 0;
      final repository = LogisticsRepository(
        authService: _auth((_) async {
          requests++;
          return http.Response(
            jsonEncode(_actionResponse('awaiting_rider_assignment')),
            200,
          );
        }),
      );

      expect(
        () => repository.receiveRefundCash(
          payoutId: 44,
          expectedAmountMinor: 12500,
          actualAmount: '124.99',
          reference: 'REF-1',
        ),
        throwsArgumentError,
      );
      await expectLater(
        () => repository.confirmRefundCashReturn(
          payoutId: 44,
          expectedAmountMinor: 12500,
          actualAmount: '125.000',
          reference: 'REF-1',
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.receiveRefundCash(
          payoutId: 44,
          expectedAmountMinor: 12500,
          actualAmount: '125.00',
          reference: ' ',
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.receiveRefundCash(
          payoutId: 44,
          expectedAmountMinor: 12500,
          actualAmount: '125.00',
          reference: 'x' * 151,
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.verifyRefundCashReceipt(
          payoutId: 44,
          verificationNote: 'no',
        ),
        throwsArgumentError,
      );
      expect(requests, 0);
    },
  );

  test(
    'loads official slip fields and authenticated private proof bytes',
    () async {
      final requests = <http.Request>[];
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/acknowledgment-slip')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'acknowledgment_reference': 'ACK-44-A01',
                  'delivery_attempt_number': 1,
                  'amount_minor': 12500,
                  'buyer_or_recipient_name': 'Buyer One',
                  'refund_no': 'RFD-44',
                  'payout_no': 'RCP-44',
                  'order_no': 'ORD-44',
                  'rider_name': 'Rider One',
                  'provider_name': 'Victoria Logistics',
                  'buyer_confirmation':
                      'I confirm that I received the cash refund.',
                  'signature_labels': [
                    'Received by Buyer',
                    'Delivered by Rider',
                  ],
                },
              }),
              200,
            );
          }
          return http.Response.bytes(
            '%PDF-proof'.codeUnits,
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      );

      final slip = await repository.refundCashAcknowledgmentSlip(payoutId: 44);
      final proof = await repository.refundCashSignedProof(payoutId: 44);

      expect(slip.reference, 'ACK-44-A01');
      expect(slip.amountMinor, 12500);
      expect(slip.signatureLabels, ['Received by Buyer', 'Delivered by Rider']);
      expect(
        requests[0].url.path,
        '/api/mobile/logistics/cash-custody/refunds/44/acknowledgment-slip',
      );
      expect(
        requests[1].url.path,
        '/api/mobile/logistics/cash-custody/refunds/44/acknowledgment',
      );
      expect(
        requests[1].headers['authorization'],
        'Bearer logistics-test-token',
      );
      expect(proof.contentType, 'application/pdf');
      expect(String.fromCharCodes(proof.bytes), '%PDF-proof');
    },
  );
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

Map<String, Object?> _actionResponse(String status) => {
  'data': {
    'payout': {
      'id': 44,
      'payout_no': 'RCP-44',
      'status': status,
      'amount_minor': 12500,
      'acknowledgment_reference': 'ACK-44-A01',
    },
  },
  'message': 'Refund cash action accepted.',
};
