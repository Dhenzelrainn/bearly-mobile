import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Rider sessions cannot mutate the Buyer cart', () async {
    var requestCount = 0;
    final h = _Harness((request) async {
      requestCount++;
      return _json(_cart([]));
    });
    h.auth.currentSession = const AuthSession(
      id: 77,
      name: 'Rider Test',
      email: 'rider@example.test',
      role: AccountRole.rider,
    );

    await expectLater(
      h.cartController.addItem(productVariantId: 1, quantity: 1),
      throwsA(isA<AuthException>()),
    );
    expect(requestCount, 0);
  });

  group('Buyer Product Detail cart integration', () {
    testWidgets('adds with the selected numeric Laravel variant ID', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(variants: [_variant(73)]),
          });
        }
        if (_isCart(request)) return _json(_cart([]));
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      await _tapAdd(tester);

      final add = requests.singleWhere((request) => request.method == 'POST');
      expect(add.url.path, '/api/mobile/buyer/cart/items');
      expect(jsonDecode(add.body), {'product_variant_id': 73, 'quantity': 1});
      expect(find.text('Added to your cart.'), findsOneWidget);
    });

    testWidgets('Color and Size resolve the exact existing variant', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(
              variants: [
                _variant(101, color: 'Blue', size: 'Small', price: 10000),
                _variant(102, color: 'Blue', size: 'Large', price: 11000),
                _variant(103, color: 'Green', size: 'Small', price: 12000),
                _variant(104, color: 'Green', size: 'Large', price: 13000),
              ],
            ),
          });
        }
        if (_isCart(request)) return _json(_cart([]));
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      await tester.tap(find.byKey(const ValueKey('buyer-option-Color-Green')));
      await tester.tap(find.byKey(const ValueKey('buyer-option-Size-Large')));
      await tester.pumpAndSettle();
      await _tapAdd(tester);

      final add = requests.singleWhere((request) => request.method == 'POST');
      expect(jsonDecode(add.body)['product_variant_id'], 104);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-detail-price')))
            .data,
        '₱130.00',
      );
    });

    testWidgets('a missing option combination is visibly unavailable', (
      tester,
    ) async {
      final h = _Harness((request) async {
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(
              variants: [
                _variant(201, color: 'Blue', size: 'Small'),
                _variant(202, color: 'Green', size: 'Large'),
              ],
            ),
          });
        }
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-option-Color-Green')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-option-Color-Green')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-option-Size-Small')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-option-Size-Small')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('buyer-detail-combination-unavailable')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('buyer-detail-add-to-cart')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('changing a variant updates price and stock availability', (
      tester,
    ) async {
      final h = _Harness((request) async {
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(
              variants: [
                _variant(301, color: 'Blue', size: 'Small', price: 10000),
                _variant(
                  302,
                  color: 'Blue',
                  size: 'Large',
                  price: 15000,
                  inStock: false,
                ),
              ],
            ),
          });
        }
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-detail-price')))
            .data,
        '₱100.00',
      );
      await tester.tap(find.byKey(const ValueKey('buyer-option-Size-Large')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-detail-price')))
            .data,
        '₱150.00',
      );
      expect(find.text('Out of stock'), findsWidgets);
    });

    testWidgets('a single default variant is directly addable', (tester) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(variants: [_variant(701, options: {})]),
          });
        }
        if (_isCart(request)) return _json(_cart([]));
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      await _tapAdd(tester);

      expect(
        jsonDecode(
          requests.singleWhere((request) => request.method == 'POST').body,
        )['product_variant_id'],
        701,
      );
    });

    testWidgets('irregular option data uses the safe real-variant selector', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(
              variants: [
                _variant(801, options: {'Color': 'Blue'}),
                _variant(802, options: {'Size': 'Large'}),
              ],
            ),
          });
        }
        if (_isCart(request)) return _json(_cart([]));
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      expect(find.byKey(const ValueKey('buyer-variant-801')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('buyer-variant-802')));
      await _tapAdd(tester);

      expect(
        jsonDecode(
          requests.singleWhere((request) => request.method == 'POST').body,
        )['product_variant_id'],
        802,
      );
    });

    testWidgets('quantity is sent with the selected variant', (tester) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(variants: [_variant(901)]),
          });
        }
        if (_isCart(request)) return _json(_cart([]));
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      await tester.tap(
        find.byKey(const ValueKey('buyer-detail-quantity-plus')),
      );
      await tester.tap(
        find.byKey(const ValueKey('buyer-detail-quantity-plus')),
      );
      await _tapAdd(tester);

      final body =
          jsonDecode(
                requests
                    .singleWhere((request) => request.method == 'POST')
                    .body,
              )
              as Map<String, dynamic>;
      expect(body, {'product_variant_id': 901, 'quantity': 3});
    });

    testWidgets('rapid Add to Cart taps submit only one pending request', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      var addCount = 0;
      final h = _Harness((request) async {
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(variants: [_variant(1001)]),
          });
        }
        if (request.method == 'POST') {
          addCount++;
          return response.future;
        }
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      final button = find.byKey(const ValueKey('buyer-detail-add-to-cart'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(addCount, 1);

      response.complete(
        _json(
          _cart([
            _cartItem(1101, variantId: 1001),
          ], mutationItem: _cartItem(1101, variantId: 1001)),
        ),
      );
      await tester.pumpAndSettle();
      expect(addCount, 1);
    });

    testWidgets('multi-variant product card quick-add opens selection first', (
      tester,
    ) async {
      var addCount = 0;
      final h = _Harness((request) async {
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(
              variants: [
                _variant(1101, color: 'Blue', size: 'Small'),
                _variant(1102, color: 'Green', size: 'Large'),
              ],
            ),
          });
        }
        if (request.method == 'POST') addCount++;
        return _catalogResponse(request);
      });
      await _pumpHome(tester, h);
      await tester.tap(find.byKey(const ValueKey('buyer-add-cart-41')));
      await tester.pumpAndSettle();

      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(addCount, 0);
    });

    testWidgets('successful Add to Cart appears in the shared cart page', (
      tester,
    ) async {
      final currentItems = <Map<String, Object?>>[];
      final h = _Harness((request) async {
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(variants: [_variant(1201)]),
          });
        }
        if (request.method == 'POST') {
          final item = _cartItem(1202, variantId: 1201);
          currentItems
            ..clear()
            ..add(item);
          return _json(_cart([item], mutationItem: item));
        }
        if (_isCart(request)) return _json(_cart(currentItems));
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      await _tapAdd(tester);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cart'));
      await tester.pumpAndSettle();

      expect(find.text('Handmade Bear'), findsOneWidget);
      expect(find.text('Bearly Studio'), findsOneWidget);
      expect(find.text('Color: Blue · Size: Small'), findsOneWidget);
    });

    testWidgets('stock validation failure never reports success', (
      tester,
    ) async {
      final h = _Harness((request) async {
        if (_isProductDetail(request)) {
          return _json({
            'data': _product(variants: [_variant(1301)]),
          });
        }
        if (request.method == 'POST') {
          return _json({
            'message': 'The given data was invalid.',
            'errors': {
              'quantity': ['Only 2 item(s) are currently available.'],
            },
          }, 422);
        }
        return _catalogResponse(request);
      });
      await _openProduct(tester, h);
      await _tapAdd(tester);

      expect(
        find.text('Only 2 item(s) are currently available.'),
        findsOneWidget,
      );
      expect(find.text('Added to your cart.'), findsNothing);
    });
  });

  group('Buyer Cart screen integration', () {
    testWidgets('fetches and renders the Laravel cart response', (
      tester,
    ) async {
      final h = _Harness((request) async {
        if (_isCart(request)) {
          return _json(_cart([_cartItem(1501, quantity: 2)], count: 2));
        }
        return _catalogResponse(request);
      });
      await _openCart(tester, h);

      expect(find.text('Handmade Bear'), findsOneWidget);
      expect(find.byKey(const ValueKey('buyer-cart-count')), findsOneWidget);
      expect(find.text('₱100.00'), findsOneWidget);
    });

    testWidgets('empty cart has a Shop path and no fake products', (
      tester,
    ) async {
      final h = _Harness((request) async {
        if (_isCart(request)) return _json(_cart([]));
        return _catalogResponse(request);
      });
      await _openCart(tester, h);

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Classic Linen Shirt'), findsNothing);
      expect(
        find.byKey(const ValueKey('buyer-cart-empty-shop')),
        findsOneWidget,
      );
    });

    testWidgets('server quantities, warnings, and subtotal are displayed', (
      tester,
    ) async {
      final h = _Harness((request) async {
        if (_isCart(request)) {
          return _json(
            _cart(
              [
                _cartItem(1601, quantity: 4, stock: 2, isAvailable: false),
                _cartItem(1602, quantity: 2, unitPrice: 25000),
              ],
              count: 6,
              subtotal: 90000,
            ),
          );
        }
        return _catalogResponse(request);
      });
      await _openCart(tester, h);

      expect(find.text('6 items in your cart'), findsOneWidget);
      expect(
        find.text('Only 2 available. Adjust the quantity before checkout.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-cart-subtotal')))
            .data,
        '₱900.00',
      );
      expect(find.text('₱250.00'), findsOneWidget);
    });

    testWidgets('quantity update PATCH targets the cart-item ID', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isCart(request)) {
          return _json(_cart([_cartItem(1701, quantity: 2)], count: 2));
        }
        if (request.method == 'PATCH') {
          final item = _cartItem(1701, quantity: 3);
          return _json(_cart([item], mutationItem: item, count: 3));
        }
        return _catalogResponse(request);
      });
      await _openCart(tester, h);
      await tester.tap(
        find.byKey(const ValueKey('buyer-cart-quantity-plus-1701')),
      );
      await tester.pumpAndSettle();

      final update = requests.singleWhere(
        (request) => request.method == 'PATCH',
      );
      expect(update.url.path, '/api/mobile/buyer/cart/items/1701');
      expect(jsonDecode(update.body), {'quantity': 3});
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('buyer-cart-quantity-1701')),
            )
            .data,
        '3',
      );
    });

    testWidgets('remove DELETE targets only the selected cart-item ID', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isCart(request)) {
          return _json(
            _cart([_cartItem(1801), _cartItem(1802, name: 'Other Bear')]),
          );
        }
        if (request.method == 'DELETE') {
          return _json(_cart([_cartItem(1802, name: 'Other Bear')]));
        }
        return _catalogResponse(request);
      });
      await _openCart(tester, h);
      await tester.tap(find.byKey(const ValueKey('buyer-cart-remove-1801')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('buyer-cart-confirm-remove')));
      await tester.pumpAndSettle();

      final remove = requests.singleWhere(
        (request) => request.method == 'DELETE',
      );
      expect(remove.url.path, '/api/mobile/buyer/cart/items/1801');
      expect(find.text('Handmade Bear'), findsNothing);
      expect(find.text('Other Bear'), findsOneWidget);
    });

    testWidgets('server response replaces cart after a successful mutation', (
      tester,
    ) async {
      final h = _Harness((request) async {
        if (_isCart(request)) {
          return _json(_cart([_cartItem(1901, quantity: 1)]));
        }
        if (request.method == 'PATCH') {
          final item = _cartItem(1901, quantity: 4, unitPrice: 23000);
          return _json(
            _cart([item], mutationItem: item, count: 4, subtotal: 92000),
          );
        }
        return _catalogResponse(request);
      });
      await _openCart(tester, h);
      await tester.tap(
        find.byKey(const ValueKey('buyer-cart-quantity-plus-1901')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('buyer-cart-quantity-1901')),
            )
            .data,
        '4',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-cart-subtotal')))
            .data,
        '₱920.00',
      );
    });

    testWidgets('failed cart load can be retried without demo fallback', (
      tester,
    ) async {
      var cartRequests = 0;
      final h = _Harness((request) async {
        if (_isCart(request)) {
          cartRequests++;
          if (cartRequests == 1) throw http.ClientException('offline');
          return _json(_cart([]));
        }
        return _catalogResponse(request);
      });
      await _openCart(tester, h);
      expect(
        find.byKey(const ValueKey('buyer-cart-load-error')),
        findsOneWidget,
      );
      expect(find.text('Classic Linen Shirt'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(cartRequests, 2);
      expect(find.text('Your cart is empty'), findsOneWidget);
    });

    testWidgets('401 clears cached cart state and offers sign-in', (
      tester,
    ) async {
      var cartRequests = 0;
      final h = _Harness((request) async {
        if (_isCart(request)) {
          cartRequests++;
          if (cartRequests == 1) return _json(_cart([_cartItem(2001)]));
          return _json({'message': 'Unauthenticated.'}, 401);
        }
        return _catalogResponse(request);
      });
      await _openCart(tester, h);
      expect(find.text('Handmade Bear'), findsOneWidget);
      await h.cartController.refresh(force: true);
      await tester.pumpAndSettle();

      expect(h.auth.currentSession, isNull);
      expect(find.text('Handmade Bear'), findsNothing);
      expect(find.text('Sign in again'), findsOneWidget);
    });

    testWidgets('changing Buyer account clears the previous account cart', (
      tester,
    ) async {
      final responses = <int, Map<String, Object?>>{
        8: _cart([_cartItem(2101, name: 'Buyer Eight Item')]),
        9: _cart([_cartItem(2102, name: 'Buyer Nine Item')]),
      };
      late final _Harness h;
      h = _Harness((request) async {
        if (_isCart(request)) return _json(responses[h.accountId]!);
        return _catalogResponse(request);
      });
      await _openCart(tester, h);
      expect(find.text('Buyer Eight Item'), findsOneWidget);
      h.accountId = 9;
      h.auth.currentSession = _buyerSession(9);
      h.cartController.synchronizeSession();
      await tester.pump();

      expect(find.text('Buyer Eight Item'), findsNothing);
      await h.cartController.refresh(force: true);
      await tester.pumpAndSettle();
      expect(find.text('Buyer Nine Item'), findsOneWidget);
    });

    testWidgets('empty selection cannot continue or call checkout APIs', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final h = _Harness((request) async {
        requests.add(request);
        if (_isCart(request)) return _json(_cart([_cartItem(2201)]));
        return _catalogResponse(request);
      });
      await _openCart(tester, h);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('buyer-cart-continue-checkout')),
            )
            .onPressed,
        isNull,
      );

      expect(
        requests.every((request) => !request.url.path.contains('/orders')),
        isTrue,
      );
      expect(
        requests.every((request) => !request.url.path.contains('/checkout')),
        isTrue,
      );
    });
  });
}

