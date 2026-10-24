import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_checkout_attempt_store.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_checkout_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_checkout_attempt.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_checkout_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BuyerCheckoutRepository', () {
    test(
      'sends a server-calculated COD quote selection and parses minor units',
      () async {
        late http.Request request;
        final repository = _repository((incoming) async {
          request = incoming;
          return _json(_quoteResponse());
        });
        final quoteRequest = BuyerCheckoutQuoteRequest(
          addressId: 6,
          cartItemIds: [71],
          vouchers: BuyerCheckoutVoucherSelection(voucherCode: ' bear-10 '),
        );

        final quote = await repository.requestQuote(quoteRequest);

        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/buyer/checkout/quote');
        expect(jsonDecode(request.body), {
          'address_id': 6,
          'cart_item_ids': [71],
          'payment_method': 'cod',
          'voucher_code': 'BEAR-10',
        });
        expect(request.body, isNot(contains('total_minor')));
        expect(quote.totalMinor, 13300);
        expect(quote.items.single.unitPriceMinor, 12500);
        expect(quote.buyerAccountId, 17);
        expect(quote.sourceRequest?.cartItemIds, [71]);
      },
    );

    test('rejects duplicate, empty, or oversized quote selections', () async {
      expect(
        () => BuyerCheckoutQuoteRequest(addressId: 6, cartItemIds: []),
        throwsArgumentError,
      );
      expect(
        () => BuyerCheckoutQuoteRequest(addressId: 6, cartItemIds: [71, 71]),
        throwsArgumentError,
      );
      expect(
        () => BuyerCheckoutQuoteRequest(
          addressId: 6,
          cartItemIds: List<int>.generate(101, (index) => index + 1),
        ),
        throwsArgumentError,
      );
    });

    test(
      'persists before placement and retries the exact payload after timeout',
      () async {
        final attempts = _MemoryAttemptStore();
        final bodies = <Map<String, dynamic>>[];
        var placements = 0;
        final auth = _auth(
          MockClient((request) async {
            if (request.url.path.endsWith('/checkout/quote')) {
              return _json(_quoteResponse());
            }
            placements++;
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            if (placements == 1) throw http.ClientException('offline');
            return _json(_placedOrderResponse());
          }),
        );
        final repository = BuyerCheckoutRepository(
          authService: auth,
          attemptStore: attempts,
          uuidGenerator: () => '4f87cae0-9999-4b31-8d11-123456789abc',
          clock: () => DateTime.utc(2026, 10, 24, 12),
        );

        final quote = await repository.requestQuote(
          BuyerCheckoutQuoteRequest(addressId: 6, cartItemIds: [71]),
        );
        final attempt = await repository.beginPlacementAttempt(
          quote: quote,
          sellerNote: '  Leave at the front desk  ',
        );
        expect(attempt.status, BuyerCheckoutAttemptStatus.ready);
        expect(attempts.saved[17]?.status, BuyerCheckoutAttemptStatus.ready);

        await expectLater(
          repository.submitPlacementAttempt(),
          throwsA(
            isA<BuyerCheckoutException>().having(
              (error) => error.category,
              'category',
              BuyerCheckoutFailureCategory.connectivity,
            ),
          ),
        );
        final restartedRepository = BuyerCheckoutRepository(
          authService: auth,
          attemptStore: attempts,
          uuidGenerator: () => 'must-not-be-used-on-retry',
          clock: () => DateTime.utc(2026, 10, 24, 12),
        );
        expect(
          (await restartedRepository.restorePlacementAttempt())?.status,
          BuyerCheckoutAttemptStatus.indeterminate,
        );
        final placed = await restartedRepository.submitPlacementAttempt();
        expect(placed.id, 812);
        expect(placements, 2);
        expect(bodies[0], bodies[1]);
        expect(
          bodies.first['checkout_request_key'],
          attempt.request.checkoutRequestKey,
        );
        expect(bodies.first['quote_token'], 'encrypted-quote-token');
        expect(bodies.first['seller_note'], 'Leave at the front desk');
        expect(bodies.first['payment_method'], 'cod');
        expect(
          (await attempts.read(17))?.status,
          BuyerCheckoutAttemptStatus.succeeded,
        );

        final cached = await restartedRepository.submitPlacementAttempt();
        expect(cached.id, 812);
        expect(placements, 2, reason: 'a cached success must never POST again');
      },
    );

    test(
      'history, detail, tracking, and bodyless receipt use read/confirmation routes',
      () async {
        final requests = <http.Request>[];
        final repository = _repository((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/tracking')) {
            return _json(_trackingResponse());
          }
          if (request.url.path.endsWith('/confirm-receipt')) {
            return _json(_receiptResponse());
          }
          if (request.url.path.endsWith('/orders/812')) {
            return _json(_detailResponse());
          }
          return _json(_historyResponse());
        });

        final history = await repository.fetchOrderHistory(
          page: 3,
          perPage: 25,
        );
        final detail = await repository.fetchOrderDetail(812);
        final tracking = await repository.fetchTracking(812);
        final receipt = await repository.confirmReceipt(812);

        expect(history.orders, isEmpty);
        expect(history.pagination.currentPage, 3);
        expect(requests[0].url.queryParameters, {
          'page': '3',
          'per_page': '25',
        });
        expect(detail.id, 812);
        expect(detail.deliveryAddress.recipientName, 'Bea Buyer');
        expect(detail.sellerOrders.single.platformDiscountMinor, 1000);
        expect(
          detail.sellerOrders.single.items.single.variantName,
          'Honey / Large',
        );
        expect(detail.sellerOrders.single.returns.single.reference, 'RET-1');
        expect(tracking.trackingState, 'pending');
        expect(tracking.shipmentCount, 0);
        expect(receipt.orderId, 812);
        expect(receipt.alreadyConfirmed, isTrue);
        expect(requests[1].method, 'GET');
        expect(requests[2].url.path, '/api/mobile/buyer/orders/812/tracking');
        expect(requests[3].method, 'POST');
        expect(requests[3].body, isEmpty);
        expect(requests[3].headers['content-type'], isNull);
      },
    );

    test(
      'parses shipment events and delivery-only history without private assignment data',
      () async {
        final repository = _repository(
          (_) async => _json(_availableTrackingResponse()),
        );

        final tracking = await repository.fetchTracking(812);
        final shipment = tracking.sellerOrders.first.shipments.single;

        expect(tracking.trackingState, 'available');
        expect(shipment.events.map((event) => event.eventId), [31, 32]);
        expect(shipment.events.last.parcelReference, 'PARCEL-1');
        expect(shipment.pickupAssignments.single.status, 'completed');
        expect(shipment.deliveryAttempts.single.attemptNumber, 1);
        expect(shipment.deliveryAttempts.single.parcelReference, 'PARCEL-1');
      },
    );

    test(
      'preserves explicit Laravel receipt conflict code and does not retry',
      () async {
        var requests = 0;
        final repository = _repository((_) async {
          requests++;
          return _json({'code': 'order_not_fully_delivered'}, 409);
        });

        await expectLater(
          repository.confirmReceipt(812),
          throwsA(
            isA<BuyerCheckoutException>()
                .having(
                  (error) => error.category,
                  'category',
                  BuyerCheckoutFailureCategory.conflict,
                )
                .having(
                  (error) => error.serverErrorCode,
                  'code',
                  'order_not_fully_delivered',
                ),
          ),
        );
        expect(requests, 1);
      },
    );

    test('fences a delayed response when the active Buyer changes', () async {
      final responseGate = Completer<http.Response>();
      final requestStarted = Completer<void>();
      late AuthService auth;
      final client = MockClient((_) {
        requestStarted.complete();
        return responseGate.future;
      });
      auth = _auth(client);
      final repository = BuyerCheckoutRepository(
        authService: auth,
        attemptStore: _MemoryAttemptStore(),
      );
      final pending = repository.fetchOrderHistory();
      await requestStarted.future;
      auth.currentSession = _session(18);
      responseGate.complete(_json(_historyResponse()));

      await expectLater(
        pending,
        throwsA(
          isA<BuyerCheckoutException>().having(
            (error) => error.category,
            'category',
            BuyerCheckoutFailureCategory.sessionChanged,
          ),
        ),
      );
    });

    test(
      'a stale 401 from the previous Buyer cannot clear the new session',
      () async {
        final responseGate = Completer<http.Response>();
        final requestStarted = Completer<void>();
        final auth = _auth(
          MockClient((_) {
            requestStarted.complete();
            return responseGate.future;
          }),
        );
        final repository = BuyerCheckoutRepository(
          authService: auth,
          attemptStore: _MemoryAttemptStore(),
        );
        final pending = repository.fetchOrderHistory();
        await requestStarted.future;
        auth.currentSession = _session(18);
        responseGate.complete(_json({'message': 'Unauthenticated'}, 401));

        await expectLater(pending, throwsA(isA<BuyerCheckoutException>()));
        expect(auth.currentSession?.id, 18);
      },
    );

    test(
      'requires a Buyer session and refuses to clear unresolved attempts',
      () async {
        final auth = _auth(MockClient((_) async => _json(_historyResponse())));
        auth.currentSession = null;
        final repository = BuyerCheckoutRepository(
          authService: auth,
          attemptStore: _MemoryAttemptStore(),
        );
        await expectLater(
          repository.fetchOrderHistory(),
          throwsA(isA<BuyerCheckoutException>()),
        );
      },
    );
  });
}

