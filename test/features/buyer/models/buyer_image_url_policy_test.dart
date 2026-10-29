import 'package:bearly_mobile/features/buyer/models/buyer_catalog_models.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_image_url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BuyerImageUrlPolicy', () {
    const debugPolicy = BuyerImageUrlPolicy(allowLocalHttp: true);
    const productionPolicy = BuyerImageUrlPolicy(allowLocalHttp: false);

    test('accepts only explicitly approved local HTTP hosts in debug mode', () {
      for (final host in ['127.0.0.1', 'localhost', '10.0.2.2']) {
        final url = 'http://$host:8000/storage/products/bear.jpg';
        expect(debugPolicy.normalize(url), url);
      }
    });

    test('preserves path, query, and port for an approved local URL', () {
      const url =
          'http://127.0.0.1:8011/storage/products/bear.jpg?width=640&fit=cover';

      expect(debugPolicy.normalize(url), url);
    });

    test('rejects unlisted local and external HTTP hosts in debug mode', () {
      expect(
        debugPolicy.normalize('http://192.168.1.44:8000/storage/bear.jpg'),
        isNull,
      );
      expect(
        debugPolicy.normalize('http://api.example.test/storage/bear.jpg'),
        isNull,
      );
      expect(
        debugPolicy.normalize('http://localhost.example.test/storage/bear.jpg'),
        isNull,
      );
    });

    test(
      'rejects all HTTP URLs in production mode but preserves HTTPS URLs',
      () {
        expect(
          productionPolicy.normalize('http://127.0.0.1:8000/storage/bear.jpg'),
          isNull,
        );
        expect(
          productionPolicy.normalize(
            'http://api.example.test/storage/bear.jpg',
          ),
          isNull,
        );

        const secureUrl =
            'https://cdn.example.test:8443/storage/bear.jpg?width=640';
        expect(productionPolicy.normalize(secureUrl), secureUrl);
      },
    );

    test('rejects protocol-relative URLs and embedded credentials', () {
      expect(debugPolicy.normalize('//127.0.0.1/storage/bear.jpg'), isNull);
      expect(
        debugPolicy.normalize('http://user:password@127.0.0.1/bear.jpg'),
        isNull,
      );
    });
  });

  test('catalog and detail image parsing share the debug URL policy', () {
    const url = 'http://127.0.0.1:8000/storage/products/bear.jpg?size=large';
    final product = BuyerCatalogProduct.fromJson({
      'id': 7,
      'slug': 'honey-bear',
      'name': 'Honey Bear',
      'description': 'A bear.',
      'description_summary': 'A bear.',
      'store': null,
      'category': null,
      'price_minor': 10000,
      'regular_price_minor': 10000,
      'discount_percent': 0,
      'currency': 'PHP',
      'image_url': url,
      'in_stock': true,
      'variants': [],
      'rating_summary': {'average': 0, 'count': 0},
      'images': [
        {
          'url': url,
          'alt_text': 'Honey bear',
          'variant_id': null,
          'is_primary': true,
        },
      ],
    });

    expect(product.imageUrl, url);
    expect(product.images.single.url, url);
  });
}