class _Harness {
  _Harness(this.handler) {
    auth = AuthService(
      apiClient: ApiClient(
        httpClient: MockClient(handler),
        baseUri: Uri.parse('https://api.example.test'),
      ),
      tokenStore: _MemoryTokenStore()..token = 'mock-token',
    );
    auth.currentSession = _buyerSession(accountId);
    cartController = BuyerCartController(authService: auth);
    wishlistController = BuyerWishlistController(authService: auth);
  }

  final Future<http.Response> Function(http.Request) handler;
  late final AuthService auth;
  late final BuyerCartController cartController;
  late final BuyerWishlistController wishlistController;
  int accountId = 8;
}

Future<void> _pumpHome(WidgetTester tester, _Harness h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: BuyerHomePage(
        authService: h.auth,
        cartController: h.cartController,
        wishlistController: h.wishlistController,
      ),
      onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
        settings,
        authService: h.auth,
        cartController: h.cartController,
        wishlistController: h.wishlistController,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openProduct(WidgetTester tester, _Harness h) async {
  await _pumpHome(tester, h);
  await tester.tap(find.byKey(const ValueKey('buyer-product-41')));
  await tester.pumpAndSettle();
}

Future<void> _openCart(WidgetTester tester, _Harness h) async {
  await _pumpHome(tester, h);
  await tester.tap(find.byTooltip('Cart'));
  await tester.pumpAndSettle();
}

Future<void> _tapAdd(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('buyer-detail-add-to-cart'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

bool _isProductDetail(http.Request request) =>
    request.method == 'GET' &&
    request.url.path == '/api/mobile/buyer/products/41';

bool _isCart(http.Request request) =>
    request.method == 'GET' && request.url.path == '/api/mobile/buyer/cart';

Future<http.Response> _catalogResponse(http.Request request) async {
  if (request.url.path == '/api/mobile/buyer/wishlist' &&
      request.method == 'GET') {
    return _json({
      'data': [],
      'meta': {
        'current_page': 1,
        'per_page': 12,
        'total': 0,
        'last_page': 1,
        'has_more': false,
      },
    });
  }
  if (request.url.path.startsWith('/api/mobile/buyer/wishlist/') &&
      (request.method == 'PUT' || request.method == 'DELETE')) {
    final id = int.parse(request.url.path.split('/').last);
    return _json({
      'data': {'product_id': id, 'is_saved': request.method == 'PUT'},
    });
  }
  if (request.method == 'POST' &&
      request.url.path == '/api/mobile/buyer/cart/items') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final quantity = body['quantity'] as int;
    final item = _cartItem(
      9901,
      variantId: body['product_variant_id'] as int,
      quantity: quantity,
    );
    return _json(
      _cart(
        [item],
        mutationItem: item,
        count: quantity,
        subtotal: 10000 * quantity,
      ),
    );
  }
  if (request.url.path == '/api/mobile/buyer/categories') {
    return _json({'data': []});
  }
  if (request.url.path == '/api/mobile/buyer/products') {
    return _json(
      _catalog([
        _product(variants: [_variant(71)]),
      ]),
    );
  }
  return _json({'message': 'Not found.'}, 404);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> _catalog(List<Map<String, Object?>> products) => {
  'data': products,
  'meta': {
    'current_page': 1,
    'per_page': 12,
    'total': products.length,
    'last_page': 1,
    'has_more': false,
  },
  'filters': {'search': '', 'category': null, 'sort': 'featured'},
};

Map<String, Object?> _product({
  int id = 41,
  List<Map<String, Object?>> variants = const [],
}) => {
  'id': id,
  'slug': 'handmade-bear-$id',
  'name': 'Handmade Bear',
  'description': 'Soft bear.',
  'description_summary': 'A soft handmade bear.',
  'store': {'name': 'Bearly Studio', 'slug': 'bearly-studio'},
  'category': null,
  'price_minor': 10000,
  'regular_price_minor': 12000,
  'discount_percent': 17,
  'currency': 'PHP',
  'image_url': null,
  'in_stock': true,
  'variants': variants,
  'rating_summary': {'average': 4.5, 'count': 1},
  'images': [],
};

Map<String, Object?> _variant(
  int id, {
  String color = 'Blue',
  String size = 'Small',
  int price = 10000,
  bool inStock = true,
  Map<String, Object?>? options,
}) => {
  'id': id,
  'name': '$color / $size',
  'options': options ?? {'Color': color, 'Size': size},
  'price_minor': price,
  'regular_price_minor': price + 2000,
  'discount_percent': 17,
  'currency': 'PHP',
  'in_stock': inStock,
};

Map<String, Object?> _cart(
  List<Map<String, Object?>> items, {
  Map<String, Object?>? mutationItem,
  int? count,
  int? subtotal,
}) => {
  'data': {
    'items': items,
    'cart_count':
        count ??
        items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int)),
    'subtotal_minor':
        subtotal ??
        items.fold<int>(
          0,
          (sum, item) => sum + (item['line_subtotal_minor'] as int),
        ),
    'currency': 'PHP',
    'item': ?mutationItem,
  },
};

Map<String, Object?> _cartItem(
  int id, {
  int variantId = 73,
  int quantity = 1,
  String name = 'Handmade Bear',
  int unitPrice = 10000,
  int stock = 8,
  bool isAvailable = true,
}) => {
  'id': id,
  'product_id': 41,
  'product_variant_id': variantId,
  'product': {'id': 41, 'name': name},
  'variant': {
    'id': variantId,
    'name': 'Blue / Small',
    'options': {'Color': 'Blue', 'Size': 'Small'},
  },
  'name': name,
  'variant_name': 'Blue / Small',
  'options': {'Color': 'Blue', 'Size': 'Small'},
  'price_minor': unitPrice,
  'unit_price_minor': unitPrice,
  'line_subtotal_minor': unitPrice * quantity,
  'regular_price_minor': unitPrice + 2000,
  'discount_percent': 17,
  'campaign_name': null,
  'quantity': quantity,
  'selected': true,
  'image': '',
  'image_url': null,
  'available_stock': stock,
  'in_stock': stock > 0,
  'is_available': isAvailable,
  'store_name': 'Bearly Studio',
  'seller_name': 'Bearly Studio',
};

AuthSession _buyerSession(int id) => AuthSession(
  id: id,
  name: 'Buyer $id',
  email: 'buyer$id@example.test',
  role: AccountRole.buyer,
);

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}
