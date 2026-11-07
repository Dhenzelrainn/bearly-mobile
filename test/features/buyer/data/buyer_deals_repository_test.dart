import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_deals_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_deals_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads current offers with the authenticated Buyer session', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return _jsonResponse(_deals());
    });

    final page = await repository.getDeals();

    expect(request.method, 'GET');
    expect(request.url.path, '/api/mobile/buyer/deals');
    expect(request.headers['authorization'], 'Bearer deals-session-token');
    expect(page.campaigns.single.name, 'Payday Sale');
    expect(page.campaigns.single.products.single.product.priceMinor, 8000);
    expect(
      page.campaigns.single.products.single.product.regularPriceMinor,
      10000,
    );
    expect(
      page.campaigns.single.products.single.promotion?.name,
      'Payday Sale',
    );
    expect(page.storeDeals.single.product.store?.slug, 'bearly-studio');
    expect(page.platformOffers.single.discountLabel, '10% off');
    expect(page.isEmpty, isFalse);
  });

  test('parses empty deals without placeholder records', () async {
    final page = await _repository(
      (_) async => _jsonResponse({
        'data': {'campaigns': [], 'store_deals': [], 'platform_offers': []},
      }),
    ).getDeals();

    expect(page.isEmpty, isTrue);
    expect(page.campaigns, isEmpty);
    expect(page.storeDeals, isEmpty);
    expect(page.platformOffers, isEmpty);
  });

  test('rejects an incomplete API response', () async {
    final repository = _repository(
      (_) async => _jsonResponse({
        'data': {'campaigns': []},
      }),
    );

    await expectLater(
      repository.getDeals(),
      throwsA(isA<BuyerDealsFormatException>()),
    );
  });
}

BuyerDealsRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerDealsRepository(
  authService: AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: _MemoryTokenStore()..token = 'deals-session-token',
  ),
);

http.Response _jsonResponse(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _deals() => {
  'data': {
    'campaigns': [
      {
        'campaign': {
          'id': 7,
          'name': 'Payday Sale',
          'type_label': 'Payday Sale',
          'description': 'Active marketplace campaign.',
          'period': 'Nov 1 – Nov 30',
          'banner_url': null,
          'banner_title': null,
        },
        'products': [_product(41, 'Campaign bear', 8000, 10000, 'campaign')],
      },
    ],
    'store_deals': [
      _product(42, 'Store markdown bear', 9000, 10000, 'product_discount'),
    ],
    'platform_offers': [
      {
        'id': 12,
        'name': 'Bearly 10% offer',
        'kind': 'automatic_discount',
        'discount_label': '10% off',
        'description': 'On eligible products.',
        'terms': null,
        'code': null,
        'minimum_spend_minor': 0,
        'starts_at': '2026-11-01T00:00:00+08:00',
        'ends_at': '2026-11-30T23:59:59+08:00',
      },
    ],
  },
};

Map<String, Object?> _product(
  int id,
  String name,
  int price,
  int regular,
  String source,
) => {
  'id': id,
  'slug': 'deal-product-$id',
  'name': name,
  'description': name,
  'description_summary': name,
  'store': {'name': 'Bearly Studio', 'slug': 'bearly-studio'},
  'category': {
    'id': 5,
    'name': 'Home and Furniture',
    'slug': 'home-and-furniture',
    'parent': null,
  },
  'price_minor': price,
  'regular_price_minor': regular,
  'discount_percent': 100 - ((price * 100) ~/ regular),
  'currency': 'PHP',
  'image_url': null,
  'in_stock': true,
  'variants': [
    {
      'id': id + 100,
      'name': 'Standard',
      'options': <String, Object?>{},
      'price_minor': price,
      'regular_price_minor': regular,
      'discount_percent': 100 - ((price * 100) ~/ regular),
      'currency': 'PHP',
      'in_stock': true,
    },
  ],
  'rating_summary': {'average': 0, 'count': 0},
  'promotion': {
    'source': source,
    'name': source == 'campaign' ? 'Payday Sale' : 'Weekend markdown',
    'starts_at': '2026-11-01T00:00:00+08:00',
    'ends_at': '2026-11-30T23:59:59+08:00',
  },
};

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