BuyerCheckoutRepository _repository(
  Future<http.Response> Function(http.Request) handler, {
  BuyerCheckoutAttemptStore? attemptStore,
  String Function()? uuid,
}) => BuyerCheckoutRepository(
  authService: _auth(MockClient(handler)),
  attemptStore: attemptStore ?? _MemoryAttemptStore(),
  uuidGenerator: uuid,
  clock: () => DateTime.utc(2026, 10, 24, 12),
);

AuthService _auth(http.Client client) {
  final service = AuthService(
    apiClient: ApiClient(
      httpClient: client,
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: _MemoryTokenStore()..token = 'test-session-token',
  );
  service.currentSession = _session(17);
  return service;
}

AuthSession _session(int id) => AuthSession(
  id: id,
  name: 'Bea Buyer',
  email: 'bea@example.test',
  role: AccountRole.buyer,
);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> _quoteResponse() => {
  'data': {
    'currency': 'PHP',
    'items': [
      {
        'cart_item_id': 71,
        'product_id': 41,
        'product_name': 'Handmade Bear',
        'variant_id': 9,
        'variant_name': 'Honey / Large',
        'options': {'Color': 'Honey', 'Size': 'Large'},
        'quantity': 1,
        'unit_price_minor': 12500,
        'subtotal_minor': 12500,
        'seller_discount_minor': 0,
        'platform_discount_minor': 1000,
        'total_discount_minor': 1000,
        'total_minor': 11500,
      },
    ],
    'seller_orders': [],
    'delivery_address': {
      'id': 6,
      'name': 'Bea Buyer',
      'phone': '09170000000',
      'street': '1 Main Street',
      'barangay': 'San Roque',
      'city': 'Quezon City',
      'province': 'Metro Manila',
      'postal': '1100',
      'isDefault': true,
    },
    'subtotal_minor': 12500,
    'shipping_fee_minor': 1800,
    'seller_discount_minor': 0,
    'platform_discount_minor': 1000,
    'shipping_discount_minor': 0,
    'discount_minor': 1000,
    'total_discount_minor': 1000,
    'total_minor': 13300,
    'payment_method': 'cod',
    'available_payment_methods': ['cod'],
    'promotion_selection': {'voucher_code': 'BEAR-10'},
    'applied_promotions': [],
    'quote_token': 'encrypted-quote-token',
    'quote_expires_at': '2026-10-24T12:10:00Z',
  },
};

Map<String, Object?> _placedOrderResponse() => {
  'data': {
    'id': 812,
    'order_reference': 'BRL-812',
    'status': 'pending',
    'payment_method': 'cod',
    'payment_status': 'unpaid',
    'initial_payment_state': 'pending',
    'currency': 'PHP',
    'subtotal_minor': 12500,
    'shipping_fee_minor': 1800,
    'discount_minor': 1000,
    'platform_discount_minor': 1000,
    'campaign_platform_discount_minor': 0,
    'shipping_discount_minor': 0,
    'total_minor': 13300,
    'created_at': '2026-10-24T12:00:00Z',
    'placed_at': '2026-10-24T12:00:00Z',
    'seller_orders': [],
  },
};

Map<String, Object?> _historyResponse() => {
  'data': <Object?>[],
  'links': {'first': null, 'last': null, 'prev': null, 'next': null},
  'meta': {
    'current_page': 3,
    'from': null,
    'last_page': 3,
    'per_page': 25,
    'to': null,
    'total': 0,
  },
};

Map<String, Object?> _detailResponse() => {
  'data': {
    'id': 812,
    'order_reference': 'BRL-812',
    'created_at': '2026-10-24T12:00:00Z',
    'placed_at': '2026-10-24T12:00:00Z',
    'status': 'pending',
    'payment_status': 'unpaid',
    'currency': 'PHP',
    'subtotal_minor': 12500,
    'shipping_fee_minor': 1800,
    'discount_minor': 1000,
    'total_minor': 13300,
    'item_count': 1,
    'preview_image_url': null,
    'cod_payment': null,
    'seller_orders': [
      {
        'id': 991,
        'order_reference': 'SELL-991',
        'store_id': 33,
        'store_name': 'Bearly Studio',
        'status': 'pending',
        'item_count': 1,
        'line_count': 1,
        'subtotal_minor': 12500,
        'discount_minor': 1000,
        'shipping_fee_minor': 1800,
        'total_minor': 13300,
        'shipments': [],
        'platform_discount_minor': 1000,
        'campaign_platform_discount_minor': 0,
        'platform_shipping_discount_minor': 0,
        'items': [
          {
            'id': 881,
            'product_name': 'Handmade Bear',
            'variant_name': 'Honey / Large',
            'sku': 'BEAR-HONEY-L',
            'options': {'Color': 'Honey', 'Size': 'Large'},
            'product_image_url': null,
            'quantity': 1,
            'unit_price_minor': 12500,
            'subtotal_minor': 12500,
            'seller_discount_minor': 0,
            'platform_discount_minor': 1000,
            'campaign_platform_discount_minor': 0,
            'total_minor': 11500,
          },
        ],
        'returns': [
          {
            'return_reference': 'RET-1',
            'request_type': 'refund',
            'status': 'pending',
            'requested_amount_minor': 11500,
            'submitted_at': null,
            'resolved_at': null,
            'refunds': [],
          },
        ],
      },
    ],
    'platform_discount_minor': 1000,
    'campaign_platform_discount_minor': 0,
    'platform_shipping_discount_minor': 0,
    'delivery_address': {
      'recipient_name': 'Bea Buyer',
      'recipient_phone': '09170000000',
      'address_line': '1 Main Street',
      'barangay': 'San Roque',
      'city_municipality': 'Quezon City',
      'province': 'Metro Manila',
      'postal_code': '1100',
    },
    'payments': [],
    'promotions': [],
    'buyer_actions': {
      'can_confirm_receipt': false,
      'receipt_confirmed': false,
      'receipt_confirmed_at': null,
    },
  },
};

Map<String, Object?> _trackingResponse() => {
  'data': {
    'order_id': 812,
    'order_reference': 'BRL-812',
    'order_status': 'pending',
    'payment_status': 'unpaid',
    'placed_at': '2026-10-24T12:00:00Z',
    'tracking_state': 'pending',
    'shipment_count': 0,
    'buyer_receipt_confirmed': false,
    'buyer_receipt_confirmed_at': null,
    'seller_orders': [],
  },
};

Map<String, Object?> _availableTrackingResponse() => {
  'data': {
    'order_id': 812,
    'order_reference': 'BRL-812',
    'order_status': 'shipped',
    'payment_status': 'unpaid',
    'placed_at': '2026-10-24T12:00:00Z',
    'tracking_state': 'available',
    'shipment_count': 1,
    'buyer_receipt_confirmed': false,
    'buyer_receipt_confirmed_at': null,
    'seller_orders': [
      {
        'id': 991,
        'order_reference': 'SELL-991',
        'status': 'shipped',
        'status_history': [
          {
            'from_status': null,
            'to_status': 'pending',
            'occurred_at': '2026-10-24T12:00:00Z',
          },
        ],
        'shipments': [
          {
            'id': 451,
            'shipment_reference': 'SHIP-451',
            'purpose': 'outbound',
            'status': 'in_transit',
            'waybill_reference': 'WB-451',
            'estimated_delivery_at': '2026-10-26T12:00:00Z',
            'delivered_at': null,
            'events': [
              {
                'event_id': 31,
                'scope': 'shipment',
                'event_type': 'created',
                'from_status': null,
                'to_status': 'pending',
                'parcel_reference': null,
                'occurred_at': '2026-10-24T12:05:00Z',
              },
              {
                'event_id': 32,
                'scope': 'parcel',
                'event_type': 'scan',
                'from_status': 'pending',
                'to_status': 'in_transit',
                'parcel_reference': 'PARCEL-1',
                'occurred_at': '2026-10-24T13:05:00Z',
              },
            ],
            'pickup_assignments': [
              {
                'status': 'completed',
                'assigned_at': '2026-10-24T12:10:00Z',
                'accepted_at': '2026-10-24T12:12:00Z',
                'arrived_at': '2026-10-24T12:30:00Z',
                'picked_up_at': '2026-10-24T12:40:00Z',
                'completed_at': '2026-10-24T12:41:00Z',
              },
            ],
            'delivery_attempts': [
              {
                'parcel_reference': 'PARCEL-1',
                'attempt_no': 1,
                'outcome': 'failed',
                'attempted_at': '2026-10-24T14:00:00Z',
                'next_attempt_at': null,
              },
            ],
          },
        ],
      },
    ],
  },
};

Map<String, Object?> _receiptResponse() => {
  'data': {
    'order_id': 812,
    'order_reference': 'BRL-812',
    'status': 'completed',
    'payment_status': 'paid',
    'currency': 'PHP',
    'total_minor': 13300,
    'completed_at': '2026-10-24T13:00:00Z',
    'receipt_confirmed': true,
    'already_confirmed': true,
    'seller_orders': [],
  },
};

class _MemoryTokenStore implements SessionTokenStore {
  String? token;
  @override
  Future<void> clear() async {
    token = null;
  }

  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String token) async {
    this.token = token;
  }
}

class _MemoryAttemptStore implements BuyerCheckoutAttemptStore {
  final saved = <int, BuyerCheckoutAttempt>{};
  @override
  Future<void> clear(int buyerAccountId) async {
    saved.remove(buyerAccountId);
  }

  @override
  Future<BuyerCheckoutAttempt?> read(int buyerAccountId) async =>
      saved[buyerAccountId];
  @override
  Future<void> write(BuyerCheckoutAttempt attempt) async {
    saved[attempt.buyerAccountId] = BuyerCheckoutAttempt.fromJson(
      attempt.toJson(),
    );
  }
}
