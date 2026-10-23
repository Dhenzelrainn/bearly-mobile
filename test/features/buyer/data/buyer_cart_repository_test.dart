import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BuyerCartRepository', () {
    test('distinguishes a successfully retrieved empty cart', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _jsonResponse(_cartResponse());
      });

      final cart = await repository.fetchCart();

      expect(request.method, 'GET');
      expect(request.url.path, '/api/mobile/buyer/cart');
      expect(request.headers['authorization'], 'Bearer test-session-token');
      expect(cart.items, isEmpty);
      expect(cart.cartCount, 0);
      expect(cart.subtotalMinor, 0);
      expect(cart.currency, 'PHP');
    });

    test(
      'parses item, product, variant IDs and minor-unit totals separately',
      () async {
        final repository = _repository(
          (_) async => _jsonResponse(_cartResponse(items: [_item()])),
        );

        final cart = await repository.fetchCart();
        final item = cart.items.single;

        expect(item.id, 71); // cart_items.id
        expect(item.productId, 41);
        expect(item.productVariantId, 9);
        expect(item.product?.id, 41);
        expect(item.variant?.id, 9);
        expect(item.variant?.options, {'Color': 'Honey', 'Size': 'Large'});
        expect(item.quantity, 2);
        expect(item.priceMinor, 12500);
        expect(item.unitPriceMinor, 12500);
        expect(item.lineSubtotalMinor, 25000);
        expect(item.regularPriceMinor, 15000);
        expect(item.availableStock, 3);
        expect(item.inStock, isTrue);
        expect(item.isAvailable, isTrue);
        expect(item.storeName, 'Bearly Studio');
        expect(item.imageUrl, 'https://cdn.example.test/products/bear.jpg');
        expect(cart.cartCount, 2);
        expect(cart.subtotalMinor, 25000);
        expect(cart.mutationItem, isNull);
      },
    );

    test(
      'parses a cart with multiple distinct items and authoritative totals',
      () async {
        final first = _item();
        final second = _item()
          ..['id'] = 72
          ..['product_id'] = 42
          ..['product_variant_id'] = 10
          ..['product'] = {'id': 42, 'name': 'Small Bear'}
          ..['variant'] = {
            'id': 10,
            'name': 'Cream / Small',
            'options': {'Color': 'Cream', 'Size': 'Small'},
          }
          ..['quantity'] = 1
          ..['price_minor'] = 3500
          ..['unit_price_minor'] = 3500
          ..['line_subtotal_minor'] = 3500
          ..['regular_price_minor'] = 3500;
        final repository = _repository(
          (_) async => _jsonResponse(_cartResponse(items: [first, second])),
        );

        final cart = await repository.fetchCart();

        expect(cart.items.map((item) => item.id), [71, 72]);
        expect(cart.items.map((item) => item.productId), [41, 42]);
        expect(cart.items.map((item) => item.productVariantId), [9, 10]);
        expect(cart.cartCount, 3);
        expect(cart.subtotalMinor, 28500);
      },
    );

    test(
      'adds a variant and exposes returned item with authoritative cart',
      () async {
        late http.Request request;
        final item = _item();
        final repository = _repository((incoming) async {
          request = incoming;
          return _jsonResponse(
            _cartResponse(items: [item], mutationItem: item),
          );
        });

        final cart = await repository.addItem(productVariantId: 9, quantity: 2);

        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/buyer/cart/items');
        expect(jsonDecode(request.body), {
          'product_variant_id': 9,
          'quantity': 2,
        });
        expect(request.body, isNot(contains('price')));
        expect(cart.items.single.id, 71);
        expect(cart.mutationItem?.id, 71);
      },
    );

    test(
      'supports product_id addition and quantity updates by cart-item ID',
      () async {
        late http.Request addRequest;
        late http.Request updateRequest;
        final item = _item()
          ..['quantity'] = 3
          ..['line_subtotal_minor'] = 37500;
        final repository = _repository((incoming) async {
          if (incoming.method == 'POST') {
            addRequest = incoming;
          } else {
            updateRequest = incoming;
          }
          return _jsonResponse(
            _cartResponse(items: [item], mutationItem: item),
          );
        });

        await repository.addItem(productId: 41, quantity: 1);
        final updated = await repository.updateQuantity(
          cartItemId: 71,
          quantity: 3,
        );

        expect(jsonDecode(addRequest.body), {'product_id': 41, 'quantity': 1});
        expect(updateRequest.method, 'PATCH');
        expect(updateRequest.url.path, '/api/mobile/buyer/cart/items/71');
        expect(jsonDecode(updateRequest.body), {'quantity': 3});
        expect(updated.mutationItem?.id, 71);
        expect(updated.mutationItem?.quantity, 3);
        expect(updated.cartCount, 3);
      },
    );

    test('removes by cart-item ID and parses the updated empty cart', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _jsonResponse(_cartResponse());
      });

      final cart = await repository.removeItem(71);

      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/mobile/buyer/cart/items/71');
      expect(cart.items, isEmpty);
      expect(cart.cartCount, 0);
      expect(cart.mutationItem, isNull);
    });

    test(
      'preserves Laravel stock validation details and does not fake an empty cart',
      () async {
        final store = MemoryTokenStore()..token = 'test-session-token';
        final repository = _repository(
          (_) async => _jsonResponse({
            'message': 'The given data was invalid.',
            'errors': {
              'quantity': ['Only 2 item(s) are currently available.'],
            },
          }, 422),
          store: store,
        );

        await expectLater(
          repository.addItem(productVariantId: 9, quantity: 9),
          throwsA(
            isA<ApiHttpException>()
                .having((error) => error.statusCode, 'statusCode', 422)
                .having(
                  (error) => error.validationErrors['quantity'],
                  'quantity errors',
                  ['Only 2 item(s) are currently available.'],
                ),
          ),
        );
        expect(store.token, 'test-session-token');
      },
    );

    test(
      'rejects malformed cart contracts and invalid local arguments',
      () async {
        final repository = _repository(
          (_) async => _jsonResponse({
            'data': {'items': []},
          }),
        );

        await expectLater(
          repository.fetchCart(),
          throwsA(isA<BuyerShoppingFormatException>()),
        );
        expect(
          () => repository.addItem(quantity: 1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => repository.updateQuantity(cartItemId: 71, quantity: 0),
          throwsA(isA<RangeError>()),
        );
      },
    );
  });
}

