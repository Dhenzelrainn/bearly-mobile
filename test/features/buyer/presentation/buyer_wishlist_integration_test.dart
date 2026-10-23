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
  group('Buyer Wishlist UI integration', () {
    testWidgets('Home heart saves the numeric product ID without navigation', (
      tester,
    ) async {
      final harness = _WishlistHarness();
      await _pumpHome(tester, harness);
      await tester.ensureVisible(find.byKey(const ValueKey('buyer-save-41')));
      await tester.tap(find.byKey(const ValueKey('buyer-save-41')));
      await tester.pumpAndSettle();

      expect(
        harness.requests,
        contains(
          predicate<http.Request>(
            (request) =>
                request.method == 'PUT' &&
                request.url.path == '/api/mobile/buyer/wishlist/41',
          ),
        ),
      );
      expect(
        harness.requests.any(
          (request) => request.url.path == '/api/mobile/buyer/products/41',
        ),
        isFalse,
      );
      expect(harness.controller.isSaved(41), isTrue);
      expect(
        harness.requests.any(
          (request) =>
              request.url.path.contains('/cart') ||
              request.url.path.contains('/checkout'),
        ),
        isFalse,
      );
    });

    testWidgets('Shop heart removes an already saved product', (tester) async {
      final harness = _WishlistHarness(savedIds: {41});
      await _pumpHome(tester, harness);
      await tester.ensureVisible(find.byKey(const ValueKey('buyer-save-41')));
      await tester.tap(find.byKey(const ValueKey('buyer-save-41')));
      await tester.pumpAndSettle();

      expect(
        harness.requests.any(
          (request) =>
              request.method == 'DELETE' &&
              request.url.path == '/api/mobile/buyer/wishlist/41',
        ),
        isTrue,
      );
      expect(harness.controller.isSaved(41), isFalse);
    });

    testWidgets(
      'Product Details shares saved state and preserves variant and quantity',
      (tester) async {
        final harness = _WishlistHarness();
        await _pumpHome(tester, harness);
        await tester.tap(find.byKey(const ValueKey('buyer-product-41')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('buyer-option-Color-Cream')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('buyer-option-Size-Small')));
        await tester.pumpAndSettle();
        final quantityPlus = find.byKey(
          const ValueKey('buyer-detail-quantity-plus'),
        );
        await tester.ensureVisible(quantityPlus);
        await tester.tap(quantityPlus);
        await tester.pumpAndSettle();
        final selectedPrice = tester
            .widget<Text>(find.byKey(const ValueKey('buyer-detail-price')))
            .data;
        expect(selectedPrice, isNotNull);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('buyer-detail-quantity')))
              .data,
          '2',
        );

        final heart = find.byKey(const ValueKey('buyer-detail-save-41'));
        await tester.ensureVisible(heart);
        await tester.tap(heart);
        await tester.pumpAndSettle();

        expect(harness.controller.isSaved(41), isTrue);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('buyer-detail-price')))
              .data,
          selectedPrice,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('buyer-detail-quantity')))
              .data,
          '2',
        );
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await tester.pumpAndSettle();
        expect(harness.controller.isSaved(41), isTrue);
        expect(
          find.byIcon(Icons.favorite_rounded, skipOffstage: false),
          findsWidgets,
        );
      },
    );

    testWidgets('Saved page renders Laravel data and supports remove/open', (
      tester,
    ) async {
      final harness = _WishlistHarness(savedIds: {41});
      await _pumpHome(tester, harness);
      await tester.tap(find.text('Saved').last);
      await tester.pumpAndSettle();

      expect(find.text('Handmade Bear'), findsOneWidget);
      expect(find.text('Bearly Studio'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-saved-price-41')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('buyer-saved-availability-41')),
        findsOneWidget,
      );
      expect(
        harness.requests.where(
          (request) =>
              request.method == 'GET' &&
              request.url.path == '/api/mobile/buyer/wishlist',
        ),
        isNotEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('buyer-saved-open-41')));
      await tester.pumpAndSettle();
      expect(
        harness.requests.any(
          (request) => request.url.path == '/api/mobile/buyer/products/41',
        ),
        isTrue,
      );
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('buyer-saved-remove-41'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(harness.controller.isSaved(41), isFalse);
    });

    testWidgets('an empty Laravel wishlist has a distinct empty state', (
      tester,
    ) async {
      final harness = _WishlistHarness();
      await _pumpHome(tester, harness);
      await tester.tap(find.text('Saved').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('buyer-wishlist-empty')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('buyer-wishlist-error')), findsNothing);
    });

    testWidgets('Load More reveals paginated products once each', (
      tester,
    ) async {
      final harness = _WishlistHarness(
        savedIds: {for (var id = 41; id <= 53; id++) id},
        duplicateFirstOnSecondPage: true,
      );
      await _pumpHome(tester, harness);
      await tester.tap(find.text('Saved').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('buyer-saved-open-41')), findsOneWidget);
      expect(find.byKey(const ValueKey('buyer-saved-open-53')), findsNothing);
      expect(
        harness.requests.where(
          (request) =>
              request.url.path == '/api/mobile/buyer/wishlist' &&
              request.url.queryParameters['page'] == '2',
        ),
        isNotEmpty,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-wishlist-load-more')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-wishlist-load-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('buyer-saved-open-53')), findsOneWidget);
      expect(find.byKey(const ValueKey('buyer-saved-open-41')), findsOneWidget);
    });

    testWidgets('failed save does not report success or change saved status', (
      tester,
    ) async {
      final harness = _WishlistHarness()..putStatusCode = 500;
      await _pumpHome(tester, harness);
      await tester.ensureVisible(find.byKey(const ValueKey('buyer-save-41')));
      await tester.tap(find.byKey(const ValueKey('buyer-save-41')));
      await tester.pumpAndSettle();

      expect(harness.controller.isSaved(41), isFalse);
      expect(find.text('Added to saved products.'), findsNothing);
      expect(
        find.text('Bearly could not update saved products. Try again shortly.'),
        findsOneWidget,
      );
    });

    testWidgets('unavailable product save returns a safe error', (
      tester,
    ) async {
      final harness = _WishlistHarness()..putStatusCode = 404;
      await _pumpHome(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-save-41')));
      await tester.pumpAndSettle();

      expect(harness.controller.isSaved(41), isFalse);
      expect(
        find.text('This product is no longer available to save or view.'),
        findsOneWidget,
      );
      expect(find.text('Added to saved products.'), findsNothing);
    });

    testWidgets(
      'rapid taps issue only one mutation while a request is pending',
      (tester) async {
        final harness = _WishlistHarness()..holdPut = Completer<void>();
        await _pumpHome(tester, harness);
        final heart = find.byKey(const ValueKey('buyer-save-41'));
        await tester.ensureVisible(heart);
        await tester.tap(heart);
        await tester.pump();
        await tester.tap(heart);
        await tester.pump();

        expect(harness.putCount, 1);
        expect(harness.controller.isPending(41), isTrue);
        harness.holdPut!.complete();
        await tester.pumpAndSettle();
        expect(harness.controller.isSaved(41), isTrue);
        expect(harness.putCount, 1);
      },
    );

    test(
      'account changes clear the previous Buyer wishlist immediately',
      () async {
        final harness = _WishlistHarness(savedIds: {41});
        await harness.controller.refresh();
        expect(harness.controller.isSaved(41), isTrue);
        expect(harness.controller.products, hasLength(1));

        harness.auth.currentSession = _buyerSession(9);
        expect(harness.controller.synchronizeSession(), isTrue);
        expect(harness.controller.isSaved(41), isNull);
        expect(harness.controller.products, isEmpty);
      },
    );

    test(
      '401 invalidates the session and never shows stale saved products',
      () async {
        final harness = _WishlistHarness()..wishlistStatusCode = 401;
        await harness.controller.refresh();
        expect(harness.store.token, isNull);
        expect(harness.auth.currentSession, isNull);
        expect(harness.controller.products, isEmpty);
        expect(harness.controller.membershipLoaded, isFalse);
        expect(harness.controller.loadError, isA<ApiException>());
      },
    );

    testWidgets('Wishlist GET failure offers retry and recovers', (
      tester,
    ) async {
      final harness = _WishlistHarness(savedIds: {41})
        ..wishlistFailuresRemaining = 2;
      await _pumpHome(tester, harness);
      await tester.tap(find.text('Saved').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('buyer-wishlist-error')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('buyer-wishlist-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Handmade Bear'), findsOneWidget);
    });
  });
}

