import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../data/buyer_deals_repository.dart';
import '../models/buyer_catalog_models.dart';
import '../models/buyer_deals_models.dart';

class BuyerDealsPage extends StatefulWidget {
  const BuyerDealsPage({
    super.key,
    required this.repository,
    required this.onOpenProduct,
  });

  final BuyerDealsDataSource repository;
  final ValueChanged<int> onOpenProduct;

  @override
  State<BuyerDealsPage> createState() => _BuyerDealsPageState();
}

class _BuyerDealsPageState extends State<BuyerDealsPage> {
  BuyerDealsPageData? _deals;
  Object? _error;
  bool _loading = true;
  Future<void>? _pending;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDeals());
  }

  Future<void> _loadDeals() {
    final pending = _pending;
    if (pending != null) return pending;

    final request = _fetchDeals();
    _pending = request.whenComplete(() => _pending = null);
    return _pending!;
  }

  Future<void> _fetchDeals() async {
    setState(() {
      if (_deals == null) _loading = true;
      _error = null;
    });
    try {
      final deals = await widget.repository.getDeals();
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Deals & Perks')),
    body: _loading && _deals == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDeals,
            child: ListView(
              key: const ValueKey('buyer-deals-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Deals & Perks',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Current Bearly campaigns, store markdowns, and platform offers.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
                ),
                const SizedBox(height: 18),
                if (_error != null && _deals == null)
                  _errorCard()
                else if (_deals?.isEmpty ?? true)
                  _emptyState(context)
                else ...[
                  if (_deals!.campaigns.isNotEmpty) ...[
                    _sectionTitle(context, 'Marketplace campaigns'),
                    const SizedBox(height: 8),
                    for (final campaign in _deals!.campaigns)
                      _campaignCard(context, campaign),
                  ],
                  if (_deals!.storeDeals.isNotEmpty) ...[
                    _sectionTitle(context, 'Store markdowns'),
                    const SizedBox(height: 8),
                    for (final deal in _deals!.storeDeals)
                      _productCard(context, deal),
                  ],
                  if (_deals!.platformOffers.isNotEmpty) ...[
                    _sectionTitle(context, 'Bearly platform offers'),
                    const SizedBox(height: 8),
                    for (final offer in _deals!.platformOffers)
                      _offerCard(context, offer),
                    const SizedBox(height: 8),
                    Text(
                      'Offer terms and checkout eligibility are confirmed by Bearly when an order is placed.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    _inlineError(),
                  ],
                ],
              ],
            ),
          ),
  );

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 2),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _campaignCard(BuildContext context, BuyerDealCampaign campaign) =>
      Card(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (campaign.bannerUrl != null)
              Image.network(
                campaign.bannerUrl!,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.typeLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: BearlyColors.gold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    campaign.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (campaign.period != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      campaign.period!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (campaign.description != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      campaign.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            for (final product in campaign.products)
              _productCard(context, product, compact: true),
          ],
        ),
      );

  Widget _productCard(
    BuildContext context,
    BuyerDealProduct deal, {
    bool compact = false,
  }) {
    final product = deal.product;
    return Card(
      margin: EdgeInsets.fromLTRB(compact ? 10 : 0, 4, compact ? 10 : 0, 8),
      child: InkWell(
        key: ValueKey('buyer-deal-product-${product.id}'),
        onTap: () => widget.onOpenProduct(product.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ProductThumbnail(
                imageUrl: product.imageUrl,
                size: 68,
                semanticLabel: product.name,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (product.store != null)
                      Text(
                        product.store!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: BearlyColors.brown800),
                        ),
                        if (product.regularPriceMinor > product.priceMinor)
                          Text(
                            product.formattedRegularPrice,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        if (product.discountPercent > 0)
                          Text(
                            '${product.discountPercent}% off',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: BearlyColors.success),
                          ),
                      ],
                    ),
                    if (deal.promotion?.name != null)
                      Text(
                        deal.promotion!.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offerCard(BuildContext context, BuyerPlatformOffer offer) {
    final dates = _dateRange(context, offer.startsAt, offer.endsAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _offerKind(offer.kind),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: BearlyColors.gold),
            ),
            const SizedBox(height: 3),
            Text(offer.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(
              offer.discountLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (offer.description != null) ...[
              const SizedBox(height: 4),
              Text(offer.description!),
            ],
            if (offer.minimumSpendMinor > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Minimum spend ${formatPriceMinorUnits(offer.minimumSpendMinor, currency: 'PHP')}',
              ),
            ],
            if (dates != null) ...[
              const SizedBox(height: 4),
              Text(
                'Available $dates',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (offer.code != null) ...[
              const SizedBox(height: 5),
              SelectableText('Code: ${offer.code}'),
            ],
            if (offer.terms != null) ...[
              const SizedBox(height: 5),
              Text(offer.terms!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  String? _dateRange(BuildContext context, DateTime? start, DateTime? end) {
    final localizations = MaterialLocalizations.of(context);
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      return '${localizations.formatMediumDate(start.toLocal())} – ${localizations.formatMediumDate(end.toLocal())}';
    }
    return start != null
        ? 'from ${localizations.formatMediumDate(start.toLocal())}'
        : 'until ${localizations.formatMediumDate(end!.toLocal())}';
  }

  String _offerKind(String kind) => switch (kind) {
    'voucher' => 'Platform voucher',
    'automatic_discount' => 'Automatic discount',
    'free_shipping' => 'Shipping offer',
    _ => 'Bearly offer',
  };

  Widget _emptyState(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 54),
    child: Column(
      children: [
        const Icon(
          Icons.local_offer_outlined,
          size: 42,
          color: BearlyColors.brown500,
        ),
        const SizedBox(height: 10),
        Text(
          'No live deals right now',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text('Check back later for current Bearly campaigns and offers.'),
      ],
    ),
  );

  Widget _errorCard() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 40,
          color: BearlyColors.brown500,
        ),
        const SizedBox(height: 10),
        const Text(
          'Deals could not be loaded. Check your connection and try again.',
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _loadDeals, child: const Text('Retry')),
      ],
    ),
  );

  Widget _inlineError() => Row(
    children: [
      const Expanded(child: Text('Deals could not be refreshed.')),
      TextButton(onPressed: _loadDeals, child: const Text('Retry')),
    ],
  );
}
