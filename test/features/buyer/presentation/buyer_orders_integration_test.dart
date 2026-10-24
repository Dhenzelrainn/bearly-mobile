import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_address_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_checkout_attempt_store.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_checkout_repository.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_location_repository.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_checkout_attempt.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_home_page.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_order_details_page.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Buyer order history and details integration', () {
    testWidgets('Buyer Home Orders tab opens paginated server history', (
      tester,
    ) async {
      final h = _Harness(
        historyHandler: (request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          return _json(
            _historyPage(
              page == 1
                  ? [
                      _summaryJson(
                        id: 812,
                        reference: 'BRL-812',
                        sellers: [
                          _sellerSummaryJson(id: 991, store: 'Bearly Studio'),
                          _sellerSummaryJson(
                            id: 992,
                            reference: 'SELL-992',
                            store: 'Laguna Makers',
                          ),
                        ],
                      ),
                    ]
                  : [
                      _summaryJson(
                        id: 813,
                        reference: 'BRL-813',
                        sellers: [
                          _sellerSummaryJson(id: 993, store: 'North Shop'),
                        ],
                      ),
                    ],
              page: page,
              lastPage: 2,
              total: 2,
            ),
          );
        },
      );
      await _mountHome(tester, h);

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('BRL-812'), findsOneWidget);
      expect(find.text('Bearly Studio'), findsOneWidget);
      expect(find.text('Laguna Makers'), findsOneWidget);
      expect(find.textContaining('Processing'), findsOneWidget);
      expect(find.text('Payment · Unpaid'), findsOneWidget);
      expect(find.text('COD · Pending'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-order-total-812')))
            .data,
        '₱133.00',
      );
      expect(find.textContaining('(local)'), findsOneWidget);
      expect(
        h.requests.where((request) => request.url.path.endsWith('/orders')),
        hasLength(1),
      );
      final request = h.requests.singleWhere(
        (item) => item.url.path.endsWith('/orders'),
      );
      expect(request.method, 'GET');
      expect(request.url.queryParameters, {'page': '1', 'per_page': '20'});
      expect(request.headers['authorization'], 'Bearer test-session-token');

      await tester.tap(find.byKey(const ValueKey('buyer-orders-load-more')));
      await tester.pumpAndSettle();
      expect(find.text('BRL-813'), findsOneWidget);
      expect(
        h.requests
            .where((item) => item.url.path.endsWith('/orders'))
            .last
            .url
            .queryParameters['page'],
        '2',
      );

      await tester.drag(
        find.byKey(const ValueKey('buyer-orders-list')),
        const Offset(0, 450),
      );
      await tester.pumpAndSettle();
      expect(
        h.requests.where((item) => item.url.path.endsWith('/orders')),
        hasLength(3),
      );
      expect(h.requests.every((item) => item.method == 'GET'), isTrue);
    });

    testWidgets('empty history uses a real empty state', (tester) async {
      final h = _Harness(
        historyHandler: (_) async => _json(_historyPage(const [])),
      );
      await _mountOrders(tester, h);

      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.textContaining('BRL-'), findsNothing);
      expect(h.requests.single.url.path, '/api/mobile/buyer/orders');
      expect(h.requests.single.method, 'GET');
    });

    testWidgets(
      'details show historical variants, COD state, Seller groups, and tracking',
      (tester) async {
        final sellers = [
          _sellerDetailJson(
            id: 991,
            reference: 'SELL-991',
            store: 'Bearly Studio',
            status: 'pending',
            shipments: const [],
            item: _itemJson(
              name: 'Handmade Bear',
              variant: 'Honey / Large',
              options: {'Color': 'Honey', 'Size': 'Large'},
              unit: 12500,
              total: 11500,
            ),
          ),
          _sellerDetailJson(
            id: 992,
            reference: 'SELL-992',
            store: 'Laguna Makers',
            status: 'ready_for_pickup',
            subtotal: 8000,
            shipping: 900,
            total: 8900,
            shipments: const [],
            item: _itemJson(
              name: 'Canvas Pouch',
              variant: 'Olive / Medium',
              options: {'Color': 'Olive', 'Size': 'Medium'},
              unit: 8000,
              subtotal: 8000,
              total: 8000,
            ),
          ),
        ];
        final h = _Harness(
          detailHandler: (_) async => _json(_detailResponse(sellers: sellers)),
          trackingHandler: (_) async => _json(
            _trackingResponse(
              sellers: [
                _trackedSellerJson(
                  id: 991,
                  reference: 'SELL-991',
                  status: 'pending',
                  history: [
                    _statusChange(null, 'pending', '2026-10-23T09:00:00Z'),
                  ],
                  shipments: [
                    _shipmentJson(
                      id: 451,
                      reference: 'SHIP-451',
                      status: 'in_transit',
                      events: [
                        _event(
                          32,
                          'delivery_confirmed',
                          '2026-10-24T12:00:00Z',
                          to: 'delivered',
                        ),
                        _event(
                          31,
                          'city_handoff',
                          '2026-10-24T10:00:00Z',
                          to: 'city_handoff',
                        ),
                      ],
                      assignment: {
                        'status': 'completed',
                        'assigned_at': '2026-10-24T08:00:00Z',
                        'accepted_at': '2026-10-24T08:10:00Z',
                        'arrived_at': '2026-10-24T08:30:00Z',
                        'picked_up_at': '2026-10-24T08:40:00Z',
                        'completed_at': '2026-10-24T08:45:00Z',
                      },
                      attempts: [
                        {
                          'parcel_reference': 'PARCEL-451',
                          'attempt_no': 1,
                          'outcome': 'failed',
                          'attempted_at': '2026-10-24T13:00:00Z',
                          'next_attempt_at': null,
                        },
                      ],
                    ),
                    _shipmentJson(
                      id: 452,
                      reference: 'SHIP-452',
                      status: 'cancelled',
                      events: [
                        _event(
                          41,
                          'shipment_cancelled',
                          '2026-10-24T14:00:00Z',
                          to: 'cancelled',
                        ),
                      ],
                    ),
                  ],
                ),
                _trackedSellerJson(
                  id: 992,
                  reference: 'SELL-992',
                  status: 'ready_for_pickup',
                  history: [
                    _statusChange(null, 'pending', '2026-10-23T10:00:00Z'),
                    _statusChange(
                      'pending',
                      'ready_for_pickup',
                      '2026-10-24T09:00:00Z',
                    ),
                  ],
                  shipments: [
                    _shipmentJson(
                      id: 453,
                      reference: 'SHIP-453',
                      status: 'failed',
                      events: [
                        _event(
                          51,
                          'delivery_failed',
                          '2026-10-24T15:00:00Z',
                          to: 'failed',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              shipmentCount: 3,
            ),
          ),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();

        expect(find.byType(BuyerOrderDetailsPage), findsOneWidget);
        expect(find.text('BRL-812'), findsOneWidget);
        expect(find.text('Order status · Processing'), findsOneWidget);
        await _scrollTo(tester, find.textContaining('Honey / Large'));
        expect(find.text('Handmade Bear'), findsOneWidget);
        expect(find.textContaining('Honey / Large'), findsOneWidget);
        expect(
          find.textContaining('Purchase-time unit price'),
          findsNWidgets(2),
        );
        expect(find.text('Order payment status · Unpaid'), findsOneWidget);
        expect(find.text('COD payment status · Pending'), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('buyer-order-detail-total')),
              )
              .data,
          '₱133.00',
        );
        expect(find.textContaining('Amount payable'), findsOneWidget);
        expect(find.text('Bea Buyer'), findsOneWidget);
        expect(find.text('1 Main Street'), findsOneWidget);
        expect(
          find.text('Seller order status · Ready For Pickup'),
          findsNWidgets(2),
        );
        await _scrollTo(tester, find.text('City Handoff'));
        expect(find.text('Shipment · SHIP-451'), findsOneWidget);
        expect(find.text('Pickup rider activity'), findsNWidgets(3));
        expect(find.text('Last-mile delivery attempts'), findsNWidgets(3));
        expect(
          find.text('Pickup assignment status · Completed'),
          findsOneWidget,
        );
        expect(find.text('Parcel picked up'), findsOneWidget);
        expect(find.text('Attempt 1 · Failed'), findsOneWidget);
        expect(find.text('City Handoff'), findsOneWidget);
        expect(find.text('Delivery Confirmed'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('City Handoff')).dy,
          lessThan(tester.getTopLeft(find.text('Delivery Confirmed')).dy),
        );
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-shipment-452')),
        );
        expect(find.text('Shipment · SHIP-452'), findsOneWidget);
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-shipment-453')),
        );
        expect(find.text('Shipment · SHIP-453'), findsOneWidget);
        expect(h.requests.map((item) => item.method).toSet(), {'GET'});
        expect(
          h.requests.any((item) => item.url.path.contains('confirm-receipt')),
          isFalse,
        );
      },
    );

    testWidgets('pending COD order with no shipments has no fake timeline', (
      tester,
    ) async {
      final detail = _detailResponse(
        canConfirmReceipt: false,
        paymentStatus: 'unpaid',
        sellers: [
          _sellerDetailJson(
            id: 991,
            reference: 'SELL-991',
            store: 'Bearly Studio',
            status: 'pending',
            shipments: const [],
            item: _itemJson(
              name: 'Handmade Bear',
              variant: 'Honey / Large',
              options: {},
            ),
          ),
        ],
      );
      final h = _Harness(
        detailHandler: (_) async => _json(detail),
        trackingHandler: (_) async => _json(
          _trackingResponse(
            trackingState: 'pending',
            sellers: [
              _trackedSellerJson(
                id: 991,
                reference: 'SELL-991',
                status: 'pending',
              ),
            ],
          ),
        ),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-no-shipments')),
      );

      expect(find.text('Order payment status · Unpaid'), findsOneWidget);
      expect(find.text('COD payment status · Pending'), findsOneWidget);
      expect(
        find.text(
          'No shipment records have been returned yet. No shipment milestones are inferred.',
        ),
        findsOneWidget,
      );
      expect(find.text('City Handoff'), findsNothing);
      expect(find.text('Dispatched'), findsNothing);
      expect(find.text('Delivery Confirmed'), findsNothing);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-receipt-ineligible')),
      );
      expect(
        find.byKey(const ValueKey('buyer-order-complete-order')),
        findsNothing,
      );
      expect(find.text('Confirm receipt'), findsNothing);
      expect(h.requests.every((item) => item.method == 'GET'), isTrue);
    });

    testWidgets('missing optional snapshot fields are handled safely', (
      tester,
    ) async {
      final h = _Harness(
        detailHandler: (_) async => _json(
          _detailResponse(
            nullDates: true,
            noPayment: true,
            emptyAddress: true,
            sellers: [
              _sellerDetailJson(
                id: 991,
                reference: 'SELL-991',
                store: null,
                status: 'pending',
                shipments: const [],
                item: _itemJson(
                  name: '',
                  variant: '',
                  options: {},
                  image: null,
                ),
              ),
            ],
          ),
        ),
        trackingHandler: (_) async => _json(
          _trackingResponse(
            trackingState: 'pending',
            sellers: [
              _trackedSellerJson(
                id: 991,
                reference: 'SELL-991',
                status: 'pending',
              ),
            ],
          ),
        ),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Date unavailable'), findsOneWidget);
      await _scrollTo(tester, find.text('No COD payment record was returned.'));
      expect(find.text('No COD payment record was returned.'), findsOneWidget);
      expect(find.text('No address snapshot was returned.'), findsOneWidget);
      expect(find.text('Item name unavailable'), findsOneWidget);
      expect(
        find.text(
          'No shipment records have been returned yet. No shipment milestones are inferred.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tracking labels histories at Laravel response limits', (
      tester,
    ) async {
      final start = DateTime.utc(2026, 10, 24);
      final history = List.generate(
        100,
        (index) => _statusChange(
          index == 0 ? null : 'pending',
          'pending',
          start.add(Duration(minutes: index)).toIso8601String(),
        ),
      );
      final events = List.generate(
        100,
        (index) => _event(
          index + 1,
          'sorting_scan',
          start.add(Duration(minutes: index)).toIso8601String(),
        ),
      );
      final h = _Harness(
        trackingHandler: (_) async => _json(
          _trackingResponse(
            shipmentCount: 1,
            sellers: [
              _trackedSellerJson(
                id: 991,
                reference: 'SELL-991',
                status: 'in_transit',
                history: history,
                shipments: [
                  _shipmentJson(
                    id: 451,
                    reference: 'SHIP-451',
                    status: 'in_transit',
                    events: events,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.textContaining('up to 100 status history'));

      expect(
        find.textContaining('History at this limit may be incomplete.'),
        findsNWidgets(2),
      );
    });

    testWidgets('order-history failure offers retry and retains real results', (
      tester,
    ) async {
      var calls = 0;
      final h = _Harness(
        historyHandler: (_) async {
          calls++;
          return calls == 1
              ? _json({'message': 'Unavailable.'}, 503)
              : _json(_historyPage([_summaryJson(reference: 'BRL-RECOVERED')]));
        },
      );
      await _mountOrders(tester, h);
      expect(
        find.textContaining('could not load this order information'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('buyer-orders-retry')));
      await tester.pumpAndSettle();
      expect(find.text('BRL-RECOVERED'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('detail read failure can be retried', (tester) async {
      var detailCalls = 0;
      final h = _Harness(
        detailHandler: (_) async {
          detailCalls++;
          return detailCalls == 1
              ? _json({'message': 'Unavailable.'}, 503)
              : _json(_detailResponse());
        },
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('buyer-order-details-retry')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('buyer-order-details-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('buyer-order-detail-reference')),
        findsOneWidget,
      );
      expect(detailCalls, 2);
      expect(h.requests.every((item) => item.method == 'GET'), isTrue);
    });

    testWidgets(
      'account switching clears history and discards a late response',
      (tester) async {
        final firstResponse = Completer<http.Response>();
        var calls = 0;
        final h = _Harness(
          historyHandler: (_) {
            calls++;
            if (calls == 1) return firstResponse.future;
            return Future.value(
              _json(
                _historyPage([_summaryJson(id: 913, reference: 'BRL-BUYER-9')]),
              ),
            );
          },
        );
        await _mountOrders(tester, h, settle: false);
        await tester.pump();
        h.auth.currentSession = _session(9);
        await tester.pumpAndSettle();
        expect(find.text('BRL-BUYER-9'), findsOneWidget);

        firstResponse.complete(
          _json(_historyPage([_summaryJson(reference: 'BRL-BUYER-8-PRIVATE')])),
        );
        await tester.pumpAndSettle();
        expect(find.text('BRL-BUYER-8-PRIVATE'), findsNothing);
        expect(find.text('BRL-BUYER-9'), findsOneWidget);
      },
    );

    testWidgets('account switching clears late order details and tracking', (
      tester,
    ) async {
      final detailResponse = Completer<http.Response>();
      final trackingResponse = Completer<http.Response>();
      final h = _Harness(
        detailHandler: (_) => detailResponse.future,
        trackingHandler: (_) => trackingResponse.future,
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pump();
      h.auth.currentSession = _session(9);
      await tester.pumpAndSettle();

      expect(find.textContaining('Your account changed.'), findsOneWidget);
      detailResponse.complete(_json(_detailResponse()));
      trackingResponse.complete(
        _json(
          _trackingResponse(
            sellers: [
              _trackedSellerJson(
                id: 991,
                reference: 'SELL-991',
                status: 'pending',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('buyer-order-detail-reference')),
        findsNothing,
      );
      expect(find.text('Bea Buyer'), findsNothing);
      expect(h.requests.every((item) => item.method == 'GET'), isTrue);
    });

    testWidgets(
      'history and detail screens never send placement or receipt POSTs',
      (tester) async {
        final h = _Harness(
          detailHandler: (_) async => _json(_eligibleDetailResponse()),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        expect(find.byType(BuyerOrderDetailsPage), findsOneWidget);
        expect(
          h.requests.where((request) => request.method == 'POST'),
          isEmpty,
        );
        expect(
          h.requests.any(
            (request) => request.url.path.contains('/confirm-receipt'),
          ),
          isFalse,
        );
      },
    );
  });

  group('Buyer receipt confirmation UI', () {
    testWidgets('eligible state offers action without posting on page load', (
      tester,
    ) async {
      final h = _Harness(
        detailHandler: (_) async => _json(
          _detailResponse(
            canConfirmReceipt: true,
            paymentStatus: 'paid',
            sellers: [
              _sellerDetailJson(
                id: 991,
                reference: 'SELL-991',
                store: 'Bearly Studio',
                status: 'handed_to_logistics',
                shipments: [_deliveredShipmentDetailJson()],
                item: _itemJson(),
              ),
            ],
          ),
        ),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );

      expect(
        find.byKey(const ValueKey('buyer-order-receipt-action')),
        findsOneWidget,
      );
      expect(find.text('Bearly Studio · Handed To Logistics'), findsOneWidget);
      expect(h.requests.where((request) => request.method == 'POST'), isEmpty);
    });

    testWidgets(
      'backend-ineligible and pending COD orders have no submit path',
      (tester) async {
        final h = _Harness(
          detailHandler: (_) async => _json(
            _detailResponse(canConfirmReceipt: false, paymentStatus: 'unpaid'),
          ),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-receipt-ineligible')),
        );

        expect(
          find.byKey(const ValueKey('buyer-order-complete-order')),
          findsNothing,
        );
        expect(find.textContaining('not currently eligible'), findsOneWidget);
        expect(find.text('COD payment status · Pending'), findsOneWidget);
        expect(
          h.requests.where((request) => request.method == 'POST'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'undelivered multi-Seller order does not get partial confirmation',
      (tester) async {
        final h = _Harness(
          detailHandler: (_) async => _json(
            _detailResponse(
              canConfirmReceipt: false,
              sellers: [
                _sellerDetailJson(
                  id: 991,
                  reference: 'SELL-991',
                  store: 'Bearly Studio',
                  status: 'completed',
                  shipments: const [],
                  item: _itemJson(),
                ),
                _sellerDetailJson(
                  id: 992,
                  reference: 'SELL-992',
                  store: 'Laguna Makers',
                  status: 'ready_for_pickup',
                  shipments: const [],
                  item: _itemJson(name: 'Canvas Pouch'),
                ),
              ],
            ),
          ),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-receipt-ineligible')),
        );

        expect(
          find.byKey(const ValueKey('buyer-order-complete-order')),
          findsNothing,
        );
        expect(find.text('Bearly Studio'), findsWidgets);
        expect(find.text('Laguna Makers'), findsWidgets);
        expect(
          h.requests.where((request) => request.method == 'POST'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'already-completed order shows recorded state and no new action',
      (tester) async {
        final h = _Harness(
          detailHandler: (_) async => _json(
            _detailResponse(
              confirmedReceipt: true,
              orderStatus: 'fulfilled',
              paymentStatus: 'paid',
              receiptConfirmedAt: '2026-10-24T08:45:00Z',
              sellers: [
                _sellerDetailJson(
                  id: 991,
                  reference: 'SELL-991',
                  store: 'Bearly Studio',
                  status: 'completed',
                  shipments: const [],
                  item: _itemJson(),
                ),
              ],
            ),
          ),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-receipt-complete')),
        );

        expect(find.text('Receipt confirmed'), findsOneWidget);
        expect(find.textContaining('Philippine Time, UTC+8'), findsOneWidget);
        expect(find.text('SELL-991 · Completed'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('buyer-order-complete-order')),
          findsNothing,
        );
        expect(
          h.requests.where((request) => request.method == 'POST'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'dialog requires explicit confirmation and Cancel sends no POST',
      (tester) async {
        final h = _Harness(
          detailHandler: (_) async => _json(_eligibleDetailResponse()),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('buyer-order-receipt-confirmation-dialog')),
          findsOneWidget,
        );
        expect(
          find.text(
            'This confirms the parent Order for all applicable Seller orders together. There is no per-Seller partial confirmation.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('only after the actual delivery is complete'),
          findsOneWidget,
        );
        expect(
          find.textContaining('does not release Seller payouts'),
          findsNWidgets(2),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-receipt-cancel')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('buyer-order-receipt-confirmation-dialog')),
          findsNothing,
        );
        expect(
          h.requests.where((request) => request.method == 'POST'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'confirmation posts the parent ID bodylessly and refreshes details',
      (tester) async {
        var detailCalls = 0;
        http.Request? receiptRequest;
        final h = _Harness(
          detailHandler: (_) async {
            detailCalls++;
            final completed = detailCalls >= 3;
            return _json(
              _eligibleDetailResponse(
                canConfirmReceipt: !completed,
                confirmedReceipt: completed,
                orderStatus: completed ? 'fulfilled' : 'processing',
                sellers: [
                  _sellerDetailJson(
                    id: 991,
                    reference: 'SELL-991',
                    store: 'Bearly Studio',
                    status: completed ? 'completed' : 'handed_to_logistics',
                    shipments: [_deliveredShipmentDetailJson()],
                    item: _itemJson(),
                  ),
                ],
              ),
            );
          },
          receiptHandler: (request) async {
            receiptRequest = request;
            return _json(_receiptResponse());
          },
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-receipt-confirm')),
        );
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-receipt-complete')),
        );

        expect(receiptRequest, isNotNull);
        expect(receiptRequest!.method, 'POST');
        expect(
          receiptRequest!.url.path,
          '/api/mobile/buyer/orders/812/confirm-receipt',
        );
        expect(receiptRequest!.body, isEmpty);
        expect(
          receiptRequest!.headers['authorization'],
          'Bearer test-session-token',
        );
        expect(
          detailCalls,
          3,
          reason: 'initial, pre-submit, and post-success GETs',
        );
        expect(find.text('Order status · Fulfilled'), findsWidgets);
        expect(find.text('SELL-991 · Completed'), findsOneWidget);
        expect(find.textContaining('Philippine Time, UTC+8'), findsOneWidget);
        expect(
          h.requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        expect(
          h.requests
              .where((request) => request.method == 'POST')
              .single
              .url
              .path,
          '/api/mobile/buyer/orders/812/confirm-receipt',
        );
      },
    );

    testWidgets('already-confirmed replay preserves the returned timestamp', (
      tester,
    ) async {
      final h = _Harness(
        detailHandler: (_) async => _json(_eligibleDetailResponse()),
        receiptHandler: (_) async => _json(
          _receiptResponse(
            alreadyConfirmed: true,
            completedAt: '2026-10-20T01:02:03Z',
          ),
        ),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-receipt-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt was already confirmed'), findsOneWidget);
      expect(find.text('Order status · Fulfilled'), findsWidgets);
      expect(find.textContaining('Philippine Time, UTC+8'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-order-complete-order')),
        findsNothing,
      );
      expect(
        h.requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
    });

    testWidgets('rapid taps keep one receipt POST in flight', (tester) async {
      final response = Completer<http.Response>();
      final postStarted = Completer<void>();
      final h = _Harness(
        detailHandler: (_) async => _json(_eligibleDetailResponse()),
        receiptHandler: (_) {
          if (!postStarted.isCompleted) postStarted.complete();
          return response.future;
        },
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-receipt-confirm')),
      );
      await tester.pump();
      await postStarted.future;
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.pump();

      expect(
        h.requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      response.complete(_json(_receiptResponse()));
      await tester.pumpAndSettle();
    });

    testWidgets('409 conflict is shown and server eligibility is refreshed', (
      tester,
    ) async {
      var detailCalls = 0;
      final h = _Harness(
        detailHandler: (_) async {
          detailCalls++;
          return _json(
            _eligibleDetailResponse(canConfirmReceipt: detailCalls < 3),
          );
        },
        receiptHandler: (_) async => _json({
          'message': 'Not fully delivered.',
          'error': {'code': 'order_not_fully_delivered'},
        }, 409),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-receipt-confirm')),
      );
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-receipt-ineligible')),
      );

      expect(
        find.byKey(const ValueKey('buyer-order-complete-order')),
        findsNothing,
      );
      expect(
        find.textContaining('not every applicable parcel has been delivered'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('buyer-order-receipt-complete')),
        findsNothing,
      );
      expect(detailCalls, 3);
      expect(
        h.requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
    });

    testWidgets('403 clears private order state and offers sign-in again', (
      tester,
    ) async {
      final h = _Harness(
        detailHandler: (_) async => _json(_eligibleDetailResponse()),
        receiptHandler: (_) async => _json({'message': 'Forbidden.'}, 403),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-receipt-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Your account changed.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-order-details-session-sign-in')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('buyer-order-detail-reference')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('buyer-order-receipt-complete')),
        findsNothing,
      );
      expect(
        h.requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
    });

    testWidgets('401 clears private order state and offers sign-in again', (
      tester,
    ) async {
      for (final status in [401, 403]) {
        final h = _Harness(
          detailHandler: (_) async => _json(_eligibleDetailResponse()),
          receiptHandler: (_) async =>
              _json({'message': 'Request rejected.'}, status),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-receipt-confirm')),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Your account changed.'),
          findsOneWidget,
          reason: 'HTTP $status',
        );
        expect(
          find.byKey(const ValueKey('buyer-order-details-session-sign-in')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('buyer-order-detail-reference')),
          findsNothing,
        );
        expect(
          h.requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets('404, 422, and 429 show safe actionable messages', (
      tester,
    ) async {
      const scenarios = <(int, String)>[
        (404, 'unavailable for the signed-in Buyer'),
        (422, 'could not validate the receipt confirmation'),
        (429, 'Wait a little before checking this order again'),
      ];
      for (final (status, expectedMessage) in scenarios) {
        final h = _Harness(
          detailHandler: (_) async => _json(_eligibleDetailResponse()),
          receiptHandler: (_) async =>
              _json({'message': 'Request rejected.'}, status),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-receipt-confirm')),
        );
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-receipt-action')),
        );

        expect(
          find.textContaining(expectedMessage),
          findsOneWidget,
          reason: 'HTTP $status',
        );
        expect(
          find.byKey(const ValueKey('buyer-order-receipt-complete')),
          findsNothing,
        );
        expect(
          h.requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
      'transport interruption is uncertain and does not auto-POST again',
      (tester) async {
        final h = _Harness(
          detailHandler: (_) async => _json(_eligibleDetailResponse()),
          receiptHandler: (_) async =>
              throw http.ClientException('Connection dropped.'),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-receipt-confirm')),
        );
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-receipt-uncertain')),
        );

        expect(
          find.textContaining(
            'latest order read does not show receipt confirmation',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('buyer-order-receipt-complete')),
          findsNothing,
        );
        expect(
          h.requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        expect(
          h.requests.where((request) => request.method == 'GET').length,
          greaterThanOrEqualTo(5),
          reason: 'a read-only status check follows the ambiguous response',
        );
      },
    );

    testWidgets(
      'read-only recovery discovers a completed Order after timeout',
      (tester) async {
        var detailCalls = 0;
        final h = _Harness(
          detailHandler: (_) async {
            detailCalls++;
            final completed = detailCalls >= 3;
            return _json(
              _eligibleDetailResponse(
                canConfirmReceipt: !completed,
                confirmedReceipt: completed,
                orderStatus: completed ? 'fulfilled' : 'processing',
              ),
            );
          },
          receiptHandler: (_) async =>
              throw http.ClientException('Connection dropped.'),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-receipt-confirm')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('buyer-order-receipt-complete')),
          findsOneWidget,
        );
        expect(find.text('Order status · Fulfilled'), findsWidgets);
        expect(find.textContaining('Philippine Time, UTC+8'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('buyer-order-receipt-uncertain')),
          findsNothing,
        );
        expect(
          h.requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
      },
    );

    testWidgets('late confirmation response after Buyer switch is discarded', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      final h = _Harness(
        detailHandler: (_) async => _json(_eligibleDetailResponse()),
        receiptHandler: (_) => response.future,
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-receipt-confirm')),
      );
      await tester.pump();
      h.auth.currentSession = _session(9);
      await tester.pumpAndSettle();

      expect(find.textContaining('Your account changed.'), findsOneWidget);
      response.complete(_json(_receiptResponse()));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('buyer-order-receipt-complete')),
        findsNothing,
      );
      expect(find.textContaining('Philippine Time, UTC+8'), findsNothing);
      expect(
        h.requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
    });

    testWidgets('account change clears an authoritative receipt UI state', (
      tester,
    ) async {
      final h = _Harness(
        detailHandler: (_) async => _json(_eligibleDetailResponse()),
        receiptHandler: (_) async => _json(_receiptResponse()),
      );
      await _mountOrders(tester, h);
      await tester.tap(find.text('BRL-812'));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-complete-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-order-receipt-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('buyer-order-receipt-complete')),
        findsOneWidget,
      );

      h.auth.currentSession = _session(9);
      await tester.pumpAndSettle();

      expect(find.textContaining('Your account changed.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-order-receipt-complete')),
        findsNothing,
      );
      expect(find.textContaining('Philippine Time, UTC+8'), findsNothing);
    });

    testWidgets(
      'history refreshes after returning from successful confirmation',
      (tester) async {
        var historyCalls = 0;
        var detailCalls = 0;
        final h = _Harness(
          historyHandler: (_) async {
            historyCalls++;
            return _json(
              _historyPage([
                _summaryJson(
                  status: historyCalls > 1 ? 'fulfilled' : 'processing',
                  paymentStatus: historyCalls > 1 ? 'paid' : 'unpaid',
                ),
              ]),
            );
          },
          detailHandler: (_) async {
            detailCalls++;
            final completed = detailCalls >= 3;
            return _json(
              _eligibleDetailResponse(
                canConfirmReceipt: !completed,
                confirmedReceipt: completed,
                orderStatus: completed ? 'fulfilled' : 'processing',
              ),
            );
          },
          receiptHandler: (_) async => _json(_receiptResponse()),
        );
        await _mountOrders(tester, h);
        await tester.tap(find.text('BRL-812'));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-complete-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-order-receipt-confirm')),
        );
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(BuyerOrderDetailsPage))).pop();
        await tester.pumpAndSettle();

        expect(historyCalls, 2);
        expect(find.textContaining('Order · Fulfilled'), findsOneWidget);
        expect(
          h.requests.where(
            (request) => request.url.path.contains('/confirm-receipt'),
          ),
          hasLength(1),
        );
      },
    );
  });
}

Future<void> _mountOrders(
  WidgetTester tester,
  _Harness h, {
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: BuyerOrdersPage(
        authService: h.auth,
        checkoutRepository: h.checkout,
        onSignInAgain: () {},
      ),
      onGenerateRoute: (settings) => _generateRoute(settings, h),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _mountHome(WidgetTester tester, _Harness h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: BuyerHomePage(
        authService: h.auth,
        cartController: h.cart,
        wishlistController: h.wishlist,
        addressController: h.addresses,
        locationRepository: h.locations,
        checkoutRepository: h.checkout,
      ),
      onGenerateRoute: (settings) => _generateRoute(settings, h),
    ),
  );
  await tester.pumpAndSettle();
}

Route<dynamic> _generateRoute(RouteSettings settings, _Harness h) =>
    AppRoutes.onGenerateRoute(
      settings,
      authService: h.auth,
      cartController: h.cart,
      wishlistController: h.wishlist,
      addressController: h.addresses,
      locationRepository: h.locations,
      checkoutRepository: h.checkout,
    );

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness({
    this.historyHandler,
    this.detailHandler,
    this.trackingHandler,
    this.receiptHandler,
  }) {
    apiClient = ApiClient(
      httpClient: client,
      baseUri: Uri.parse('https://api.example.test'),
    );
    auth = AuthService(
      apiClient: apiClient,
      tokenStore: _MemoryTokenStore()..token = 'test-session-token',
    )..currentSession = _session(8);
    checkout = BuyerCheckoutRepository(
      authService: auth,
      attemptStore: _MemoryAttemptStore(),
    );
    cart = BuyerCartController(authService: auth);
    wishlist = BuyerWishlistController(authService: auth);
    addresses = BuyerAddressController(authService: auth);
    locations = BuyerLocationRepository(apiClient: apiClient);
  }

  final Future<http.Response> Function(http.Request)? historyHandler;
  final Future<http.Response> Function(http.Request)? detailHandler;
  final Future<http.Response> Function(http.Request)? trackingHandler;
  final Future<http.Response> Function(http.Request)? receiptHandler;
  final List<http.Request> requests = [];

  late final MockClient client = MockClient(_respond);
  late final ApiClient apiClient;
  late final AuthService auth;
  late final BuyerCheckoutRepository checkout;
  late final BuyerCartController cart;
  late final BuyerWishlistController wishlist;
  late final BuyerAddressController addresses;
  late final BuyerLocationRepository locations;

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request);
    if (request.method == 'POST' &&
        request.url.path.endsWith('/confirm-receipt')) {
      return receiptHandler == null
          ? _json({'message': 'Unexpected receipt confirmation.'}, 405)
          : receiptHandler!(request);
    }
    if (request.method != 'GET') {
      return _json({'message': 'Unexpected method.'}, 405);
    }
    if (request.url.path == '/api/mobile/buyer/orders') {
      return historyHandler == null
          ? _json(_historyPage([_summaryJson()]))
          : historyHandler!(request);
    }
    if (request.url.path.endsWith('/tracking')) {
      return trackingHandler == null
          ? _json(
              _trackingResponse(
                sellers: [
                  _trackedSellerJson(
                    id: 991,
                    reference: 'SELL-991',
                    status: 'pending',
                  ),
                ],
              ),
            )
          : trackingHandler!(request);
    }
    if (RegExp(r'/api/mobile/buyer/orders/\d+$').hasMatch(request.url.path)) {
      return detailHandler == null
          ? _json(_detailResponse())
          : detailHandler!(request);
    }
    return _json({'message': 'Not found.'}, 404);
  }
}

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

class _MemoryAttemptStore implements BuyerCheckoutAttemptStore {
  @override
  Future<BuyerCheckoutAttempt?> read(int buyerAccountId) async => null;

  @override
  Future<void> write(BuyerCheckoutAttempt attempt) async {}

  @override
  Future<void> clear(int buyerAccountId) async {}
}

AuthSession _session(int id) => AuthSession(
  id: id,
  name: 'Bea Buyer',
  email: 'bea@example.test',
  role: AccountRole.buyer,
);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> _historyPage(
  List<Map<String, Object?>> orders, {
  int page = 1,
  int lastPage = 1,
  int? total,
  int perPage = 20,
}) {
  final count = total ?? orders.length;
  return {
    'data': orders,
    'links': {
      'first':
          'https://api.example.test/api/mobile/buyer/orders?page=1&per_page=$perPage',
      'last':
          'https://api.example.test/api/mobile/buyer/orders?page=$lastPage&per_page=$perPage',
      'prev': page > 1
          ? 'https://api.example.test/api/mobile/buyer/orders?page=${page - 1}&per_page=$perPage'
          : null,
      'next': page < lastPage
          ? 'https://api.example.test/api/mobile/buyer/orders?page=${page + 1}&per_page=$perPage'
          : null,
    },
    'meta': {
      'current_page': page,
      'from': count == 0 ? null : ((page - 1) * perPage) + 1,
      'last_page': lastPage,
      'per_page': perPage,
      'to': count == 0 ? null : ((page - 1) * perPage) + orders.length,
      'total': count,
    },
  };
}

Map<String, Object?> _summaryJson({
  int id = 812,
  String reference = 'BRL-812',
  String status = 'processing',
  String paymentStatus = 'unpaid',
  int total = 13300,
  List<Map<String, Object?>>? sellers,
  bool nullDates = false,
  bool noPayment = false,
}) => {
  'id': id,
  'order_reference': reference,
  'created_at': nullDates ? null : '2026-10-24T12:00:00Z',
  'placed_at': nullDates ? null : '2026-10-24T12:00:00Z',
  'status': status,
  'payment_status': paymentStatus,
  'currency': 'PHP',
  'subtotal_minor': total,
  'shipping_fee_minor': 1800,
  'discount_minor': 1000,
  'total_minor': total,
  'item_count': 2,
  'preview_image_url': null,
  'cod_payment': noPayment
      ? null
      : {
          'status': paymentStatus == 'paid' ? 'paid' : 'pending',
          'amount_minor': total,
          'paid_at': paymentStatus == 'paid' ? '2026-10-24T08:45:00Z' : null,
        },
  'seller_orders': sellers ?? [_sellerSummaryJson()],
};

Map<String, Object?> _sellerSummaryJson({
  int id = 991,
  String reference = 'SELL-991',
  String? store = 'Bearly Studio',
  String status = 'pending',
  int subtotal = 12500,
  int discount = 1000,
  int shipping = 1800,
  int total = 13300,
  List<Map<String, Object?>> shipments = const [],
}) => {
  'id': id,
  'order_reference': reference,
  'store_id': id + 100,
  'store_name': store,
  'status': status,
  'item_count': 1,
  'line_count': 1,
  'subtotal_minor': subtotal,
  'discount_minor': discount,
  'shipping_fee_minor': shipping,
  'total_minor': total,
  'shipments': shipments,
};

Map<String, Object?> _sellerDetailJson({
  required int id,
  required String reference,
  required String? store,
  required String status,
  required List<Map<String, Object?>> shipments,
  required Map<String, Object?> item,
  int subtotal = 12500,
  int discount = 1000,
  int shipping = 1800,
  int total = 13300,
  List<Map<String, Object?>> returns = const [],
}) => {
  ..._sellerSummaryJson(
    id: id,
    reference: reference,
    store: store,
    status: status,
    subtotal: subtotal,
    discount: discount,
    shipping: shipping,
    total: total,
    shipments: shipments,
  ),
  'platform_discount_minor': 1000,
  'campaign_platform_discount_minor': 0,
  'platform_shipping_discount_minor': 0,
  'items': [item],
  'returns': returns,
};

Map<String, Object?> _summaryFromDetail(Map<String, Object?> seller) => {
  for (final key in [
    'id',
    'order_reference',
    'store_id',
    'store_name',
    'status',
    'item_count',
    'line_count',
    'subtotal_minor',
    'discount_minor',
    'shipping_fee_minor',
    'total_minor',
    'shipments',
  ])
    key: seller[key],
};

Map<String, Object?> _itemJson({
  String name = 'Handmade Bear',
  String variant = 'Honey / Large',
  Map<String, Object?> options = const {'Color': 'Honey', 'Size': 'Large'},
  int quantity = 1,
  int unit = 12500,
  int subtotal = 12500,
  int total = 11500,
  String? image,
}) => {
  'id': 881,
  'product_name': name,
  'variant_name': variant,
  'sku': 'BEAR-HONEY-L',
  'options': options,
  'product_image_url': image,
  'quantity': quantity,
  'unit_price_minor': unit,
  'subtotal_minor': subtotal,
  'seller_discount_minor': 0,
  'platform_discount_minor': 1000,
  'campaign_platform_discount_minor': 0,
  'total_minor': total,
};

Map<String, Object?> _detailResponse({
  List<Map<String, Object?>>? sellers,
  bool canConfirmReceipt = false,
  bool confirmedReceipt = false,
  String orderStatus = 'processing',
  String? receiptConfirmedAt,
  String paymentStatus = 'unpaid',
  bool nullDates = false,
  bool noPayment = false,
  bool emptyAddress = false,
}) {
  final detailSellers =
      sellers ??
      [
        _sellerDetailJson(
          id: 991,
          reference: 'SELL-991',
          store: 'Bearly Studio',
          status: 'pending',
          shipments: const [],
          item: _itemJson(),
        ),
      ];
  final summaries = detailSellers.map(_summaryFromDetail).toList();
  final summary = _summaryJson(
    sellers: summaries,
    status: orderStatus,
    paymentStatus: paymentStatus,
    total: 13300,
    nullDates: nullDates,
    noPayment: noPayment,
  );
  return {
    'data': {
      ...summary,
      'platform_discount_minor': 1000,
      'campaign_platform_discount_minor': 0,
      'platform_shipping_discount_minor': 0,
      'delivery_address': emptyAddress
          ? {
              'recipient_name': '',
              'recipient_phone': '',
              'address_line': '',
              'barangay': '',
              'city_municipality': '',
              'province': '',
              'postal_code': null,
            }
          : {
              'recipient_name': 'Bea Buyer',
              'recipient_phone': '09170000000',
              'address_line': '1 Main Street',
              'barangay': 'San Roque',
              'city_municipality': 'Quezon City',
              'province': 'Metro Manila',
              'postal_code': '1100',
            },
      'payments': noPayment
          ? <Object?>[]
          : [
              {
                'method': 'cod',
                'status': paymentStatus == 'paid' ? 'paid' : 'pending',
                'amount_minor': 13300,
                'paid_at': paymentStatus == 'paid'
                    ? '2026-10-24T08:45:00Z'
                    : null,
              },
            ],
      'promotions': <Object?>[],
      'seller_orders': detailSellers,
      'buyer_actions': {
        'can_confirm_receipt': canConfirmReceipt,
        'receipt_confirmed': confirmedReceipt,
        'receipt_confirmed_at': confirmedReceipt
            ? (receiptConfirmedAt ?? '2026-10-25T12:00:00Z')
            : null,
      },
    },
  };
}

Map<String, Object?> _eligibleDetailResponse({
  bool canConfirmReceipt = true,
  bool confirmedReceipt = false,
  String orderStatus = 'processing',
  List<Map<String, Object?>>? sellers,
}) => _detailResponse(
  canConfirmReceipt: canConfirmReceipt,
  confirmedReceipt: confirmedReceipt,
  orderStatus: orderStatus,
  paymentStatus: 'paid',
  sellers:
      sellers ??
      [
        _sellerDetailJson(
          id: 991,
          reference: 'SELL-991',
          store: 'Bearly Studio',
          status: confirmedReceipt ? 'completed' : 'handed_to_logistics',
          shipments: [_deliveredShipmentDetailJson()],
          item: _itemJson(),
        ),
      ],
);

Map<String, Object?> _deliveredShipmentDetailJson() => {
  'id': 451,
  'shipment_reference': 'SHIP-451',
  'status': 'delivered',
  'waybill_reference': 'WAY-451',
  'estimated_delivery_at': '2026-10-24T08:45:00Z',
  'delivered_at': '2026-10-24T08:45:00Z',
};

Map<String, Object?> _receiptResponse({
  bool alreadyConfirmed = false,
  String completedAt = '2026-10-24T08:45:00Z',
}) => {
  'data': {
    'order_id': 812,
    'order_reference': 'BRL-812',
    'status': 'fulfilled',
    'payment_status': 'paid',
    'currency': 'PHP',
    'total_minor': 13300,
    'completed_at': completedAt,
    'receipt_confirmed': true,
    'already_confirmed': alreadyConfirmed,
    'seller_orders': [
      {
        'id': 991,
        'order_reference': 'SELL-991',
        'status': 'completed',
        'completed_at': completedAt,
      },
      {
        'id': 992,
        'order_reference': 'SELL-992',
        'status': 'cancelled',
        'completed_at': null,
      },
    ],
  },
  'message': alreadyConfirmed
      ? 'Order receipt was already confirmed.'
      : 'Order receipt confirmed.',
};

Map<String, Object?> _trackingResponse({
  List<Map<String, Object?>> sellers = const [],
  String trackingState = 'available',
  int? shipmentCount,
}) => {
  'data': {
    'order_id': 812,
    'order_reference': 'BRL-812',
    'order_status': 'processing',
    'payment_status': 'unpaid',
    'placed_at': '2026-10-24T12:00:00Z',
    'tracking_state': trackingState,
    'shipment_count':
        shipmentCount ??
        sellers.fold<int>(
          0,
          (count, seller) => count + (seller['shipments'] as List).length,
        ),
    'buyer_receipt_confirmed': false,
    'buyer_receipt_confirmed_at': null,
    'seller_orders': sellers,
  },
};

Map<String, Object?> _trackedSellerJson({
  required int id,
  required String reference,
  required String status,
  List<Map<String, Object?>> history = const [],
  List<Map<String, Object?>> shipments = const [],
}) => {
  'id': id,
  'order_reference': reference,
  'status': status,
  'status_history': history,
  'shipments': shipments,
};

Map<String, Object?> _statusChange(String? from, String to, String at) => {
  'from_status': from,
  'to_status': to,
  'occurred_at': at,
};

Map<String, Object?> _shipmentJson({
  required int id,
  required String reference,
  required String status,
  List<Map<String, Object?>> events = const [],
  Map<String, Object?>? assignment,
  List<Map<String, Object?>> attempts = const [],
}) => {
  'id': id,
  'shipment_reference': reference,
  'purpose': 'outbound',
  'status': status,
  'waybill_reference': 'WB-$id',
  'estimated_delivery_at': '2026-10-27T12:00:00Z',
  'delivered_at': status == 'delivered' ? '2026-10-24T12:00:00Z' : null,
  'events': events,
  'pickup_assignments': assignment == null ? <Object?>[] : [assignment],
  'delivery_attempts': attempts,
};

Map<String, Object?> _event(
  int id,
  String type,
  String at, {
  String? from,
  String? to,
}) => {
  'event_id': id,
  'scope': 'shipment',
  'event_type': type,
  'from_status': from,
  'to_status': to,
  'parcel_reference': null,
  'occurred_at': at,
};