Future<void> _pumpHome(WidgetTester tester, _WishlistHarness harness) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: BuyerHomePage(
        authService: harness.auth,
        cartController: harness.cartController,
        wishlistController: harness.controller,
      ),
      onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
        settings,
        authService: harness.auth,
        cartController: harness.cartController,
        wishlistController: harness.controller,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _WishlistHarness {
  _WishlistHarness({
    Set<int> savedIds = const {},
    this.duplicateFirstOnSecondPage = false,
  }) : savedIds = {...savedIds} {
    auth = AuthService(
      apiClient: ApiClient(
        httpClient: MockClient(_handle),
        baseUri: Uri.parse('https://api.example.test'),
      ),
      tokenStore: store,
    );
    auth.currentSession = _buyerSession(8);
    cartController = BuyerCartController(authService: auth);
    controller = BuyerWishlistController(authService: auth);
  }

  final Set<int> savedIds;
  final bool duplicateFirstOnSecondPage;
  final requests = <http.Request>[];
  final store = _MemoryTokenStore()..token = 'mock-session-token';
  late final AuthService auth;
  late final BuyerCartController cartController;
  late final BuyerWishlistController controller;
  int wishlistStatusCode = 200;
  int putStatusCode = 200;
  int wishlistFailuresRemaining = 0;
  int putCount = 0;
  Completer<void>? holdPut;

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (request.url.path == '/api/mobile/buyer/categories') {
      return _json({'data': []});
    }
    if (request.url.path == '/api/mobile/buyer/products') {
      return _json(_catalog([_productJson(41)]));
    }
    if (request.url.path.startsWith('/api/mobile/buyer/products/')) {
      final id = int.parse(request.url.path.split('/').last);
      return _json({'data': _productJson(id, detail: true)});
    }
    if (request.url.path == '/api/mobile/buyer/wishlist') {
      if (wishlistFailuresRemaining > 0) {
        wishlistFailuresRemaining--;
        return _json({'message': 'Server error.'}, 500);
      }
      if (wishlistStatusCode != 200) {
        return _json({'message': 'Unauthenticated.'}, wishlistStatusCode);
      }
      final page =
          int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
      final allIds = savedIds.toList()..sort();
      final start = (page - 1) * 12;
      final safeStart = start < allIds.length ? start : allIds.length;
      final candidateEnd = start + 12;
      final end = candidateEnd < allIds.length ? candidateEnd : allIds.length;
      var entries = allIds.sublist(safeStart, end);
      if (duplicateFirstOnSecondPage && page == 2 && allIds.isNotEmpty) {
        entries = [allIds.first, ...entries];
      }
      final lastPage = allIds.isEmpty ? 1 : ((allIds.length - 1) ~/ 12) + 1;
      return _json({
        'data': entries.map(_wishlistEntry).toList(),
        'meta': {
          'current_page': page,
          'per_page': 12,
          'total': allIds.length,
          'last_page': lastPage,
          'has_more': page < lastPage,
        },
      });
    }
    if (request.url.path.startsWith('/api/mobile/buyer/wishlist/')) {
      final id = int.parse(request.url.path.split('/').last);
      if (request.method == 'PUT') {
        putCount++;
        if (holdPut != null) await holdPut!.future;
        if (putStatusCode != 200) {
          return _json({'message': 'Server error.'}, putStatusCode);
        }
        savedIds.add(id);
        return _json({
          'data': {'product_id': id, 'is_saved': true},
        });
      }
      if (request.method == 'DELETE') {
        savedIds.remove(id);
        return _json({
          'data': {'product_id': id, 'is_saved': false},
        });
      }
    }
    return _json({'message': 'Not found.'}, 404);
  }
}

