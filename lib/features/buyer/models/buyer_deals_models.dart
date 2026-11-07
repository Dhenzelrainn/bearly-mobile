import 'package:flutter/foundation.dart';

import 'buyer_catalog_models.dart';
import 'buyer_image_url_policy.dart';

const _dealImagePolicy = BuyerImageUrlPolicy(allowLocalHttp: kDebugMode);

class BuyerDealsFormatException implements Exception {
  const BuyerDealsFormatException(this.field);

  final String field;

  @override
  String toString() => 'Invalid Buyer deals response field: $field.';
}

class BuyerDealsPageData {
  BuyerDealsPageData({
    required List<BuyerDealCampaign> campaigns,
    required List<BuyerDealProduct> storeDeals,
    required List<BuyerPlatformOffer> platformOffers,
  }) : campaigns = List.unmodifiable(campaigns),
       storeDeals = List.unmodifiable(storeDeals),
       platformOffers = List.unmodifiable(platformOffers);

  final List<BuyerDealCampaign> campaigns;
  final List<BuyerDealProduct> storeDeals;
  final List<BuyerPlatformOffer> platformOffers;

  bool get isEmpty =>
      campaigns.isEmpty && storeDeals.isEmpty && platformOffers.isEmpty;

  factory BuyerDealsPageData.fromJson(Object? value) {
    final root = _dealsMap(value, 'root');
    final data = _dealsMap(root['data'], 'data');
    return BuyerDealsPageData(
      campaigns: _dealsList(
        data['campaigns'],
        'campaigns',
      ).map(BuyerDealCampaign.fromJson).toList(growable: false),
      storeDeals: _dealsList(
        data['store_deals'],
        'store_deals',
      ).map(BuyerDealProduct.fromJson).toList(growable: false),
      platformOffers: _dealsList(
        data['platform_offers'],
        'platform_offers',
      ).map(BuyerPlatformOffer.fromJson).toList(growable: false),
    );
  }
}

class BuyerDealCampaign {
  BuyerDealCampaign({
    required this.id,
    required this.name,
    required this.typeLabel,
    required this.description,
    required this.period,
    required this.bannerUrl,
    required this.bannerTitle,
    required List<BuyerDealProduct> products,
  }) : products = List.unmodifiable(products);

  final int id;
  final String name;
  final String typeLabel;
  final String? description;
  final String? period;
  final String? bannerUrl;
  final String? bannerTitle;
  final List<BuyerDealProduct> products;

  factory BuyerDealCampaign.fromJson(Object? value) {
    final json = _dealsMap(value, 'campaign_group');
    final campaign = _dealsMap(json['campaign'], 'campaign_group.campaign');
    return BuyerDealCampaign(
      id: _dealsInt(campaign['id'], 'campaign.id', positive: true),
      name: _dealsString(campaign['name'], 'campaign.name'),
      typeLabel: _dealsString(campaign['type_label'], 'campaign.type_label'),
      description: _dealsOptionalString(campaign['description']),
      period: _dealsOptionalString(campaign['period']),
      bannerUrl: _dealImagePolicy.normalize(campaign['banner_url']),
      bannerTitle: _dealsOptionalString(campaign['banner_title']),
      products: _dealsList(
        json['products'],
        'campaign_group.products',
      ).map(BuyerDealProduct.fromJson).toList(growable: false),
    );
  }
}

class BuyerDealProduct {
  const BuyerDealProduct({required this.product, required this.promotion});

  final BuyerCatalogProduct product;
  final BuyerProductPromotion? promotion;

  factory BuyerDealProduct.fromJson(Object? value) {
    final json = _dealsMap(value, 'deal_product');
    return BuyerDealProduct(
      product: BuyerCatalogProduct.fromJson(json),
      promotion: json['promotion'] == null
          ? null
          : BuyerProductPromotion.fromJson(json['promotion']),
    );
  }
}

class BuyerProductPromotion {
  const BuyerProductPromotion({
    required this.source,
    required this.name,
    required this.startsAt,
    required this.endsAt,
  });

  final String source;
  final String? name;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory BuyerProductPromotion.fromJson(Object? value) {
    final json = _dealsMap(value, 'deal_product.promotion');
    return BuyerProductPromotion(
      source: _dealsString(json['source'], 'promotion.source'),
      name: _dealsOptionalString(json['name']),
      startsAt: _dealsDate(json['starts_at']),
      endsAt: _dealsDate(json['ends_at']),
    );
  }
}

class BuyerPlatformOffer {
  const BuyerPlatformOffer({
    required this.id,
    required this.name,
    required this.kind,
    required this.discountLabel,
    required this.description,
    required this.terms,
    required this.code,
    required this.minimumSpendMinor,
    required this.startsAt,
    required this.endsAt,
    this.isClaimable = false,
    this.canClaim = false,
    this.claimed = false,
    this.autoApplies = false,
    this.codeApplies = false,
    this.availabilityStatus = 'active',
    this.availabilityReason,
  });

  final int id;
  final String name;
  final String kind;
  final String discountLabel;
  final String? description;
  final String? terms;
  final String? code;
  final int minimumSpendMinor;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isClaimable;
  final bool canClaim;
  final bool claimed;
  final bool autoApplies;
  final bool codeApplies;
  final String availabilityStatus;
  final String? availabilityReason;

  factory BuyerPlatformOffer.fromJson(Object? value) {
    final json = _dealsMap(value, 'platform_offer');
    return BuyerPlatformOffer(
      id: _dealsInt(json['id'], 'offer.id', positive: true),
      name: _dealsString(json['name'], 'offer.name'),
      kind: _dealsString(json['kind'], 'offer.kind'),
      discountLabel: _dealsString(
        json['discount_label'],
        'offer.discount_label',
      ),
      description: _dealsOptionalString(json['description']),
      terms: _dealsOptionalString(json['terms']),
      code: _dealsOptionalString(json['code']),
      minimumSpendMinor: _dealsInt(
        json['minimum_spend_minor'],
        'offer.minimum_spend_minor',
      ),
      startsAt: _dealsDate(json['starts_at']),
      endsAt: _dealsDate(json['ends_at']),
      isClaimable: json['is_claimable'] == true,
      canClaim: json['can_claim'] == true,
      claimed: json['claimed'] == true,
      autoApplies: json['auto_applies'] == true,
      codeApplies: json['code_applies'] == true,
      availabilityStatus:
          _dealsOptionalString(json['availability_status']) ?? 'active',
      availabilityReason: _dealsOptionalString(json['availability_reason']),
    );
  }
}

Map<String, Object?> _dealsMap(Object? value, String field) {
  if (value is! Map) throw BuyerDealsFormatException(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerDealsFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _dealsList(Object? value, String field) {
  if (value is! List) throw BuyerDealsFormatException(field);
  return value.cast<Object?>();
}

int _dealsInt(Object? value, String field, {bool positive = false}) {
  if (value is! int || value < 0 || (positive && value == 0)) {
    throw BuyerDealsFormatException(field);
  }
  return value;
}

String _dealsString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw BuyerDealsFormatException(field);
  }
  return value.trim();
}

String? _dealsOptionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const BuyerDealsFormatException('optional_string');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _dealsDate(Object? value) {
  if (value == null || value == '') return null;
  if (value is! String) throw const BuyerDealsFormatException('date');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const BuyerDealsFormatException('date');
  return parsed;
}
