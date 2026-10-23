import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_catalog_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BuyerCatalogRepository', () {
    test('parses a paginated product listing and integer PHP prices', () async {
      final repository = _repository(
        (_) async => _jsonResponse({
          'data': [_productJson()],
          'meta': {
            'current_page': 2,
            'per_page': 1,
            'total': 3,
            'last_page': 3,
            'has_more': true,
          },
          'filters': {
            'search': 'linen',
            'category': 'fashion',
            'sort': 'price_low',
          },
        }),
      );

      final page = await repository.getProducts();
      final product = page.products.single;

      expect(page.pagination.currentPage, 2);
      expect(page.pagination.perPage, 1);
      expect(page.pagination.total, 3);
      expect(page.pagination.lastPage, 3);
      expect(page.pagination.hasMore, isTrue);
      expect(page.filters.search, 'linen');
      expect(page.filters.category, 'fashion');
      expect(page.filters.sort, BuyerCatalogSort.priceLow);
      expect(product.id, 41);
      expect(product.priceMinor, 12500);
      expect(product.regularPriceMinor, 15000);
      expect(product.discountPercent, 17);
      expect(product.formattedPrice, '₱125.00');
      expect(product.formattedRegularPrice, '₱150.00');
      expect(product.variants.single.priceMinor, 12500);
      expect(product.variants.single.formattedPrice, '₱125.00');
      expect(product.ratingSummary.average, 4.5);
      expect(product.ratingSummary.count, 2);
    });

    test('parses an empty catalog without inventing product data', () async {
      final repository = _repository(
        (_) async => _jsonResponse({
          'data': [],
          'meta': {
            'current_page': 1,
            'per_page': 12,
            'total': 0,
            'last_page': 1,
            'has_more': false,
          },
          'filters': {'search': '', 'category': null, 'sort': 'featured'},
        }),
      );

      final page = await repository.getProducts();

      expect(page.products, isEmpty);
      expect(page.pagination.total, 0);
      expect(page.pagination.hasMore, isFalse);
    });

    test(
      'parses detail gallery, category hierarchy, options, and stock',
      () async {
        final detail = _productJson()
          ..['description'] = '<p>Full product description.</p>'
          ..['image_url'] =
              'https://cdn.example.test/storage/products/bear-front.jpg'
          ..['images'] = [
            {
              'url': 'https://cdn.example.test/storage/products/bear-front.jpg',
              'alt_text': 'Bear front view',
              'variant_id': null,
              'is_primary': true,
            },
            {
              'url': 'https://cdn.example.test/storage/products/bear-side.jpg',
              'alt_text': null,
              'variant_id': 9,
              'is_primary': false,
            },
          ];
        late http.Request request;
        final repository = _repository((incoming) async {
          request = incoming;
          return _jsonResponse({'data': detail});
        });

        final product = await repository.getProduct(41);

        expect(request.url.path, '/api/mobile/buyer/products/41');
        expect(product.description, '<p>Full product description.</p>');
        expect(product.category?.parent?.id, 3);
        expect(product.category?.parent?.name, 'Home and Living');
        expect(product.variants.single.id, 9);
        expect(product.variants.single.options, {
          'Color': 'Honey',
          'Size': 'Large',
        });
        expect(product.inStock, isTrue);
        expect(product.variants.single.inStock, isTrue);
        expect(product.images, hasLength(2));
        expect(product.imageUrl, product.images.first.url);
        expect(product.images.first.isPrimary, isTrue);
        expect(product.images.last.variantId, 9);
      },
    );

    test(
      'handles nullable optional metadata and empty image galleries',
      () async {
        final data = _productJson()
          ..['store'] = null
          ..['category'] = null
          ..['image_url'] = null
          ..['rating_summary'] = {'average': 0, 'count': 0}
          ..remove('images');
        final repository = _repository(
          (_) async => _jsonResponse({'data': data}),
        );

        final product = await repository.getProduct(41);

        expect(product.store, isNull);
        expect(product.category, isNull);
        expect(product.imageUrl, isNull);
        expect(product.images, isEmpty);
        expect(product.ratingSummary.count, 0);
      },
    );

    test('parses category identifiers and parent data', () async {
      final repository = _repository(
        (_) async => _jsonResponse({
          'data': [
            {
              'id': 5,
              'name': 'Home and Furniture',
              'slug': 'home-and-furniture',
              'parent': {
                'id': 3,
                'name': 'Home and Living',
                'slug': 'home-and-living',
              },
            },
          ],
        }),
      );

      final categories = await repository.getCategories();

      expect(categories.single.id, 5);
      expect(categories.single.slug, 'home-and-furniture');
      expect(categories.single.parent?.id, 3);
    });

    test(
      'constructs Laravel query parameters and sends the session header',
      () async {
        late http.Request request;
        final repository = _repository((incoming) async {
          request = incoming;
          return _jsonResponse({
            'data': [],
            'meta': {
              'current_page': 2,
              'per_page': 7,
              'total': 0,
              'last_page': 1,
              'has_more': false,
            },
            'filters': {
              'search': 'linen & cotton',
              'category': 'fashion-and-apparel',
              'sort': 'price_high',
            },
          });
        });

        await repository.getProducts(
          search: ' linen & cotton ',
          category: ' fashion-and-apparel ',
          sort: BuyerCatalogSort.priceHigh,
          page: 2,
          perPage: 7,
        );

        expect(request.method, 'GET');
        expect(request.url.path, '/api/mobile/buyer/products');
        expect(request.url.queryParameters, {
          'search': 'linen & cotton',
          'category': 'fashion-and-apparel',
          'sort': 'price_high',
          'page': '2',
          'per_page': '7',
        });
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['authorization'], 'Bearer test-session-token');
      },
    );

    test('uses a non-persistent session through AuthService', () async {
      String? authorization;
      final store = MemoryTokenStore();
      final auth = AuthService(
        apiClient: ApiClient(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/mobile/login')) {
              return _jsonResponse({
                'token': 'ephemeral-test-token',
                'user': {
                  'id': 1,
                  'name': 'Buyer Test',
                  'email': 'buyer@example.test',
                  'role': 'buyer',
                  'status': 'active',
                },
              });
            }
            authorization = request.headers['authorization'];
            return _jsonResponse({
              'data': [],
              'meta': {
                'current_page': 1,
                'per_page': 12,
                'total': 0,
                'last_page': 1,
                'has_more': false,
              },
              'filters': {'search': '', 'category': null, 'sort': 'featured'},
            });
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
        tokenStore: store,
      );
      await auth.login(
        email: 'buyer@example.test',
        password: 'test-password',
        rememberMe: false,
      );

      await BuyerCatalogRepository(authService: auth).getProducts();

      expect(store.token, isNull);
      expect(authorization, 'Bearer ephemeral-test-token');
    });

    test('rejects requests without a saved or in-memory session', () async {
      var requestWasSent = false;
      final repository = BuyerCatalogRepository(
        authService: _authService(
          MockClient((_) async {
            requestWasSent = true;
            return _jsonResponse({});
          }),
          store: MemoryTokenStore(),
        ),
      );

      await expectLater(
        repository.getCategories(),
        throwsA(isA<AuthException>()),
      );
      expect(requestWasSent, isFalse);
    });

    for (final statusCode in [401, 403, 404, 422, 429, 500]) {
      test(
        'propagates HTTP $statusCode and preserves session policy',
        () async {
          final store = MemoryTokenStore()..token = 'test-session-token';
          final auth = _authService(
            MockClient(
              (_) async => _jsonResponse({
                'message': 'Request rejected.',
                if (statusCode == 422)
                  'errors': {
                    'page': ['The page field is invalid.'],
                  },
              }, statusCode),
            ),
            store: store,
          );
          final repository = BuyerCatalogRepository(authService: auth);

          await expectLater(
            repository.getProduct(41),
            throwsA(
              isA<ApiHttpException>().having(
                (error) => error.statusCode,
                'statusCode',
                statusCode,
              ),
            ),
          );

          if (statusCode == 401 || statusCode == 403) {
            expect(store.token, isNull);
          } else {
            expect(store.token, 'test-session-token');
          }
        },
      );
    }

    test(
      'keeps the session on connectivity, timeout, and server JSON errors',
      () async {
        final store = MemoryTokenStore()..token = 'test-session-token';
        final transportRepository = BuyerCatalogRepository(
          authService: _authService(
            MockClient((_) async => throw http.ClientException('offline')),
            store: store,
          ),
        );
        await expectLater(
          transportRepository.getProducts(),
          throwsA(isA<ApiTransportException>()),
        );
        expect(store.token, 'test-session-token');

        final timeoutRepository = BuyerCatalogRepository(
          authService: _authService(
            MockClient((_) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return _jsonResponse({});
            }),
            store: store,
            timeout: const Duration(milliseconds: 1),
          ),
        );
        await expectLater(
          timeoutRepository.getProducts(),
          throwsA(isA<ApiTimeoutException>()),
        );
        expect(store.token, 'test-session-token');

        final malformedJsonRepository = BuyerCatalogRepository(
          authService: _authService(
            MockClient((_) async => http.Response('{bad-json', 200)),
            store: store,
          ),
        );
        await expectLater(
          malformedJsonRepository.getProducts(),
          throwsA(isA<ApiFormatException>()),
        );
        expect(store.token, 'test-session-token');
      },
    );

    test(
      'rejects malformed required product fields instead of defaulting them',
      () {
        final malformed = _productJson()..remove('id');

        expect(
          () => BuyerCatalogProduct.fromJson(malformed),
          throwsA(isA<BuyerCatalogFormatException>()),
        );
      },
    );

    test('preserves HTTPS gallery URLs and omits unsafe image paths', () {
      final data = _productJson()
        ..['images'] = [
          {
            'url': 'https://cdn.example.test/storage/products/public.jpg',
            'alt_text': null,
            'variant_id': null,
            'is_primary': true,
          },
          {
            'url': '/storage/private/seller-document.jpg',
            'alt_text': 'private',
            'variant_id': null,
            'is_primary': false,
          },
        ];

      final product = BuyerCatalogProduct.fromJson(data);

      expect(
        product.imageUrl,
        'https://cdn.example.test/storage/products/bear.jpg',
      );
      expect(product.images, hasLength(1));
      expect(
        product.images.single.url,
        'https://cdn.example.test/storage/products/public.jpg',
      );
    });
  });
}

BuyerCatalogRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerCatalogRepository(
  authService: _authService(
    MockClient(handler),
    store: MemoryTokenStore()..token = 'test-session-token',
  ),
);

AuthService _authService(
  http.Client client, {
  required MemoryTokenStore store,
  Duration timeout = const Duration(seconds: 30),
}) => AuthService(
  apiClient: ApiClient(
    httpClient: client,
    timeout: timeout,
    baseUri: Uri.parse('https://api.example.test'),
  ),
  tokenStore: store,
);

http.Response _jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response(jsonEncode(value), statusCode);

Map<String, Object?> _productJson() => {
  'id': 41,
  'slug': 'handmade-bear',
  'name': 'Handmade Bear',
  'description': 'A soft handmade bear.',
  'description_summary': 'A soft handmade bear.',
  'store': {'name': 'Bearly Studio', 'slug': 'bearly-studio'},
  'category': {
    'id': 5,
    'name': 'Home and Furniture',
    'slug': 'home-and-furniture',
    'parent': {'id': 3, 'name': 'Home and Living', 'slug': 'home-and-living'},
  },
  'price_minor': 12500,
  'regular_price_minor': 15000,
  'discount_percent': 17,
  'currency': 'PHP',
  'image_url': 'https://cdn.example.test/storage/products/bear.jpg',
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
