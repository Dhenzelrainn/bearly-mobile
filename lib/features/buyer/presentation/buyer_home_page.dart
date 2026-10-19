import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../data/buyer_demo_data.dart';
import '../models/buyer_product.dart';
import 'buyer_account_page.dart';
import 'buyer_orders_page.dart';
import 'buyer_saved_page.dart';
import 'buyer_shop_page.dart';

/// Buyer shell: navigation and shared buyer state live here; each tab owns its
/// actual page UI in a separate file.
class BuyerHomePage extends StatefulWidget {
  const BuyerHomePage({super.key});

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  int _tab = 0;
  String _query = '';
  final Set<String> _saved = <String>{};
  int _cartCount = 0;

  void _logout() =>
      Navigator.pushNamedAndRemoveUntil(context, AppRouteNames.login, (_) => false);

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _toggleSaved(BuyerProduct product) {
    setState(() {
      if (!_saved.add(product.name)) _saved.remove(product.name);
    });
  }

  void _addToCart(BuyerProduct product) {
    setState(() => _cartCount++);
    _showMessage('${product.name} added to cart.');
  }

  @override
  Widget build(BuildContext context) {
    final savedProducts = buyerProducts
        .where((product) => _saved.contains(product.name))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const BearlyLogo(height: 34, width: 102),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => Navigator.pushNamed(context, AppRouteNames.buyerCart),
            icon: Badge(
              label: Text('$_cartCount'),
              isLabelVisible: _cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
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
            query: _query,
            saved: _saved,
            onQueryChanged: (value) => setState(() => _query = value),
            onToggleSaved: _toggleSaved,
            onAddToCart: _addToCart,
            onMessage: _showMessage,
          ),
          const BuyerOrdersPage(),
          BuyerSavedPage(products: savedProducts, onAddToCart: _addToCart),
          BuyerAccountPage(onLogout: _logout, onMessage: _showMessage),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
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
              label: Text('${_saved.length}'),
              isLabelVisible: _saved.isNotEmpty,
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
