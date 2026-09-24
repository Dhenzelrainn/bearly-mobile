import 'package:flutter/material.dart';

import '../theme/bearly_theme.dart';

class BearlyLogo extends StatelessWidget {
  const BearlyLogo({
    super.key,
    this.height = 46,
    this.width,
    this.onTap,
    this.lightSurface = true,
  });

  final double height;
  final double? width;
  final VoidCallback? onTap;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/images/bearly-logo.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      errorBuilder: (_, __, ___) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_bag_rounded,
            color: BearlyColors.brown900,
            size: height * 0.62,
          ),
          const SizedBox(width: 8),
          Text(
            'bearly',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BearlyColors.brown900,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );

    if (!lightSurface) {
      image = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: BearlyColors.cream50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: image,
      );
    }

    if (onTap == null) return image;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: image,
      ),
    );
  }
}
