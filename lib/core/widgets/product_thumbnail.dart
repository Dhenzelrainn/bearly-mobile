import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../network/mobile_image_url_policy.dart';
import '../theme/bearly_theme.dart';

/// Sized, cached-by-Flutter thumbnail with matching loading and error states.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 54,
    this.semanticLabel,
  });

  final String? imageUrl;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final url = const MobileImageUrlPolicy(
      allowLocalHttp: kDebugMode,
    ).normalize(imageUrl);
    if (url == null) return _placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).round(),
        cacheHeight: (size * 2).round(),
        semanticLabel: semanticLabel,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : _placeholder(),
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: BearlyColors.cream200,
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Icon(
      Icons.image_outlined,
      size: (size * .42).clamp(18, 30),
      color: BearlyColors.brown500,
    ),
  );
}
