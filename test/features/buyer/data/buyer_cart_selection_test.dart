import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Buyer Cart line selection', () {
    test('selection uses cart-item IDs and keeps variant quantities', () async {
      final h = _Harness(
        (_) async => _json(
          _cart([
            _item(501, productId: 41, variantId: 701, quantity: 2),
            _item(502, productId: 41, variantId: 702, quantity: 3),
          ]),
        ),
      );
      await h.cart.refresh(force: true);

      expect(h.cart.setItemSelected(501, true), isTrue);
      expect(h.cart.setItemSelected(502, true), isTrue);
      expect(h.cart.selectedCartItemIds, [501, 502]);
      expect(h.cart.selectedCount, 2);
      expect(h.cart.selectedQuantityCount, 5);
      expect(h.cart.selectedSubtotalMinor, 50000);
    });

    test('select all and deselect all update only local state', () async {
      var mutationRequests = 0;
      final h = _Harness((request) async {
        if (request.method != 'GET') mutationRequests++;
        return _json(_cart([_item(601), _item(602)]));
      });
      await h.cart.refresh(force: true);

      expect(h.cart.selectAllAvailableItems(), isTrue);
      expect(h.cart.selectedCartItemIds, [601, 602]);
      expect(h.cart.areAllAvailableItemsSelected, isTrue);
      h.cart.deselectAllItems();
      expect(h.cart.selectedCount, 0);
      expect(mutationRequests, 0);
    });

    test('unavailable lines cannot be selected', () async {
      final h = _Harness(
        (_) async => _json(_cart([_item(611, available: false)])),
      );
      await h.cart.refresh(force: true);

      expect(h.cart.setItemSelected(611, true), isFalse);
      expect(h.cart.selectAllAvailableItems(), isTrue);
      expect(h.cart.selectedCount, 0);
    });

    test(
      'remove and refresh reconcile selection to available current IDs',
      () async {
        var cartFetches = 0;
        final h = _Harness((request) async {
          if (request.method == 'DELETE') {
            return _json(_cart([_item(622)]));
          }
          cartFetches++;
          return _json(
            cartFetches == 1
                ? _cart([_item(621), _item(622)])
                : _cart([_item(622), _item(623, available: false)]),
          );
        });
        await h.cart.refresh(force: true);
        h.cart.setItemSelected(621, true);
        h.cart.setItemSelected(622, true);
        await h.cart.removeItem(621);
        expect(h.cart.selectedCartItemIds, [622]);

        await h.cart.refresh(force: true);
        expect(h.cart.selectedCartItemIds, [622]);
        expect(h.cart.setItemSelected(623, true), isFalse);
      },
    );

    test('selection respects the 100 distinct cart-item API limit', () async {
      final items = [for (var id = 1; id <= 101; id++) _item(id)];
      final h = _Harness((_) async => _json(_cart(items)));
      await h.cart.refresh(force: true);

      expect(h.cart.selectAllAvailableItems(), isFalse);
      for (var id = 1; id <= 100; id++) {
        expect(h.cart.setItemSelected(id, true), isTrue);
      }
      expect(h.cart.selectedCount, 100);
      expect(h.cart.setItemSelected(101, true), isFalse);
    });

    test('selection is cleared when the authenticated Buyer changes', () async {
      final h = _Harness((_) async => _json(_cart([_item(708)])));
      await h.cart.refresh(force: true);
      h.cart.setItemSelected(708, true);
      h.auth.currentSession = _session(9);
      expect(h.cart.synchronizeSession(), isTrue);
      expect(h.cart.selectedCount, 0);
      expect(h.cart.cart, isNull);
    });
  });
}

class _Harness {
  _Harness(Future<http.Response> Function(http.Request) handler) {
    auth = AuthService(
      apiClient: ApiClient(
        httpClient: MockClient(handler),
        baseUri: Uri.parse('https://api.example.test'),
      ),
      tokenStore: _MemoryTokenStore()..token = 'mock-session-token',
    )..currentSession = _session(8);
    cart = BuyerCartController(authService: auth);
  }

  late final AuthService auth;
  late final BuyerCartController cart;
}

AuthSession _session(int id) => AuthSession(
  id: id,
  name: 'Buyer $id',
  email: 'buyer$id@example.test',
  role: AccountRole.buyer,
);

http.Response _json(Object value) => http.Response(jsonEncode(value), 200);

Map<String, Object?> _cart(List<Map<String, Object?>> items) => {
  'data': {
    'items': items,
    'cart_count': items.fold<int>(
      0,
      (count, item) => count + (item['quantity'] as int),
    ),
    'subtotal_minor': items.fold<int>(
      0,
      (total, item) => total + (item['line_subtotal_minor'] as int),
    ),
    'currency': 'PHP',
  },
};

Map<String, Object?> _item(
  int id, {
  int productId = 41,
  int variantId = 701,
  int quantity = 1,
  bool available = true,
}) => {
  'id': id,
  'product_id': productId,
  'product_variant_id': variantId,
  'product': {'id': productId, 'name': 'Bear $id'},
  'variant': {
    'id': variantId,
    'name': 'Blue / Small',
    'options': {'Color': 'Blue', 'Size': 'Small'},
  },
  'name': 'Bear $id',
  'variant_name': 'Blue / Small',
  'options': {'Color': 'Blue', 'Size': 'Small'},
  'price_minor': 10000,
  'unit_price_minor': 10000,
  'line_subtotal_minor': 10000 * quantity,
  'regular_price_minor': 11000,
  'discount_percent': 0,
  'campaign_name': null,
  'quantity': quantity,
  'selected': false,
  'image': '',
  'image_url': null,
  'available_stock': available ? 8 : 0,
  'in_stock': available,
  'is_available': available,
  'store_name': 'Bearly Studio',
  'seller_name': 'Bearly Studio',
};

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}
