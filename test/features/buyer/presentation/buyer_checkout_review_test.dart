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
import 'package:bearly_mobile/features/buyer/data/buyer_checkout_placement_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_checkout_review_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_location_repository.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_catalog_models.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_checkout_attempt.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_checkout_models.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_order_models.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_shopping_models.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_cart_page.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_checkout_review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Buyer checkout review integration', () {
    testWidgets('sends Cart IDs and renders the server COD quote', (
      tester,
    ) async {
      final h = _Harness();
      await _pumpCart(tester, h);
      await tester.tap(find.byKey(const ValueKey('buyer-cart-select-501')));
      await tester.tap(find.byKey(const ValueKey('buyer-cart-select-502')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-cart-continue-checkout')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-cart-continue-checkout')),
      );
      await tester.pumpAndSettle();

      final quoteRequest = h.requests.singleWhere(
        (request) => request.url.path == '/api/mobile/buyer/checkout/quote',
      );
      expect(quoteRequest.method, 'POST');
      expect(
        quoteRequest.headers['authorization'],
        'Bearer test-session-token',
      );
      expect(jsonDecode(quoteRequest.body), {
        'address_id': 31,
        'cart_item_ids': [501, 502],
        'payment_method': 'cod',
      });
      expect(
        h.requests.any(
          (request) => request.url.path.endsWith('/checkout/place'),
        ),
        isFalse,
      );
      expect(h.attemptStore.readCount, 1);
      expect(h.attemptStore.writeCount, 0);
      expect(h.attemptStore.clearCount, 0);
      expect(find.byType(BuyerCheckoutReviewPage), findsOneWidget);
      expect(find.text('Alpha Shop'), findsOneWidget);
      expect(find.text('Beta Shop'), findsOneWidget);
      expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-checkout-quote-error')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-checkout-total')),
      );
      expect(
        find.text(formatPriceMinorUnits(32000, currency: 'PHP')),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
        findsOneWidget,
      );
    });

    testWidgets('no address blocks quotation and offers Add Address', (
      tester,
    ) async {
      final h = _Harness(addresses: const []);
      await h.cart.refresh(force: true);
      h.cart.setItemSelected(501, true);
      final review = h.reviewController();
      await tester.pumpWidget(
        MaterialApp(
          home: BuyerCheckoutReviewPage(
            reviewController: review,
            placementController: h.placementController(),
            addressController: h.addresses,
            locationRepository: h.locations,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No saved delivery addresses.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-checkout-add-address')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('buyer-checkout-request-quote')),
            )
            .onPressed,
        isNull,
      );
      expect(
        h.requests.any(
          (request) => request.url.path.endsWith('/checkout/quote'),
        ),
        isFalse,
      );
      expect(h.attemptStore.readCount, 1);
      expect(h.attemptStore.writeCount, 0);
    });

    test('changing address clears the prior quote', () async {
      final h = _Harness();
      await _loadInputs(h);
      final review = h.reviewController();
      await review.initialize();
      h.cart.setItemSelected(501, true);
      await review.requestQuote();
      expect(review.quote, isNotNull);
      expect(review.selectedAddressId, 31);

      expect(review.selectAddress(32), isTrue);
      expect(review.quote, isNull);
      expect(review.isQuoteExpired, isFalse);
      review.dispose();
    });

    test(
      'address created after an empty state becomes the selected address',
      () async {
        final h = _Harness(addresses: const []);
        await _loadInputs(h);
        final review = h.reviewController();
        await review.initialize();
        expect(review.selectedAddress, isNull);

        await h.addresses.createAddress(
          const BuyerAddressCreate(
            name: 'New Recipient',
            phone: '09170000000',
            province: 'Laguna',
            city: 'Santa Rosa',
            barangay: 'Balibago',
            postal: '4026',
            street: 'Pine Street',
            label: 'Home',
          ),
        );
        expect(review.selectedAddress?.name, 'New Recipient');
        expect(review.selectedAddressId, 33);
        review.dispose();
      },
    );

    test(
      'a deleted selected address clears the quote and blocks reuse',
      () async {
        final h = _Harness();
        await _loadInputs(h);
        final review = h.reviewController();
        await review.initialize();
        h.cart.setItemSelected(501, true);
        await review.requestQuote();
        expect(review.quote, isNotNull);

        h.removeAddress(31);
        await review.refreshAddresses();
        expect(review.selectedAddress, isNull);
        expect(review.quote, isNull);
        expect(review.canRequestQuote, isFalse);
        review.dispose();
      },
    );

    test(
      '422 quote validation shows its message without a fake total',
      () async {
        final h = _Harness(
          quoteHandler: (_) async => _json({
            'message': 'The selected stock has changed.',
            'errors': {
              'cart_item_ids': ['The selected stock has changed.'],
            },
          }, status: 422),
        );
        await _loadInputs(h);
        final review = h.reviewController();
        await review.initialize();
        h.cart.setItemSelected(501, true);
        await review.requestQuote();

        expect(review.quote, isNull);
        expect(
          review.quoteErrorMessage(review.quoteError!),
          'The selected stock has changed.',
        );
        expect(h.attemptStore.readCount + h.attemptStore.writeCount, 0);
        review.dispose();
      },
    );

    test('expired quote is removed and marked for refresh', () async {
      final h = _Harness(quoteLifetime: const Duration(milliseconds: 80));
      await _loadInputs(h);
      final review = h.reviewController();
      await review.initialize();
      h.cart.setItemSelected(501, true);
      await review.requestQuote();
      expect(review.quote, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(review.quote, isNull);
      expect(review.isQuoteExpired, isTrue);
      review.dispose();
    });

    test(
      'duplicate quote taps are blocked and late results are discarded',
      () async {
        final first = Completer<http.Response>();
        final second = Completer<http.Response>();
        var quoteCalls = 0;
        final h = _Harness(
          quoteHandler: (_) {
            quoteCalls++;
            return quoteCalls == 1 ? first.future : second.future;
          },
        );
        await _loadInputs(h);
        final review = h.reviewController();
        await review.initialize();
        h.cart.setItemSelected(501, true);

        final oldRequest = review.requestQuote();
        await Future<void>.delayed(Duration.zero);
        await review.requestQuote();
        expect(quoteCalls, 1);

        h.cart.setItemSelected(502, true);
        final currentRequest = review.requestQuote();
        await Future<void>.delayed(Duration.zero);
        expect(quoteCalls, 2);
        second.complete(_json(h.quoteResponse([501, 502], addressId: 31)));
        await currentRequest;
        first.complete(_json(h.quoteResponse([501], addressId: 31)));
        await oldRequest;

        expect(review.quote?.sourceRequest?.cartItemIds, [501, 502]);
        expect(quoteCalls, 2);
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );
        expect(h.attemptStore.readCount + h.attemptStore.writeCount, 0);
        review.dispose();
      },
    );

    test(
      'Buyer session change clears the previous quote and address',
      () async {
        final h = _Harness();
        await _loadInputs(h);
        final review = h.reviewController();
        await review.initialize();
        h.cart.setItemSelected(501, true);
        await review.requestQuote();
        expect(review.quote, isNotNull);

        h.auth.currentSession = _session(9);
        h.cart.synchronizeSession();
        h.addresses.synchronizeSession();
        expect(review.quote, isNull);
        expect(review.selectedAddress, isNull);
        expect(h.cart.selectedCount, 0);
        review.dispose();
      },
    );

    testWidgets(
      'persists before POST and confirms the authoritative COD order',
      (tester) async {
        final h = _Harness();
        await _enterReview(tester, h, selectedIds: [501]);

        expect(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
          findsOneWidget,
        );
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Place this COD order?'), findsOneWidget);
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );

        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
        );
        await tester.pumpAndSettle();

        final placeRequest = h.requests.singleWhere(
          (request) => request.url.path.endsWith('/checkout/place'),
        );
        final payload = jsonDecode(placeRequest.body) as Map<String, dynamic>;
        expect(payload['cart_item_ids'], [501]);
        expect(payload['address_id'], 31);
        expect(payload['payment_method'], 'cod');
        expect(payload['quote_token'], 'mock-quote-token');
        expect(
          payload['checkout_request_key'],
          matches(RegExp(r'^[0-9a-f-]{36}$')),
        );
        expect(
          h.attemptStore.events.indexOf('write-ready'),
          lessThan(h.attemptStore.events.indexOf('post')),
        );
        expect(
          h.attemptStore.events.indexOf('write-submitting'),
          lessThan(h.attemptStore.events.indexOf('post')),
        );
        expect(find.byType(BuyerOrderConfirmationPage), findsOneWidget);
        expect(find.text('BRL-ORDER-812'), findsOneWidget);
        expect(find.text('Alpha Shop'), findsOneWidget);
        expect(find.text('SO-1'), findsOneWidget);
        expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
        expect(find.textContaining('Unpaid'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('buyer-order-confirmation-total')),
          findsOneWidget,
        );
        expect(h.cart.cart?.items.map((item) => item.id), [502]);
        expect(h.cart.selectedItems, isEmpty);
        expect(
          h.requests.where(
            (request) =>
                request.method == 'GET' &&
                request.url.path == '/api/mobile/buyer/cart',
          ),
          hasLength(3),
        );
        expect(
          h.attemptStore.saved[8]?.status,
          BuyerCheckoutAttemptStatus.succeeded,
        );
      },
    );

    testWidgets(
      'final confirmation can be cancelled without creating an order',
      (tester) async {
        final h = _Harness();
        await _enterReview(tester, h, selectedIds: [501]);
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-cancel-placement')),
        );
        await tester.pumpAndSettle();

        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );
        expect(h.attemptStore.writeCount, 0);
      },
    );

    testWidgets('ambiguous timeout offers exact explicit retry', (
      tester,
    ) async {
      final bodies = <String>[];
      var placeCount = 0;
      late _Harness h;
      h = _Harness(
        placeHandler: (request) async {
          placeCount++;
          bodies.add(request.body);
          if (placeCount == 1) throw http.ClientException('connection lost');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final ids = (body['cart_item_ids'] as List).cast<int>();
          final items = h._cartItems
              .where((item) => ids.contains(item['id']))
              .toList(growable: false);
          h._cartItems.removeWhere((item) => ids.contains(item['id']));
          return _json(_placedOrderResponse(items));
        },
      );
      await _enterReview(tester, h, selectedIds: [501]);
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order status needs verification'), findsOneWidget);
      expect(
        find.textContaining('could not confirm whether the order was created'),
        findsOneWidget,
      );
      expect(
        h.attemptStore.saved[8]?.status,
        BuyerCheckoutAttemptStatus.indeterminate,
      );
      expect(
        find.byKey(const ValueKey('buyer-checkout-retry-original')),
        findsOneWidget,
      );
      expect(placeCount, 1);

      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-retry-original')),
      );
      await tester.pumpAndSettle();

      expect(placeCount, 2);
      expect(bodies, hasLength(2));
      expect(bodies[1], bodies[0]);
      expect(
        h.requests.where(
          (request) => request.url.path.endsWith('/checkout/quote'),
        ),
        hasLength(1),
      );
      expect(find.text('BRL-ORDER-812'), findsOneWidget);
    });

    testWidgets(
      'restart recovery waits for explicit retry and keeps expired token',
      (tester) async {
        final h = _Harness();
        final original = BuyerCheckoutPlacementRequest(
          checkoutRequestKey: '7f87cae0-9999-4b31-8d11-123456789abc',
          quoteToken: 'original-expired-quote-token',
          addressId: 31,
          cartItemIds: [501],
        );
        await h.attemptStore.write(
          BuyerCheckoutAttempt(
            buyerAccountId: 8,
            request: original,
            status: BuyerCheckoutAttemptStatus.indeterminate,
            updatedAt: DateTime.utc(2026, 10, 1),
            failureCategory: BuyerCheckoutFailureCategory.timeout.name,
          ),
        );
        await _pumpReview(tester, h);

        expect(find.text('Order status needs verification'), findsOneWidget);
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/quote'),
          ),
          isFalse,
        );

        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-retry-original')),
        );
        await tester.pumpAndSettle();
        final place = h.requests.singleWhere(
          (request) => request.url.path.endsWith('/checkout/place'),
        );
        expect(jsonDecode(place.body), original.toJson());
        expect(find.text('BRL-ORDER-812'), findsOneWidget);
      },
    );

    testWidgets(
      'restored unsubmitted attempt needs a fresh quote before placement',
      (tester) async {
        final h = _Harness();
        await h.attemptStore.write(
          BuyerCheckoutAttempt(
            buyerAccountId: 8,
            request: BuyerCheckoutPlacementRequest(
              checkoutRequestKey: '8f87cae0-9999-4b31-8d11-123456789abc',
              quoteToken: 'expired-unsubmitted-token',
              addressId: 31,
              cartItemIds: [501],
            ),
            status: BuyerCheckoutAttemptStatus.ready,
            updatedAt: DateTime.utc(2026, 10, 1),
          ),
        );
        await _pumpReview(tester, h);

        expect(find.text('A fresh quote is needed'), findsOneWidget);
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/quote'),
          ),
          isFalse,
        );
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );

        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-refresh-unsubmitted')),
        );
        await tester.pumpAndSettle();

        final quoteRequest = h.requests.singleWhere(
          (request) => request.url.path.endsWith('/checkout/quote'),
        );
        expect(jsonDecode(quoteRequest.body)['cart_item_ids'], [501]);
        expect(h.attemptStore.saved[8], isNull);
        expect(h.attemptStore.clearCount, 1);
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );
        expect(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'succeeded attempt without a result can recover by exact retry',
      (tester) async {
        final h = _Harness();
        final original = BuyerCheckoutPlacementRequest(
          checkoutRequestKey: '7f87cae0-9999-4b31-8d11-123456789abc',
          quoteToken: 'original-quote-token',
          addressId: 31,
          cartItemIds: [501],
        );
        await h.attemptStore.write(
          BuyerCheckoutAttempt(
            buyerAccountId: 8,
            request: original,
            status: BuyerCheckoutAttemptStatus.succeeded,
            updatedAt: DateTime.utc(2026, 10, 1),
          ),
        );

        await _pumpReview(tester, h);

        expect(find.text('Order status needs verification'), findsOneWidget);
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );
        expect(
          find.byKey(const ValueKey('buyer-checkout-retry-original')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-retry-original')),
        );
        await tester.pumpAndSettle();

        final placement = h.requests.singleWhere(
          (request) => request.url.path.endsWith('/checkout/place'),
        );
        expect(jsonDecode(placement.body), original.toJson());
        expect(find.text('BRL-ORDER-812'), findsOneWidget);
      },
    );

    testWidgets('saved success restores confirmation without another POST', (
      tester,
    ) async {
      final h = _Harness();
      final request = BuyerCheckoutPlacementRequest(
        checkoutRequestKey: '9f87cae0-9999-4b31-8d11-123456789abc',
        quoteToken: 'committed-quote-token',
        addressId: 31,
        cartItemIds: [501],
      );
      final result = BuyerPlacedOrder.fromResponse(
        _placedOrderResponse([h._cartItems.first]),
      );
      await h.attemptStore.write(
        BuyerCheckoutAttempt(
          buyerAccountId: 8,
          request: request,
          status: BuyerCheckoutAttemptStatus.succeeded,
          result: result,
          updatedAt: DateTime.utc(2026, 10, 24),
        ),
      );
      h._cartItems.removeWhere((item) => item['id'] == 501);
      await _pumpReview(tester, h);

      expect(find.byType(BuyerOrderConfirmationPage), findsOneWidget);
      expect(find.text('BRL-ORDER-812'), findsOneWidget);
      expect(
        h.requests.any(
          (request) => request.url.path.endsWith('/checkout/place'),
        ),
        isFalse,
      );
      expect(
        h.requests.any(
          (request) => request.url.path.endsWith('/checkout/quote'),
        ),
        isFalse,
      );
      expect(
        h.attemptStore.saved[8]?.status,
        BuyerCheckoutAttemptStatus.succeeded,
      );
    });

    testWidgets(
      'expired current quote disables placement until explicit refresh',
      (tester) async {
        final h = _Harness(quoteLifetime: const Duration(seconds: 1));
        await _enterReview(tester, h, selectedIds: [501]);
        expect(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('buyer-checkout-quote-expired')),
          findsOneWidget,
        );
        expect(
          h.requests.any(
            (request) => request.url.path.endsWith('/checkout/place'),
          ),
          isFalse,
        );
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-request-quote')),
        );
        await tester.pumpAndSettle();
        expect(
          h.requests.where(
            (request) => request.url.path.endsWith('/checkout/quote'),
          ),
          hasLength(2),
        );
      },
    );

    testWidgets('409 conflict is never success and keeps the attempt locked', (
      tester,
    ) async {
      final h = _Harness(
        placeHandler: (_) async => _json({
          'message': 'Conflict.',
          'error': {'code': 'checkout_request_conflict'},
        }, status: 409),
      );
      await _enterReview(tester, h, selectedIds: [501]);
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Checkout request conflict'), findsOneWidget);
      expect(find.textContaining('checkout_request_conflict'), findsOneWidget);
      expect(find.byType(BuyerOrderConfirmationPage), findsNothing);
      expect(
        find.byKey(const ValueKey('buyer-checkout-requote-after-rejection')),
        findsNothing,
      );
      expect(h.attemptStore.clearCount, 0);
      expect(
        h.attemptStore.saved[8]?.status,
        BuyerCheckoutAttemptStatus.rejected,
      );
      expect(
        h.requests.where(
          (request) =>
              request.method == 'GET' &&
              request.url.path == '/api/mobile/buyer/cart',
        ),
        hasLength(2),
      );
    });

    testWidgets('definitive 422 requires a deliberate fresh quote', (
      tester,
    ) async {
      var quoteCount = 0;
      late _Harness h;
      h = _Harness(
        quoteHandler: (request) async {
          quoteCount++;
          return _json(h._quoteFromRequest(request));
        },
        placeHandler: (_) async => _json({
          'message': 'The quote has expired.',
          'errors': {
            'quote_token': ['The checkout quote expired.'],
          },
        }, status: 422),
      );
      await _enterReview(tester, h, selectedIds: [501]);
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
      );
      await tester.pumpAndSettle();

      expect(find.text('This placement was rejected'), findsOneWidget);
      expect(find.text('The checkout quote expired.'), findsOneWidget);
      expect(quoteCount, 1);
      expect(
        h.attemptStore.saved[8]?.status,
        BuyerCheckoutAttemptStatus.rejected,
      );
      expect(
        h.requests.where(
          (request) =>
              request.method == 'GET' &&
              request.url.path == '/api/mobile/buyer/cart',
        ),
        hasLength(2),
      );

      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-requote-after-rejection')),
      );
      await tester.pumpAndSettle();
      expect(quoteCount, 2);
      expect(h.attemptStore.clearCount, 1);
      expect(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
        findsOneWidget,
      );
      expect(
        h.requests.where(
          (request) => request.url.path.endsWith('/checkout/place'),
        ),
        hasLength(1),
      );
    });

    testWidgets('secure persistence failure prevents any placement POST', (
      tester,
    ) async {
      final h = _Harness(failAttemptWrites: true);
      await _enterReview(tester, h, selectedIds: [501]);
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('buyer-checkout-placement-error')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Secure checkout recovery is unavailable'),
        findsOneWidget,
      );
      expect(
        h.requests.any(
          (request) => request.url.path.endsWith('/checkout/place'),
        ),
        isFalse,
      );
    });

    testWidgets('429 placement rejection stays definitive and offers review', (
      tester,
    ) async {
      final h = _Harness(
        placeHandler: (_) async =>
            _json({'message': 'Too many requests.'}, status: 429),
      );
      await _enterReview(tester, h, selectedIds: [501]);
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
      );
      await tester.pumpAndSettle();

      expect(find.text('This placement was rejected'), findsOneWidget);
      expect(find.textContaining('too many checkout requests'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-checkout-requote-after-rejection')),
        findsOneWidget,
      );
      expect(
        h.attemptStore.saved[8]?.status,
        BuyerCheckoutAttemptStatus.rejected,
      );
      expect(h.cart.cart?.items.map((item) => item.id), [501, 502]);
      expect(h.cart.selectedCartItemIds, [501]);
    });

    testWidgets('server and malformed placement responses stay ambiguous', (
      tester,
    ) async {
      for (final response in [
        _json({'message': 'Server error.'}, status: 500),
        _json({
          'data': {'id': 812},
        }),
      ]) {
        final h = _Harness(placeHandler: (_) async => response);
        await _enterReview(tester, h, selectedIds: [501]);
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Order status needs verification'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('buyer-checkout-retry-original')),
          findsOneWidget,
        );
        expect(
          h.attemptStore.saved[8]?.status,
          BuyerCheckoutAttemptStatus.indeterminate,
        );
        expect(find.byType(BuyerOrderConfirmationPage), findsNothing);
        expect(h.cart.cart?.items.map((item) => item.id), [501, 502]);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets(
      'account-switched late placement response cannot show prior order',
      (tester) async {
        final response = Completer<http.Response>();
        final started = Completer<void>();
        final h = _Harness(
          placeHandler: (_) {
            if (!started.isCompleted) started.complete();
            return response.future;
          },
        );
        await _enterReview(tester, h, selectedIds: [501]);
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-place-order')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
        );
        await tester.pump();
        await started.future;

        h.auth.currentSession = _session(9);
        response.complete(_json(_placedOrderResponse([h._cartItems.first])));
        await tester.pumpAndSettle();

        expect(find.text('BRL-ORDER-812'), findsNothing);
        expect(find.byType(BuyerOrderConfirmationPage), findsNothing);
        expect(
          h.attemptStore.saved[8]?.status,
          BuyerCheckoutAttemptStatus.indeterminate,
        );
        expect(h.attemptStore.saved[9], isNull);
      },
    );

    testWidgets('rapid repeated placement taps send one request', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      var placementCount = 0;
      final h = _Harness(
        placeHandler: (_) {
          placementCount++;
          return response.future;
        },
      );
      await _enterReview(tester, h, selectedIds: [501]);
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-confirm-placement')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('buyer-checkout-place-order')),
      );
      await tester.pump();
      expect(placementCount, 1);

      response.complete(_json(_placedOrderResponse([h._cartItems.first])));
      await tester.pumpAndSettle();
      expect(placementCount, 1);
    });
  });
}

