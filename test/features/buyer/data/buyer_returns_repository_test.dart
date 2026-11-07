import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_returns_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_return_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads server eligibility and remaining item quantities', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return _json(_workspace());
    });

    final workspace = await repository.getWorkspace(24);

    expect(request.method, 'GET');
    expect(request.url.path, '/api/mobile/buyer/seller-orders/24/returns');
    expect(request.headers['authorization'], 'Bearer return-token');
    expect(workspace.canRequest, isTrue);
    expect(workspace.items.single.returnableQuantity, 2);
    expect(workspace.reasonCodes['other'], 'Other issue');
  });

  test(
    'submits selected items and multiple evidence files to Laravel',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _json(_caseResponse(), 201);
      });

      final result = await repository.submitRequest(
        sellerOrderId: 24,
        requestType: 'return_refund',
        reasonCode: 'item_arrived_damaged',
        itemQuantities: {811: 1},
        buyerNote: '  Box was damaged.  ',
        deliveryMethod: 'rider_pickup',
        evidence: const [
          BuyerReturnAttachment(fileName: 'one.jpg', bytes: [1, 2, 3]),
          BuyerReturnAttachment(fileName: 'two.png', bytes: [4, 5, 6]),
        ],
      );

      expect(request.method, 'POST');
      expect(request.url.path, '/api/mobile/buyer/seller-orders/24/returns');
      expect(request.headers['authorization'], 'Bearer return-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(request.body, contains('name="item_quantities[811]"'));
      expect(request.body, contains('name="return_delivery_method"'));
      expect(request.body, contains('filename="one.jpg"'));
      expect(request.body, contains('filename="two.png"'));
      expect(result.id, 51);
      expect(result.status, 'awaiting_seller');
    },
  );

  test(
    'submits item quantities as a nested JSON object without evidence',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _json(_caseResponse(), 201);
      });
      await repository.submitRequest(
        sellerOrderId: 24,
        requestType: 'refund_only',
        reasonCode: 'other',
        itemQuantities: {811: 2},
        buyerNote: '',
        deliveryMethod: null,
        evidence: const [],
      );

      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['item_quantities'], {'811': 2});
      expect(request.headers['content-type'], startsWith('application/json'));
    },
  );

  test(
    'rejects invalid ids, missing item selections, and non-Buyer sessions',
    () async {
      var requests = 0;
      final repository = _repository((_) async {
        requests++;
        return _json(_workspace());
      });
      await expectLater(repository.getWorkspace(0), throwsRangeError);
      await expectLater(
        repository.submitRequest(
          sellerOrderId: 24,
          requestType: 'refund_only',
          reasonCode: 'other',
          itemQuantities: const {},
          buyerNote: '',
          deliveryMethod: null,
          evidence: const [],
        ),
        throwsArgumentError,
      );
      expect(requests, 0);

      final auth = _auth((_) async {
        requests++;
        return _json(_workspace());
      }, role: AccountRole.rider);
      await expectLater(
        BuyerReturnsRepository(authService: auth).getWorkspace(24),
        throwsFormatException,
      );
      expect(requests, 0);
    },
  );

  test(
    'downloads private evidence and completed refund receipts with Buyer auth',
    () async {
      final requests = <http.Request>[];
      final repository = _repository((request) async {
        requests.add(request);
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'image/png'},
        );
      });

      final evidence = await repository.downloadEvidence(71);
      final receipt = await repository.downloadRefundReceipt(72);

      expect(requests.map((request) => request.url.path), [
        '/api/mobile/buyer/returns/evidence/71',
        '/api/mobile/buyer/returns/refunds/72/receipt',
      ]);
      expect(
        requests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer return-token',
        ),
        isTrue,
      );
      expect(evidence.mimeType, 'image/png');
      expect(receipt.bytes, [1, 2, 3]);
    },
  );
}

BuyerReturnsRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerReturnsRepository(authService: _auth(handler));

AuthService _auth(
  Future<http.Response> Function(http.Request) handler, {
  AccountRole role = AccountRole.buyer,
}) {
  final auth = AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: _MemoryTokenStore()..token = 'return-token',
  );
  auth.currentSession = AuthSession(
    id: 8,
    name: 'Buyer Example',
    email: 'buyer@example.test',
    role: role,
  );
  return auth;
}

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _workspace() => {
  'data': {
    'seller_order': {
      'id': 24,
      'reference': 'SO-24',
      'order_reference': 'ORD-24',
      'store_name': 'Market Store',
      'status': 'completed',
      'completed_at': '2026-11-06T12:00:00+08:00',
    },
    'can_request': true,
    'deadline': '2026-11-09T23:59:59+08:00',
    'reason_codes': {'other': 'Other issue'},
    'delivery_methods': [
      {'value': 'rider_pickup', 'label': 'Rider pickup', 'available': true},
    ],
    'dropoff_center': null,
    'items': [
      {
        'id': 811,
        'name': 'Bearly Bag',
        'variant': 'Brown',
        'sku': 'BAG-1',
        'quantity': 2,
        'returnable_quantity': 2,
        'unit_price_minor': 50000,
        'image_url': null,
      },
    ],
    'cases': <Object>[],
  },
};

Map<String, Object?> _caseResponse() => {
  'data': {
    'id': 51,
    'return_reference': 'RET-51',
    'request_type': 'return_refund',
    'status': 'awaiting_seller',
    'requested_amount_minor': 50000,
    'submitted_at': '2026-11-07T10:00:00+08:00',
    'resolved_at': null,
    'refunds': <Object>[],
    'order_reference': 'ORD-24',
    'seller_order_id': 24,
    'store_name': 'Market Store',
    'reason_code': 'item_arrived_damaged',
    'reason_label': 'Item arrived damaged',
    'buyer_note': 'Box was damaged.',
    'resolution': null,
    'response_due_at': null,
    'dropoff_due_at': null,
    'delivery_method': 'rider_pickup',
    'can_add_evidence': false,
    'can_switch_to_pickup': false,
    'evidence': <Object>[],
    'events': <Object>[],
    'return_shipment': null,
    'items': [
      {
        'order_item_id': 811,
        'product_name': 'Bearly Bag',
        'variant_name': 'Brown',
        'quantity': 1,
        'refund_amount_minor': 50000,
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
