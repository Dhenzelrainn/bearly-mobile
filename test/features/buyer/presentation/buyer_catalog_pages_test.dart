import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/core/network/api_client.dart';
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
  group('Buyer catalog screens', () {
    testWidgets('Buyer Home and Shop render real API product data', (
      tester,
    ) async {
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({
            'data': [_category()],
          });
        }
        return _jsonResponse(_page([_product()]));
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();

      expect(find.text('Marketplace products'), findsOneWidget);
      expect(find.text('Handmade Bear'), findsOneWidget);
      expect(find.text('Bearly Studio'), findsOneWidget);
      expect(find.text('₱125.00'), findsOneWidget);
      expect(find.text('Home and Furniture'), findsOneWidget);
    });

    testWidgets('search, category, and sort use supported Laravel parameters', (
      tester,
    ) async {
      final productRequests = <Uri>[];
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({
            'data': [_category()],
          });
        }
        productRequests.add(request.url);
        return _jsonResponse(_page([]));
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-category-home-and-furniture')),
      );
      await tester.pumpAndSettle();
      expect(
        productRequests.last.queryParameters['category'],
        'home-and-furniture',
      );

      await tester.tap(find.byKey(const ValueKey('buyer-catalog-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price: low to high').last);
      await tester.pumpAndSettle();
      expect(productRequests.last.queryParameters['sort'], 'price_low');

      await tester.enterText(
        find.byKey(const ValueKey('buyer-catalog-search')),
        'linen',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(productRequests.last.queryParameters['search'], 'linen');
      expect(
        productRequests.last.queryParameters['category'],
        'home-and-furniture',
      );
      expect(productRequests.last.queryParameters['sort'], 'price_low');
      expect(productRequests.last.queryParameters['page'], '1');
    });

    testWidgets('Load more appends the next API page', (tester) async {
      final productRequests = <Uri>[];
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        productRequests.add(request.url);
        final page = request.url.queryParameters['page'];
        return _jsonResponse(
          _page(
            [page == '2' ? _product(id: 42, name: 'Second Bear') : _product()],
            currentPage: page == '2' ? 2 : 1,
            hasMore: page != '2',
          ),
        );
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();
      expect(find.text('Handmade Bear'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('buyer-load-more')));
      await tester.tap(find.byKey(const ValueKey('buyer-load-more')));
      await tester.pumpAndSettle();

      expect(productRequests.last.queryParameters['page'], '2');
      expect(find.text('Handmade Bear'), findsOneWidget);
      expect(find.text('Second Bear'), findsOneWidget);
    });

    testWidgets('product card navigates with its numeric Laravel ID', (
      tester,
    ) async {
      final requestedPaths = <String>[];
      final auth = _authService((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        if (request.url.path.endsWith('/products/41')) {
          return _jsonResponse({'data': _product(id: 41)});
        }
        return _jsonResponse(_page([_product(id: 41)]));
      });
      auth.currentSession = _buyerSession();

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-product-41')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-product-41')));
      await tester.pumpAndSettle();

      expect(requestedPaths, contains('/api/mobile/buyer/products/41'));
      expect(find.text('Full description for Handmade Bear.'), findsOneWidget);
      expect(find.byKey(const ValueKey('buyer-detail-price')), findsOneWidget);
    });

    testWidgets('detail variant selection updates price and availability', (
      tester,
    ) async {
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        if (request.url.path.endsWith('/products/41')) {
          return _jsonResponse({
            'data': _product(
              detail: true,
              variants: [
                _variant(id: 9, price: 12500, inStock: true),
                _variant(
                  id: 10,
                  price: 14000,
                  inStock: false,
                  color: 'Cream',
                  size: 'Small',
                ),
              ],
            ),
          });
        }
        return _jsonResponse(_page([_product()]));
      });
      auth.currentSession = _buyerSession();

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-product-41')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-product-41')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-detail-price')))
            .data,
        '₱125.00',
      );
      expect(find.text('In stock'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('buyer-option-Color-Cream')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('buyer-detail-combination-unavailable')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('buyer-option-Size-Small')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('buyer-detail-price')))
            .data,
        '₱140.00',
      );
      expect(find.text('Out of stock'), findsWidgets);
    });

    testWidgets('missing catalog images render a safe placeholder', (
      tester,
    ) async {
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        return _jsonResponse(_page([_product(imageUrl: null)]));
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('an empty API catalog displays an empty state', (tester) async {
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        return _jsonResponse(_page([]));
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();

      expect(find.text('No products are available right now.'), findsOneWidget);
    });

    testWidgets('network failure offers retry and then shows products', (
      tester,
    ) async {
      var productRequests = 0;
      final auth = _authService((request) async {
        if (request.url.path == '/api/mobile/buyer/wishlist') {
          return _wishlistPage([]);
        }
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        productRequests++;
        if (productRequests == 1) {
          throw http.ClientException('offline');
        }
        return _jsonResponse(_page([_product()]));
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'We could not load products. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry').last);
      await tester.pumpAndSettle();

      expect(find.text('Handmade Bear'), findsOneWidget);
      expect(productRequests, 2);
    });

    testWidgets('revoked session is cleared and prompts sign-in again', (
      tester,
    ) async {
      final store = MemoryTokenStore()..token = 'mock-session-token';
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        return _jsonResponse({'message': 'Unauthenticated.'}, 401);
      }, store: store);

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();

      expect(store.token, isNull);
      expect(
        find.text(
          'Your session needs attention. Sign in again to browse products.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cart quick-add opens detail and save uses Wishlist only', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final auth = _authService((request) async {
        requests.add(request);
        if (request.url.path == '/api/mobile/buyer/wishlist' &&
            request.method == 'GET') {
          return _wishlistPage([]);
        }
        if (request.url.path == '/api/mobile/buyer/wishlist/41' &&
            request.method == 'PUT') {
          return _jsonResponse({
            'data': {'product_id': 41, 'is_saved': true},
          });
        }
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        if (request.url.path.endsWith('/products/41')) {
          return _jsonResponse({
            'data': _product(
              detail: true,
              variants: [_variant(id: 9, price: 12500, inStock: true)],
            ),
          });
        }
        return _jsonResponse(_page([_product()]));
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-add-cart-41')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-add-cart-41')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('buyer-detail-add-to-cart')),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('buyer-save-41')));
      await tester.tap(find.byKey(const ValueKey('buyer-save-41')));
      await tester.pumpAndSettle();

      expect(find.text('Added to saved products.'), findsOneWidget);
      expect(
        requests.any(
          (request) =>
              request.method == 'PUT' &&
              request.url.path == '/api/mobile/buyer/wishlist/41',
        ),
        isTrue,
      );
      expect(requests, isNotEmpty);
      expect(
        requests.map((request) => request.url.path),
        isNot(contains('/cart')),
      );
      expect(find.text('Full description for Handmade Bear.'), findsNothing);
    });

    testWidgets('a stale search result cannot replace the latest response', (
      tester,
    ) async {
      final slowResponse = Completer<http.Response>();
      final productSearches = <String>[];
      final auth = _authService((request) async {
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({'data': []});
        }
        final search = request.url.queryParameters['search'] ?? '';
        productSearches.add(search);
        if (search == 'old search') return slowResponse.future;
        if (search == 'new search') {
          return _jsonResponse(_page([_product(id: 43, name: 'Fresh Result')]));
        }
        return _jsonResponse(_page([]));
      });

      await _pumpApp(tester, auth);
      await tester.pumpAndSettle();
      final searchField = find.byKey(const ValueKey('buyer-catalog-search'));
      await tester.enterText(searchField, 'old search');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(productSearches, contains('old search'));

      await tester.enterText(searchField, 'new search');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Fresh Result'), findsOneWidget);

      slowResponse.complete(
        _jsonResponse(_page([_product(name: 'Stale Result')])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh Result'), findsOneWidget);
      expect(find.text('Stale Result'), findsNothing);
    });
  });
}