Future<void> _loadInputs(_Harness h) async {
  await h.cart.refresh(force: true);
  await h.addresses.refresh(force: true);
}

Future<void> _enterReview(
  WidgetTester tester,
  _Harness h, {
  required List<int> selectedIds,
}) async {
  await _pumpCart(tester, h);
  for (final id in selectedIds) {
    await tester.tap(find.byKey(ValueKey('buyer-cart-select-$id')));
  }
  await tester.pump();
  await tester.ensureVisible(
    find.byKey(const ValueKey('buyer-cart-continue-checkout')),
  );
  await tester.tap(find.byKey(const ValueKey('buyer-cart-continue-checkout')));
  await tester.pumpAndSettle();
}

Future<void> _pumpReview(WidgetTester tester, _Harness h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: BuyerCheckoutReviewPage(
        reviewController: h.reviewController(),
        placementController: h.placementController(),
        addressController: h.addresses,
        locationRepository: h.locations,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCart(WidgetTester tester, _Harness h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: BuyerCartPage(cartController: h.cart),
      onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
        settings,
        authService: h.auth,
        cartController: h.cart,
        wishlistController: h.wishlist,
        addressController: h.addresses,
        locationRepository: h.locations,
        checkoutRepository: h.checkout,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness({
    List<Map<String, Object?>>? addresses,
    Future<http.Response> Function(http.Request)? quoteHandler,
    Future<http.Response> Function(http.Request)? placeHandler,
    this.failAttemptWrites = false,
    this.quoteLifetime = const Duration(minutes: 5),
  }) : _addresses = List.of(
         addresses ?? [_address(32), _address(31, isDefault: true)],
       ) {
    client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/mobile/buyer/cart') {
        return _json(_cart(_cartItems));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/mobile/buyer/addresses') {
        return _json({'data': _addresses});
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/mobile/buyer/addresses') {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final item = {
          'id': 33,
          'label': body['label'],
          'name': body['name'],
          'phone': body['phone'],
          'province': body['province'],
          'city': body['city'],
          'barangay': body['barangay'],
          'postal': body['postal'],
          'street': body['street'],
          'isDefault': false,
          'latitude': null,
          'longitude': null,
        };
        _addresses.add(item);
        return _json({'data': item});
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/mobile/buyer/checkout/quote') {
        return quoteHandler == null
            ? _json(_quoteFromRequest(request))
            : quoteHandler(request);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/mobile/buyer/checkout/place') {
        attemptStore.events.add('post');
        if (placeHandler != null) return placeHandler(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final ids = (body['cart_item_ids'] as List).cast<int>();
        final purchased = _cartItems
            .where((item) => ids.contains(item['id']))
            .toList(growable: false);
        _cartItems.removeWhere((item) => ids.contains(item['id']));
        return _json(_placedOrderResponse(purchased));
      }
      return _json({'message': 'Not found.'}, status: 404);
    });
    apiClient = ApiClient(
      httpClient: client,
      baseUri: Uri.parse('https://api.example.test'),
    );
    auth = AuthService(
      apiClient: apiClient,
      tokenStore: _MemoryTokenStore()..token = 'test-session-token',
    )..currentSession = _session(8);
    cart = BuyerCartController(authService: auth);
    addressesController = BuyerAddressController(authService: auth);
    wishlist = BuyerWishlistController(authService: auth);
    locations = BuyerLocationRepository(apiClient: apiClient);
    checkout = BuyerCheckoutRepository(
      authService: auth,
      attemptStore: attemptStore,
    );
  }

  final List<http.Request> requests = [];
  final List<Map<String, Object?>> _addresses;
  final bool failAttemptWrites;
  final Duration quoteLifetime;
  final List<Map<String, Object?>> _cartItems = [
    _cartItem(
      501,
      productId: 41,
      variantId: 701,
      storeId: 1,
      storeName: 'Alpha Shop',
    ),
    _cartItem(
      502,
      productId: 42,
      variantId: 702,
      storeId: 2,
      storeName: 'Beta Shop',
      price: 20000,
    ),
  ];
  late final _RecordingAttemptStore attemptStore = _RecordingAttemptStore(
    failWrites: failAttemptWrites,
  );
  late final MockClient client;
  late final ApiClient apiClient;
  late final AuthService auth;
  late final BuyerCartController cart;
  late final BuyerAddressController addressesController;
  late final BuyerWishlistController wishlist;
  late final BuyerLocationRepository locations;
  late final BuyerCheckoutRepository checkout;

  BuyerAddressController get addresses => addressesController;

  void removeAddress(int addressId) {
    _addresses.removeWhere((address) => address['id'] == addressId);
  }

  BuyerCheckoutReviewController reviewController() =>
      BuyerCheckoutReviewController(
        authService: auth,
        cartController: cart,
        addressController: addresses,
        checkoutRepository: checkout,
      );

  BuyerCheckoutPlacementController placementController() =>
      BuyerCheckoutPlacementController(
        authService: auth,
        checkoutRepository: checkout,
        cartController: cart,
      );

  Map<String, Object?> _quoteFromRequest(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final ids = (body['cart_item_ids'] as List).cast<int>();
    return quoteResponse(ids, addressId: body['address_id'] as int);
  }

  Map<String, Object?> quoteResponse(List<int> ids, {required int addressId}) {
    final lines = _cartItems.where((item) => ids.contains(item['id'])).toList();
    final grouped = <int, List<Map<String, Object?>>>{};
    for (final line in lines) {
      grouped.putIfAbsent(line['store_id']! as int, () => []).add(line);
    }
    int lineSubtotal(Map<String, Object?> line) =>
        (line['unit_price_minor']! as int) * (line['quantity']! as int);
    final subtotal = lines.fold<int>(
      0,
      (sum, line) => sum + lineSubtotal(line),
    );
    const shippingPerSeller = 1000;
    final shipping = grouped.length * shippingPerSeller;
    final address = _addresses.firstWhere((item) => item['id'] == addressId);
    return {
      'data': {
        'currency': 'PHP',
        'items': [
          for (final item in lines)
            {
              'cart_item_id': item['id'],
              'product_id': item['product_id'],
              'product_name': item['name'],
              'variant_id': item['product_variant_id'],
              'variant_name': item['variant_name'],
              'options': item['options'],
              'quantity': item['quantity'],
              'unit_price_minor': item['unit_price_minor'],
              'subtotal_minor': lineSubtotal(item),
              'seller_discount_minor': 0,
              'platform_discount_minor': 0,
              'total_discount_minor': 0,
              'total_minor': lineSubtotal(item),
            },
        ],
        'seller_orders': [
          for (final entry in grouped.entries)
            {
              'store_id': entry.key,
              'store_name': entry.value.first['store_name'],
              'item_count': entry.value.length,
              'subtotal_minor': entry.value.fold<int>(
                0,
                (sum, line) => sum + lineSubtotal(line),
              ),
              'seller_discount_minor': 0,
              'platform_discount_minor': 0,
              'shipping_fee_minor': shippingPerSeller,
              'shipping_discount_minor': 0,
              'total_discount_minor': 0,
              'total_minor':
                  entry.value.fold<int>(
                    0,
                    (sum, line) => sum + lineSubtotal(line),
                  ) +
                  shippingPerSeller,
            },
        ],
        'delivery_address': {
          'id': address['id'],
          'name': address['name'],
          'phone': address['phone'],
          'street': address['street'],
          'barangay': address['barangay'],
          'city': address['city'],
          'province': address['province'],
          'postal': address['postal'],
          'isDefault': address['isDefault'],
        },
        'subtotal_minor': subtotal,
        'shipping_fee_minor': shipping,
        'seller_discount_minor': 0,
        'platform_discount_minor': 0,
        'shipping_discount_minor': 0,
        'discount_minor': 0,
        'total_discount_minor': 0,
        'total_minor': subtotal + shipping,
        'payment_method': 'cod',
        'available_payment_methods': ['cod'],
        'promotion_selection': <String, Object?>{},
        'applied_promotions': <Object?>[],
        'quote_token': 'mock-quote-token',
        'quote_expires_at': DateTime.now()
            .add(quoteLifetime)
            .toUtc()
            .toIso8601String(),
      },
    };
  }
}

