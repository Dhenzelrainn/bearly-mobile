import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/session_startup_page.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/bearly_theme.dart';
import 'features/buyer/data/buyer_cart_controller.dart';
import 'features/buyer/data/buyer_address_controller.dart';
import 'features/buyer/data/buyer_checkout_repository.dart';
import 'features/buyer/data/buyer_location_repository.dart';
import 'features/buyer/data/buyer_wishlist_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BearlyApp());
}

class BearlyApp extends StatelessWidget {
  BearlyApp({
    super.key,
    AuthService? authService,
    BuyerCartController? cartController,
    BuyerWishlistController? wishlistController,
    BuyerAddressController? addressController,
    BuyerLocationRepository? locationRepository,
    BuyerCheckoutRepository? checkoutRepository,
  }) : authService = authService ?? AuthService() {
    this.cartController =
        cartController ?? BuyerCartController(authService: this.authService);
    this.wishlistController =
        wishlistController ??
        BuyerWishlistController(authService: this.authService);
    this.addressController =
        addressController ??
        BuyerAddressController(authService: this.authService);
    this.locationRepository =
        locationRepository ?? BuyerLocationRepository(apiClient: ApiClient());
    this.checkoutRepository =
        checkoutRepository ??
        BuyerCheckoutRepository(authService: this.authService);
  }

  final AuthService authService;
  late final BuyerCartController cartController;
  late final BuyerWishlistController wishlistController;
  late final BuyerAddressController addressController;
  late final BuyerLocationRepository locationRepository;
  late final BuyerCheckoutRepository checkoutRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bearly',
      debugShowCheckedModeBanner: false,
      theme: BearlyTheme.light(),
      home: SessionStartupPage(authService: authService),
      onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
        settings,
        authService: authService,
        cartController: cartController,
        wishlistController: wishlistController,
        addressController: addressController,
        locationRepository: locationRepository,
        checkoutRepository: checkoutRepository,
      ),
    );
  }
}