Future<void> _pumpApp(WidgetTester tester, AuthService auth) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(auth));
}

Widget _app(AuthService auth) {
  final cartController = BuyerCartController(authService: auth);
  final wishlistController = BuyerWishlistController(authService: auth);
  return MaterialApp(
    home: BuyerHomePage(
      authService: auth,
      cartController: cartController,
      wishlistController: wishlistController,
    ),
    onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
      settings,
      authService: auth,
      cartController: cartController,
      wishlistController: wishlistController,
    ),
  );
}

AuthService _authService(
  Future<http.Response> Function(http.Request) handler, {
  MemoryTokenStore? store,
}) {
  final auth = AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: store ?? (MemoryTokenStore()..token = 'mock-session-token'),
  );
  auth.currentSession = _buyerSession();
  return auth;
}

AuthSession _buyerSession() => const AuthSession(
  id: 8,
  name: 'Buyer Test',
  email: 'buyer@example.test',
  role: AccountRole.buyer,
);

http.Response _jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response(jsonEncode(value), statusCode);

http.Response _wishlistPage(List<Map<String, Object?>> entries) =>
    _jsonResponse({
      'data': entries,
      'meta': {
        'current_page': 1,
        'per_page': 12,
        'total': entries.length,
        'last_page': 1,
        'has_more': false,
      },
    });

Map<String, Object?> _page(
  List<Map<String, Object?>> products, {
  int currentPage = 1,
  bool hasMore = false,
}) => {
  'data': products,
  'meta': {
    'current_page': currentPage,
    'per_page': 12,
    'total': products.length + (hasMore ? 1 : 0),
    'last_page': hasMore ? currentPage + 1 : currentPage,
    'has_more': hasMore,
  },
  'filters': {'search': '', 'category': null, 'sort': 'featured'},
};

Map<String, Object?> _category() => {
  'id': 5,
  'name': 'Home and Furniture',
  'slug': 'home-and-furniture',
  'parent': {'id': 3, 'name': 'Home and Living', 'slug': 'home-and-living'},
};

Map<String, Object?> _product({
  int id = 41,
  String name = 'Handmade Bear',
  String? imageUrl,
  bool detail = false,
  List<Map<String, Object?>> variants = const [],
}) => {
  'id': id,
  'slug': 'handmade-bear-$id',
  'name': name,
  'description': detail ? '<p>Full description for $name.</p>' : 'Soft bear.',
  'description_summary': 'Full description for $name.',
  'store': {'name': 'Bearly Studio', 'slug': 'bearly-studio'},
  'category': _category(),
  'price_minor': 12500,
  'regular_price_minor': 15000,
  'discount_percent': 17,
  'currency': 'PHP',
  'image_url': imageUrl,
  'in_stock': true,
  'variants': variants,
  'rating_summary': {'average': 4.5, 'count': 2},
  if (detail)
    'images': [
      {
        'url': imageUrl,
        'alt_text': 'Bear',
        'variant_id': null,
        'is_primary': true,
      },
    ],
};

Map<String, Object?> _variant({
  required int id,
  required int price,
  required bool inStock,
  String color = 'Honey',
  String size = 'Large',
}) => {
  'id': id,
  'name': '$color / $size',
  'options': {'Color': color, 'Size': size},
  'price_minor': price,
  'regular_price_minor': price + 2500,
  'discount_percent': 17,
  'currency': 'PHP',
  'in_stock': inStock,
};

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