Map<String, Object?> _cart(List<Map<String, Object?>> items) => {
  'data': {
    'items': items,
    'cart_count': items.fold<int>(
      0,
      (sum, item) => sum + (item['quantity']! as int),
    ),
    'subtotal_minor': items.fold<int>(
      0,
      (sum, item) =>
          sum + (item['unit_price_minor']! as int) * (item['quantity']! as int),
    ),
    'currency': 'PHP',
  },
};

Map<String, Object?> _cartItem(
  int id, {
  required int productId,
  required int variantId,
  required int storeId,
  required String storeName,
  int price = 10000,
}) => {
  'id': id,
  'product_id': productId,
  'product_variant_id': variantId,
  'product': {'id': productId, 'name': 'Product $productId'},
  'variant': {
    'id': variantId,
    'name': 'Blue / Small',
    'options': {'Color': 'Blue', 'Size': 'Small'},
  },
  'name': 'Product $productId',
  'variant_name': 'Blue / Small',
  'options': {'Color': 'Blue', 'Size': 'Small'},
  'price_minor': price,
  'unit_price_minor': price,
  'line_subtotal_minor': price,
  'regular_price_minor': price,
  'discount_percent': 0,
  'campaign_name': null,
  'quantity': 1,
  'selected': false,
  'image': '',
  'image_url': null,
  'available_stock': 5,
  'in_stock': true,
  'is_available': true,
  'store_id': storeId,
  'store_name': storeName,
  'seller_name': storeName,
};

