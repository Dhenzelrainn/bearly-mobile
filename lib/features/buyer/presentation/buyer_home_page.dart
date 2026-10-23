import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_cart_controller.dart';
import '../data/buyer_catalog_repository.dart';
import '../data/buyer_wishlist_controller.dart';
import '../models/buyer_catalog_models.dart';
import 'buyer_account_page.dart';
import 'buyer_orders_page.dart';
import 'buyer_saved_page.dart';
import 'buyer_shop_page.dart';

/// Buyer shell: navigation and shared buyer state live here; each tab owns its
/// actual page UI in a separate file.
class BuyerHomePage extends StatefulWidget {
  const BuyerHomePage({
    super.key,
    required this.authService,
    required this.cartController,
    required this.wishlistController,
    this.catalogRepository,
  });

  final AuthService authService;
  final BuyerCartController cartController;
  final BuyerWishlistController wishlistController;
  final BuyerCatalogRepository? catalogRepository;

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  int _tab = 0;
  late final BuyerCatalogRepository _catalogRepository =
      widget.catalogRepository ??
      BuyerCatalogRepository(authService: widget.authService);

  @override
  void initState() {
    super.initState();
    widget.cartController.synchronizeSession();
    widget.wishlistController.synchronizeSession();
    unawaited(widget.wishlistController.refresh());
  }

  void _logout() {
    widget.cartController.clear();
    widget.wishlistController.clear();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouteNames.logout,
      (_) => false,
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _showUnavailableAction(String action) =>
      _showMessage('$action will be available in a later phase.');

  void _signInAgain() => Navigator.pushNamedAndRemoveUntil(
    context,
    AppRouteNames.login,
    (_) => false,
  );

  void _openProduct(int productId) => Navigator.pushNamed(
    context,
    AppRouteNames.buyerProduct,
    arguments: productId,
  );

  Future<void> _toggleWishlist(BuyerCatalogProduct product) async {
    final wasSaved = widget.wishlistController.isSaved(product.id) == true;
    try {
      final saved = await widget.wishlistController.toggleProduct(product);
      if (!mounted || !saved) return;
      _showMessage(
        wasSaved ? 'Removed from saved products.' : 'Added to saved products.',
      );
    } catch (error) {
      if (!mounted) return;
      final needsSignIn = _needsSignIn(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(buyerWishlistErrorMessage(error)),
          action: needsSignIn
              ? SnackBarAction(label: 'Sign in', onPressed: _signInAgain)
              : null,
        ),
      );
    }
  }

  bool _needsSignIn(Object error) =>
      error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BearlyLogo(height: 34, width: 102),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () =>
                Navigator.pushNamed(context, AppRouteNames.buyerCart),
            icon: ListenableBuilder(
              listenable: widget.cartController,
              builder: (context, _) {
                final count = widget.cartController.cart?.cartCount ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.shopping_cart_outlined),
                );
              },
            ),
          ),
          IconButton(
            onPressed: () => _showMessage('You are all caught up.'),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          BuyerShopPage(
            repository: _catalogRepository,
            wishlistController: widget.wishlistController,
            onToggleWishlist: _toggleWishlist,
            onOpenProduct: _openProduct,
            onUnavailableAction: _showUnavailableAction,
            onSignInAgain: _signInAgain,
          ),
          const BuyerOrdersPage(),
          BuyerSavedPage(
            controller: widget.wishlistController,
            isActive: _tab == 2,
            onOpenProduct: _openProduct,
            onSignInAgain: _signInAgain,
            onWishlistError: (error) {
              final needsSignIn = _needsSignIn(error);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(buyerWishlistErrorMessage(error)),
                  action: needsSignIn
                      ? SnackBarAction(
                          label: 'Sign in',
                          onPressed: _signInAgain,
                        )
                      : null,
                ),
              );
            },
          ),
          BuyerAccountPage(onLogout: _logout, onMessage: _showMessage),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _tab,
        onDestinationSelected: (value) {
          setState(() => _tab = value);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: false,
              child: const Icon(Icons.favorite_border_rounded),
            ),
            selectedIcon: const Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
