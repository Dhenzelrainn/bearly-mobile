import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_wishlist_controller.dart';

/// A shared Save/Remove control. Unknown membership stays visibly syncing and
/// cannot be mistaken for an authoritative unsaved state.
class BuyerWishlistHeartButton extends StatelessWidget {
  const BuyerWishlistHeartButton({
    super.key,
    required this.controller,
    required this.productId,
    required this.onPressed,
    this.iconSize = 19,
  });

  final BuyerWishlistController controller;
  final int productId;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final saved = controller.isSaved(productId);
      final pending = controller.isPending(productId);
      final synchronizing = saved == null && controller.loadError == null;
      final unavailable = saved == null && controller.loadError != null;
      final enabled = saved != null && !pending;
      final tooltip = pending
          ? 'Updating saved products'
          : synchronizing
          ? 'Syncing saved products'
          : unavailable
          ? 'Refresh saved products to use this control'
          : saved == true
          ? 'Remove from saved products'
          : 'Save product';

      return IconButton.filledTonal(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          foregroundColor: saved == true ? BearlyColors.brown700 : null,
          backgroundColor: saved == true
              ? BearlyColors.gold.withValues(alpha: .35)
              : null,
        ),
        icon: pending || synchronizing
            ? SizedBox.square(
                dimension: iconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : unavailable
            ? Icon(Icons.sync_problem_rounded, size: iconSize)
            : Icon(
                saved == true
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: iconSize,
              ),
      );
    },
  );
}
