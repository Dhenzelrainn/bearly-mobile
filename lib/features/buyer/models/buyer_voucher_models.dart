class BuyerVoucherFormatException implements Exception {
  const BuyerVoucherFormatException(this.field);

  final String field;

  @override
  String toString() => 'Invalid Buyer voucher response field: $field.';
}

class BuyerVoucherCategory {
  const BuyerVoucherCategory({required this.key, required this.label});

  final String key;
  final String label;

  factory BuyerVoucherCategory.fromJson(Object? value) {
    final json = _voucherMap(value, 'category');
    return BuyerVoucherCategory(
      key: _voucherString(json['key'], 'category.key'),
      label: _voucherString(json['label'], 'category.label'),
    );
  }
}

class BuyerVoucherWallet {
  BuyerVoucherWallet({
    required List<BuyerVoucher> platform,
    required List<BuyerVoucher> store,
    required this.claimedCount,
    required List<BuyerVoucherCategory> categories,
  }) : platform = List.unmodifiable(platform),
       store = List.unmodifiable(store),
       categories = List.unmodifiable(categories);

  final List<BuyerVoucher> platform;
  final List<BuyerVoucher> store;
  final int claimedCount;
  final List<BuyerVoucherCategory> categories;

  List<BuyerVoucher> get vouchers => List.unmodifiable([...platform, ...store]);
  List<BuyerVoucher> get claimed =>
      List.unmodifiable(vouchers.where((voucher) => voucher.isClaimed));
  List<BuyerVoucher> get available =>
      List.unmodifiable(vouchers.where((voucher) => voucher.canClaim));

  factory BuyerVoucherWallet.fromJson(Object? value) {
    final root = _voucherMap(value, 'root');
    final data = _voucherMap(root['data'], 'data');
    final categoriesValue = data['categories'];
    return BuyerVoucherWallet(
      platform: _voucherList(
        data['platform'],
        'data.platform',
      ).map(BuyerVoucher.fromJson).toList(growable: false),
      store: _voucherList(
        data['store'],
        'data.store',
      ).map(BuyerVoucher.fromJson).toList(growable: false),
      claimedCount: _voucherInt(data['claimed_count'], 'data.claimed_count'),
      categories: categoriesValue == null
          ? const []
          : _voucherList(
              categoriesValue,
              'data.categories',
            ).map(BuyerVoucherCategory.fromJson).toList(growable: false),
    );
  }
}

class BuyerVoucher {
  const BuyerVoucher({
    required this.source,
    required this.id,
    required this.name,
    required this.title,
    required this.valueLabel,
    required this.minimumSpendMinor,
    required this.expiresAt,
    required this.section,
    required this.claimed,
    required this.canClaim,
    required this.canUse,
    required this.autoApplies,
    required this.codeApplies,
    required this.availabilityStatus,
    required this.availabilityReason,
    required this.description,
    required this.terms,
    required this.code,
    required this.fundingType,
  });

  final String source;
  final int id;
  final String name;
  final String title;
  final String valueLabel;
  final int minimumSpendMinor;
  final DateTime? expiresAt;
  final String section;
  final bool claimed;
  final bool canClaim;
  final bool canUse;
  final bool autoApplies;
  final bool codeApplies;
  final String availabilityStatus;
  final String? availabilityReason;
  final String? description;
  final String? terms;
  final String? code;
  final String? fundingType;

  bool get isClaimed => claimed;
  bool get isStoreVoucher => source == 'store';

  factory BuyerVoucher.fromJson(Object? value) {
    final json = _voucherMap(value, 'voucher');
    return BuyerVoucher(
      source: _voucherString(json['source'], 'voucher.source'),
      id: _voucherInt(json['id'], 'voucher.id', positive: true),
      name: _voucherString(json['name'], 'voucher.name'),
      title: _voucherString(json['title'], 'voucher.title'),
      valueLabel: _voucherString(json['value_label'], 'voucher.value_label'),
      minimumSpendMinor: _voucherInt(
        json['min_spend_minor'] ?? 0,
        'voucher.min_spend_minor',
      ),
      expiresAt: _voucherDate(json['expires_at']),
      section: _voucherOptionalString(json['section']) ?? 'discount',
      claimed: json['claimed'] == true,
      canClaim: json['can_claim'] == true,
      canUse: json['can_use'] == true,
      autoApplies: json['auto_applies'] == true,
      codeApplies: json['code_applies'] == true,
      availabilityStatus:
          _voucherOptionalString(json['availability_status']) ?? 'unavailable',
      availabilityReason: _voucherOptionalString(json['availability_reason']),
      description: _voucherOptionalString(json['description']),
      terms: _voucherOptionalString(json['terms']),
      code: _voucherOptionalString(json['code']),
      fundingType: _voucherOptionalString(json['funding_type']),
    );
  }
}

Map<String, Object?> _voucherMap(Object? value, String field) {
  if (value is! Map) throw BuyerVoucherFormatException(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerVoucherFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _voucherList(Object? value, String field) {
  if (value is! List) throw BuyerVoucherFormatException(field);
  return value.cast<Object?>();
}

String _voucherString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw BuyerVoucherFormatException(field);
  }
  return value.trim();
}

String? _voucherOptionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const BuyerVoucherFormatException('string');
  final text = value.trim();
  return text.isEmpty ? null : text;
}

int _voucherInt(Object? value, String field, {bool positive = false}) {
  final number = value is int ? value : int.tryParse('$value');
  if (number == null || number < 0 || (positive && number == 0)) {
    throw BuyerVoucherFormatException(field);
  }
  return number;
}

DateTime? _voucherDate(Object? value) {
  if (value == null || value == '') return null;
  if (value is! String) throw const BuyerVoucherFormatException('date');
  final date = DateTime.tryParse(value);
  if (date == null) throw const BuyerVoucherFormatException('date');
  return date;
}