BuyerCartRepository _repository(
  Future<http.Response> Function(http.Request) handler, {
  MemoryTokenStore? store,
}) => BuyerCartRepository(
  authService: AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: store ?? (MemoryTokenStore()..token = 'test-session-token'),
  ),
);

Map<String, Object?> _cartResponse({
  List<Map<String, Object?>> items = const [],
  Map<String, Object?>? mutationItem,
}) => {
  'data': {
    'items': items,
    'cart_count': items.fold<int>(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    ),
    'subtotal_minor': items.fold<int>(
      0,
      (sum, item) => sum + (item['line_subtotal_minor'] as int),
    ),
    'currency': 'PHP',
    'item': ?mutationItem,
  },
  'message': 'Cart retrieved successfully.',
};

Map<String, Object?> _item() => {
  'id': 71,
  'product_id': 41,
  'product_variant_id': 9,
  'product': {'id': 41, 'name': 'Handmade Bear'},
  'variant': {
    'id': 9,
    'name': 'Honey / Large',
    'options': {'Color': 'Honey', 'Size': 'Large'},
  },
  'name': 'Handmade Bear',
  'variant_name': 'Honey / Large',
  'options': {'Color': 'Honey', 'Size': 'Large'},
  'price_minor': 12500,
  'unit_price_minor': 12500,
  'line_subtotal_minor': 25000,
  'regular_price_minor': 15000,
  'discount_percent': 17,
  'campaign_name': null,
  'quantity': 2,
  'selected': true,
  'image': 'https://cdn.example.test/products/bear.jpg',
  'image_url': 'https://cdn.example.test/products/bear.jpg',
  'available_stock': 3,
  'in_stock': true,
  'is_available': true,
  'store_name': 'Bearly Studio',
  'seller_name': 'Bearly Studio',
};

http.Response _jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response(jsonEncode(value), statusCode);

class MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
