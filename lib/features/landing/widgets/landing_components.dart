import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/landing_models.dart';
import 'sprite_atlas_image.dart';

class LandingBrandStrip extends StatelessWidget {
  const LandingBrandStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      color: BearlyColors.brown950,
      child: Text(
        'Find more. Live better.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, letterSpacing: .4),
      ),
    );
  }
}

class LandingCampaignCard extends StatelessWidget {
  const LandingCampaignCard({
    super.key,
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String image;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: BearlyColors.cream300),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB32C1A14)],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Text('Shop collection ↗', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LandingProductCard extends StatelessWidget {
  const LandingProductCard({
    super.key,
    required this.product,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  final LandingProduct product;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: BearlyColors.lineSoft),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SpriteAtlasImage(
                      assetPath: product.atlas == 'mixed'
                          ? 'assets/images/landing/mixed-products.webp'
                          : 'assets/images/catalog-placeholders.png',
                      cell: product.cell,
                      rows: product.atlas == 'mixed' ? 3 : 4,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: saved ? 'Remove from saved' : 'Save product',
                        onPressed: onSave,
                        icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.shop,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LandingEyebrow extends StatelessWidget {
  const LandingEyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: BearlyColors.gold,
            letterSpacing: 1.35,
          ),
    );
  }
}
