/// Minimal purchased-item data shared by Buyer, Rider, and Logistics views.
class ProductPreview {
  const ProductPreview({
    required this.name,
    required this.variant,
    required this.quantity,
    required this.imageUrl,
  });

  final String name;
  final String variant;
  final int quantity;
  final String? imageUrl;

  factory ProductPreview.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Bearly returned an invalid product preview.');
    }
    final json = value.map((key, value) => MapEntry('$key', value));
    return ProductPreview(
      name: _firstString(json, const ['name', 'product_name']),
      variant: _firstString(json, const ['variant', 'variant_name']),
      quantity: _integer(json['quantity']),
      imageUrl: _firstString(json, const ['image_url', 'product_image_url']),
    );
  }

  static List<ProductPreview> listFromJson(Object? value) => value is List
      ? value.map(ProductPreview.fromJson).toList(growable: false)
      : const <ProductPreview>[];
}

String _firstString(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) return value.trim();
  }
  return '';
}

int _integer(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
