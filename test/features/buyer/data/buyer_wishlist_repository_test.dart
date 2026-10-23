import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BuyerWishlistRepository', () {
    test('parses an empty wishlist and preserves Laravel pagination', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _jsonResponse(_wishlistResponse());
      });

      final page = await repository.fetchSavedProducts(page: 2, perPage: 7);

      expect(request.method, 'GET');
      expect(request.url.path, '/api/mobile/buyer/wishlist');
      expect(request.url.queryParameters, {'page': '2', 'per_page': '7'});
      expect(request.headers['authorization'], 'Bearer test-session-token');
      expect(page.entries, isEmpty);
      expect(page.pagination.currentPage, 2);
      expect(page.pagination.perPage, 7);
      expect(page.pagination.total, 0);
      expect(page.pagination.lastPage, 1);
      expect(page.pagination.hasMore, isFalse);
    });

    test(
      'parses saved product through the existing M2B catalog model',
      () async {
        final repository = _repository(
          (_) async => _jsonResponse(
            _wishlistResponse(
              entries: [_entry()],
              total: 20,
              lastPage: 3,
              hasMore: true,
            ),
          ),
        );

        final page = await repository.fetchSavedProducts();
        final saved = page.entries.single;

        expect(saved.wishlistId, 88);
        expect(saved.savedAt, DateTime.parse('2026-10-20T08:15:30.000000Z'));
        expect(saved.product.id, 41); // product ID; variant ID is separate.
        expect(saved.product.name, 'Handmade Bear');
        expect(saved.product.priceMinor, 12500);
        expect(saved.product.currency, 'PHP');
        expect(saved.product.variants.single.id, 9);
        expect(saved.product.store?.name, 'Bearly Studio');
        expect(page.pagination.total, 20);
        expect(page.pagination.hasMore, isTrue);
      },
    );

    test(
      'saves by product ID and returns repeated authoritative saved state',
      () async {
        final requests = <http.Request>[];
        final repository = _repository((request) async {
          requests.add(request);
          return _jsonResponse({
            'data': {'product_id': 41, 'is_saved': true},
            'message': 'Product saved to wishlist.',
          });
        });

        final first = await repository.saveProduct(41);
        final repeated = await repository.saveProduct(41);

        expect(requests.map((request) => request.method), ['PUT', 'PUT']);
        expect(requests.map((request) => request.url.path), [
          '/api/mobile/buyer/wishlist/41',
          '/api/mobile/buyer/wishlist/41',
        ]);
        expect(requests.every((request) => request.body.isEmpty), isTrue);
        expect(first.productId, 41);
        expect(first.isSaved, isTrue);
        expect(repeated.isSaved, isTrue);
      },
    );

    test('removes by product ID and parses the server unsaved state', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _jsonResponse({
          'data': {'product_id': 41, 'is_saved': false},
          'message': 'Product removed from wishlist.',
        });
      });

      final result = await repository.removeProduct(41);

      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/mobile/buyer/wishlist/41');
      expect(result.productId, 41);
      expect(result.isSaved, isFalse);
    });

    test(
      'preserves unavailable-product errors instead of returning an empty list',
      () async {
        final repository = _repository(
          (_) async => _jsonResponse({'message': 'Not found.'}, 404),
        );

        await expectLater(
          repository.saveProduct(999),
          throwsA(
            isA<ApiHttpException>().having(
              (error) => error.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      },
    );

    test('rejects malformed saved entries and invalid product IDs', () async {
      final repository = _repository(
        (_) async => _jsonResponse(_wishlistResponse(entries: [{}])),
      );

      await expectLater(
        repository.fetchSavedProducts(),
        throwsA(isA<BuyerShoppingFormatException>()),
      );
      expect(() => repository.saveProduct(0), throwsA(isA<RangeError>()));
    });
  });
}

BuyerWishlistRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerWishlistRepository(
  authService: AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: MemoryTokenStore()..token = 'test-session-token',
  ),
);

Map<String, Object?> _wishlistResponse({
  List<Map<String, Object?>> entries = const [],
  int currentPage = 2,
  int perPage = 7,
  int total = 0,
  int lastPage = 1,
  bool hasMore = false,
}) => {
  'data': entries,
  'meta': {
    'current_page': currentPage,
    'per_page': perPage,
    'total': total,
    'last_page': lastPage,
    'has_more': hasMore,
  },
};

Map<String, Object?> _entry() => {
  'wishlist_id': 88,
  'saved_at': '2026-10-20T08:15:30.000000Z',
  'product': _product(),
};

Map<String, Object?> _product() => {
  'id': 41,
  'slug': 'handmade-bear',
  'name': 'Handmade Bear',
  'description': 'A soft handmade bear.',
  'description_summary': 'A soft handmade bear.',
  'store': {'name': 'Bearly Studio', 'slug': 'bearly-studio'},
  'category': {'id': 5, 'name': 'Toys', 'slug': 'toys', 'parent': null},
  'price_minor': 12500,
  'regular_price_minor': 15000,
  'discount_percent': 17,
  'currency': 'PHP',
  'image_url': 'https://cdn.example.test/products/bear.jpg',
  'in_stock': true,
  'variants': [
    {
      'id': 9,
      'name': 'Honey / Large',
      'options': {'Color': 'Honey', 'Size': 'Large'},
      'price_minor': 12500,
      'regular_price_minor': 15000,
      'discount_percent': 17,
      'currency': 'PHP',
      'in_stock': true,
    },
  ],
  'rating_summary': {'average': 4.5, 'count': 2},
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