class _MemoryTokenStore implements SessionTokenStore {
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

AuthSession _buyerSession(int id) => AuthSession(
  id: id,
  name: 'Buyer $id',
  email: 'buyer$id@example.test',
  role: AccountRole.buyer,
);

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

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

Map<String, Object?> _wishlistEntry(int id) => {
  'wishlist_id': 1000 + id,
  'saved_at': '2026-10-20T08:15:30.000000Z',
  'product': _productJson(id),
};

Map<String, Object?> _productJson(int id, {bool detail = false}) => {
  'id': id,
  'slug': 'handmade-bear-$id',
  'name': id == 41 ? 'Handmade Bear' : 'Handmade Bear $id',
  'description': detail ? 'Full Bearly product description.' : 'Soft bear.',
  'description_summary': 'Soft handmade product $id.',
  'store': {'name': 'Bearly Studio', 'slug': 'bearly-studio'},
  'category': {'id': 5, 'name': 'Toys', 'slug': 'toys', 'parent': null},
  'price_minor': 12500,
  'regular_price_minor': 15000,
  'discount_percent': 17,
  'currency': 'PHP',
  'image_url': null,
  'in_stock': true,
  'variants': detail
      ? [
          _variant(id: 9, color: 'Honey', size: 'Large', price: 12500),
          _variant(id: 10, color: 'Cream', size: 'Small', price: 14000),
        ]
      : [],
  'rating_summary': {'average': 4.5, 'count': 2},
  if (detail) 'images': [],
};

Map<String, Object?> _variant({
  required int id,
  required String color,
  required String size,
  required int price,
}) => {
  'id': id,
  'name': '$color / $size',
  'options': {'Color': color, 'Size': size},
  'price_minor': price,
  'regular_price_minor': price + 2500,
  'discount_percent': 17,
  'currency': 'PHP',
  'in_stock': true,
};
