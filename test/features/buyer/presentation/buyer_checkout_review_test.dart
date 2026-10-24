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
import 'package:bearly_mobile/features/buyer/data/buyer_checkout_review_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_location_repository.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_catalog_models.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_checkout_attempt.dart';
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
      expect(h.attemptStore.readCount, 0);
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
      expect(find.text('Place Order'), findsNothing);
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
      expect(h.attemptStore.readCount + h.attemptStore.writeCount, 0);
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
  });
}

Future<void> _loadInputs(_Harness h) async {
  await h.cart.refresh(force: true);
  await h.addresses.refresh(force: true);
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
  final _RecordingAttemptStore attemptStore = _RecordingAttemptStore();
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
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<BuyerCheckoutAttempt?> read(int buyerAccountId) async {
    readCount++;
    return null;
  }

  @override
  Future<void> write(BuyerCheckoutAttempt attempt) async {
    writeCount++;
  }

  @override
  Future<void> clear(int buyerAccountId) async {
    clearCount++;
  }
}