Map<String, Object?> _address(int id, {bool isDefault = false}) => {
  'id': id,
  'label': id == 31 ? 'Home' : 'Work',
  'name': id == 31 ? 'Default Buyer' : 'Alternate Buyer',
  'phone': '09170000000',
  'province': 'Laguna',
  'city': 'Santa Rosa',
  'barangay': 'Balibago',
  'postal': '4026',
  'street': 'Maple Street',
  'isDefault': isDefault,
  'latitude': null,
  'longitude': null,
};

AuthSession _session(int id) => AuthSession(
  id: id,
  name: 'Buyer $id',
  email: 'buyer$id@example.test',
  role: AccountRole.buyer,
);

http.Response _json(Object value, {int status = 200}) =>
    http.Response(jsonEncode(value), status);

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

class _RecordingAttemptStore implements BuyerCheckoutAttemptStore {
  _RecordingAttemptStore({this.failWrites = false});

  final bool failWrites;
  final Map<int, BuyerCheckoutAttempt> saved = {};
  final List<String> events = [];
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<BuyerCheckoutAttempt?> read(int buyerAccountId) async {
    readCount++;
    final attempt = saved[buyerAccountId];
    return attempt == null
        ? null
        : BuyerCheckoutAttempt.fromJson(attempt.toJson());
  }

