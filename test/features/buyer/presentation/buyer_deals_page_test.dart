import 'dart:async';

import 'package:bearly_mobile/features/buyer/data/buyer_deals_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_deals_models.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_deals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows live campaign data, refreshes, and opens a product', (
    tester,
  ) async {
    final pending = Completer<BuyerDealsPageData>();
    final repository = _FakeDealsDataSource()..responses.add(pending.future);
    var openedProductId = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerDealsPage(
          repository: repository,
          onOpenProduct: (id) => openedProductId = id,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(_data(_activeDeals));
    await tester.pumpAndSettle();
    expect(find.text('Payday Sale').first, findsOneWidget);
    expect(find.text('Campaign bear'), findsOneWidget);
    expect(find.text('Weekend markdown'), findsOneWidget);
    expect(find.text('10% off'), findsOneWidget);
    expect(find.text('Store markdown bear'), findsOneWidget);

    repository.responses.add(Future.value(_data(_activeDeals)));
    await tester.drag(
      find.byKey(const ValueKey('buyer-deals-list')),
      const Offset(0, 450),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 2);

    await tester.ensureVisible(
      find.byKey(const ValueKey('buyer-deal-product-41')),
    );
    await tester.tap(find.byKey(const ValueKey('buyer-deal-product-41')));
    expect(openedProductId, 41);
  });

  testWidgets('shows an empty state when no active deals are returned', (
    tester,
  ) async {
    final repository = _FakeDealsDataSource()
      ..responses.add(Future.value(_data(_emptyDeals)));

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerDealsPage(repository: repository, onOpenProduct: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No live deals right now'), findsOneWidget);
    expect(find.text('Campaign bear'), findsNothing);
  });

  testWidgets('shows an error and retries the deals request', (tester) async {
    final failure = Completer<BuyerDealsPageData>();
    final repository = _FakeDealsDataSource()
      ..responses.add(failure.future)
      ..responses.add(Future.value(_data(_emptyDeals)));

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerDealsPage(repository: repository, onOpenProduct: (_) {}),
      ),
    );
    failure.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deals could not be loaded'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('No live deals right now'), findsOneWidget);
  });
}

class _FakeDealsDataSource implements BuyerDealsDataSource {
  final List<Future<BuyerDealsPageData>> responses = [];
  int calls = 0;

  @override
  Future<BuyerDealsPageData> getDeals() {
    calls++;
    if (responses.isEmpty) return Future.value(_data(_emptyDeals));
    return responses.removeAt(0);
  }
}

BuyerDealsPageData _data(Map<String, Object?> json) =>
    BuyerDealsPageData.fromJson(json);

final Map<String, Object?> _emptyDeals = {
  'data': {'campaigns': [], 'store_deals': [], 'platform_offers': []},
};

final Map<String, Object?> _activeDeals = {
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
        'products': [
          _product(41, 'Campaign bear', 8000, 10000, 'campaign', 'Payday Sale'),
        ],
      },
    ],
    'store_deals': [
      _product(
        42,
        'Store markdown bear',
        9000,
        10000,
        'product_discount',
        'Weekend markdown',
      ),
    ],
    'platform_offers': [
      {
        'id': 12,
        'name': 'Bearly offer',
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
  String promotionName,
) => {
  'id': id,
  'slug': 'deal-$id',
  'name': name,
  'description': name,
  'description_summary': name,
  'store': {'name': 'Bearly Studio', 'slug': 'bearly-studio'},
  'category': null,
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
    'name': promotionName,
    'starts_at': '2026-11-01T00:00:00+08:00',
    'ends_at': '2026-11-30T23:59:59+08:00',
  },
};