  @override
  Future<void> write(BuyerCheckoutAttempt attempt) async {
    writeCount++;
    events.add('write-${attempt.status.name}');
    if (failWrites) throw const BuyerCheckoutAttemptStorageException();
    saved[attempt.buyerAccountId] = BuyerCheckoutAttempt.fromJson(
      attempt.toJson(),
    );
  }

  @override
  Future<void> clear(int buyerAccountId) async {
    clearCount++;
    saved.remove(buyerAccountId);
  }
}

Map<String, Object?> _placedOrderResponse(List<Map<String, Object?>> items) {
  final groups = <int, List<Map<String, Object?>>>{};
  for (final item in items) {
    groups.putIfAbsent(item['store_id']! as int, () => []).add(item);
  }
  final subtotal = items.fold<int>(
    0,
    (total, item) =>
        total + (item['unit_price_minor']! as int) * (item['quantity']! as int),
  );
  final shipping = groups.length * 1000;
  return {
    'data': {
      'id': 812,
      'order_reference': 'BRL-ORDER-812',
      'status': 'processing',
      'payment_method': 'cod',
      'payment_status': 'unpaid',
      'initial_payment_state': 'pending',
      'currency': 'PHP',
      'subtotal_minor': subtotal,
      'shipping_fee_minor': shipping,
      'discount_minor': 0,
      'platform_discount_minor': 0,
      'campaign_platform_discount_minor': 0,
      'shipping_discount_minor': 0,
      'total_minor': subtotal + shipping,
      'created_at': '2026-10-24T12:00:00Z',
      'placed_at': '2026-10-24T12:00:00Z',
      'seller_orders': [
        for (final entry in groups.entries)
          {
            'id': 900 + entry.key,
            'seller_order_reference': 'SO-${entry.key}',
            'store_id': entry.key,
            'store_name': entry.value.first['store_name'],
            'status': 'pending',
            'item_count': entry.value.fold<int>(
              0,
              (sum, item) => sum + (item['quantity']! as int),
            ),
          },
      ],
    },
  };
}
