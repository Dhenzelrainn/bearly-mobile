import 'package:flutter/material.dart';

import 'app_route_names.dart';
import '../network/api_client.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/models/account_role.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/logout_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/pending_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/buyer/data/buyer_catalog_repository.dart';
import '../../features/buyer/data/buyer_cart_controller.dart';
import '../../features/buyer/data/buyer_address_controller.dart';
import '../../features/buyer/data/buyer_checkout_repository.dart';
import '../../features/buyer/data/buyer_checkout_placement_controller.dart';
import '../../features/buyer/data/buyer_checkout_review_controller.dart';
import '../../features/buyer/data/buyer_location_repository.dart';
import '../../features/buyer/data/buyer_wishlist_controller.dart';
import '../../features/buyer/presentation/buyer_home_page.dart';
import '../../features/buyer/presentation/buyer_cart_page.dart';
import '../../features/buyer/presentation/buyer_checkout_review_page.dart';
import '../../features/buyer/presentation/buyer_order_details_page.dart';
import '../../features/buyer/presentation/buyer_product_detail_page.dart';
import '../../features/rider/presentation/rider_home_page.dart';
import '../../features/rider/presentation/rider_module_page.dart';
import '../../features/rider/presentation/rider_pending_page.dart';
import '../../features/rider/presentation/rider_register_page.dart';

class AppRoutes {
  const AppRoutes._();

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    required AuthService authService,
    required BuyerCartController cartController,
    required BuyerWishlistController wishlistController,
    BuyerAddressController? addressController,
    BuyerLocationRepository? locationRepository,
    BuyerCheckoutRepository? checkoutRepository,
  }) {
    BuyerAddressController? fallbackAddressController;
    BuyerLocationRepository? fallbackLocationRepository;
    BuyerCheckoutRepository? fallbackCheckoutRepository;
    BuyerAddressController resolveAddressController() =>
        addressController ??
        (fallbackAddressController ??= BuyerAddressController(
          authService: authService,
        ));
    BuyerLocationRepository resolveLocationRepository() =>
        locationRepository ??
        (fallbackLocationRepository ??= BuyerLocationRepository(
          apiClient: ApiClient(),
        ));
    BuyerCheckoutRepository resolveCheckoutRepository() =>
        checkoutRepository ??
        (fallbackCheckoutRepository ??= BuyerCheckoutRepository(
          authService: authService,
        ));
    final requiredRole = _requiredRole(settings.name);
    final sessionRole = authService.currentSession?.role;
    if (requiredRole != null && sessionRole != requiredRole) {
      if (sessionRole == null) {
        return MaterialPageRoute(
          builder: (_) => LoginPage(authService: authService),
          settings: settings,
        );
      }

      final route = sessionRole == AccountRole.buyer
          ? AppRouteNames.buyer
          : AppRouteNames.rider;
      return MaterialPageRoute(
        builder: (_) => sessionRole == AccountRole.buyer
            ? BuyerHomePage(
                authService: authService,
                cartController: cartController,
                wishlistController: wishlistController,
                checkoutRepository: resolveCheckoutRepository(),
                addressController: addressController,
                locationRepository: locationRepository,
              )
            : const RiderHomePage(),
        settings: RouteSettings(name: route),
      );
    }

    switch (settings.name) {
      case AppRouteNames.landing:
        return MaterialPageRoute(
          builder: (_) => LoginPage(authService: authService),
          settings: settings,
        );
      case AppRouteNames.login:
        return MaterialPageRoute(
          builder: (_) => LoginPage(authService: authService),
          settings: settings,
        );
      case AppRouteNames.logout:
        return MaterialPageRoute(
          builder: (_) => LogoutPage(authService: authService),
          settings: settings,
        );
      case AppRouteNames.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
      case AppRouteNames.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordPage(),
          settings: settings,
        );
      case AppRouteNames.pending:
        return MaterialPageRoute(
          builder: (_) => PendingPage(roleLabel: settings.arguments as String?),
          settings: settings,
        );
      case AppRouteNames.buyer:
        return MaterialPageRoute(
          builder: (_) => BuyerHomePage(
            authService: authService,
            cartController: cartController,
            wishlistController: wishlistController,
            checkoutRepository: resolveCheckoutRepository(),
            addressController: addressController,
            locationRepository: locationRepository,
          ),
          settings: settings,
        );
      case AppRouteNames.buyerHome:
        return MaterialPageRoute(
          builder: (_) => BuyerHomePage(
            authService: authService,
            cartController: cartController,
            wishlistController: wishlistController,
            checkoutRepository: resolveCheckoutRepository(),
            addressController: addressController,
            locationRepository: locationRepository,
          ),
          settings: settings,
        );
      case AppRouteNames.buyerCart:
        return MaterialPageRoute(
          builder: (_) => BuyerCartPage(cartController: cartController),
          settings: settings,
        );
      case AppRouteNames.buyerCheckoutReview:
        return MaterialPageRoute(
          builder: (_) {
            final resolvedAddressController = resolveAddressController();
            final resolvedCheckoutRepository = resolveCheckoutRepository();
            return BuyerCheckoutReviewPage(
              addressController: resolvedAddressController,
              locationRepository: resolveLocationRepository(),
              reviewController: BuyerCheckoutReviewController(
                authService: authService,
                cartController: cartController,
                addressController: resolvedAddressController,
                checkoutRepository: resolvedCheckoutRepository,
              ),
              placementController: BuyerCheckoutPlacementController(
                authService: authService,
                checkoutRepository: resolvedCheckoutRepository,
                cartController: cartController,
              ),
            );
          },
          settings: settings,
        );
      case AppRouteNames.buyerOrderDetails:
        final orderId = settings.arguments;
        if (orderId is int && orderId > 0) {
          return MaterialPageRoute(
            builder: (context) => BuyerOrderDetailsPage(
              authService: authService,
              checkoutRepository: resolveCheckoutRepository(),
              orderId: orderId,
              onSignInAgain: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRouteNames.login, (_) => false),
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(child: Text('This order could not be opened.')),
          ),
          settings: settings,
        );
      case AppRouteNames.buyerProduct:
        final productId = settings.arguments;
        if (productId is int && productId > 0) {
          return MaterialPageRoute(
            builder: (_) => BuyerProductDetailPage(
              productId: productId,
              repository: BuyerCatalogRepository(authService: authService),
              cartController: cartController,
              wishlistController: wishlistController,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => BuyerHomePage(
            authService: authService,
            cartController: cartController,
            wishlistController: wishlistController,
            checkoutRepository: resolveCheckoutRepository(),
            addressController: addressController,
            locationRepository: locationRepository,
          ),
          settings: settings,
        );
      case AppRouteNames.rider:
        return MaterialPageRoute(
          builder: (_) => const RiderHomePage(),
          settings: settings,
        );
      case AppRouteNames.riderDashboard:
        return MaterialPageRoute(
          builder: (_) => const RiderHomePage(),
          settings: settings,
        );
      case AppRouteNames.riderRegister:
        return MaterialPageRoute(
          builder: (_) => const RiderRegisterPage(),
          settings: settings,
        );
      case AppRouteNames.riderPending:
        return MaterialPageRoute(
          builder: (_) => const RiderPendingPage(),
          settings: settings,
        );
      case AppRouteNames.riderRequests:
        return _riderModule(RiderModule.requests, settings);
      case AppRouteNames.riderPickup:
        return _riderModule(RiderModule.pickup, settings);
      case AppRouteNames.riderTransit:
        return _riderModule(RiderModule.transit, settings);
      case AppRouteNames.riderComplete:
        return _riderModule(RiderModule.complete, settings);
      case AppRouteNames.riderEarnings:
        return _riderModule(RiderModule.earnings, settings);
      case AppRouteNames.riderHistory:
        return _riderModule(RiderModule.history, settings);
      case AppRouteNames.riderMessages:
        return _riderModule(RiderModule.messages, settings);
      case AppRouteNames.riderAccount:
        return _riderModule(RiderModule.account, settings);
      default:
        return MaterialPageRoute(
          builder: (_) => LoginPage(authService: authService),
          settings: settings,
        );
    }
  }

  static Route<dynamic> _riderModule(
    RiderModule module,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(
      builder: (_) => RiderModulePage(module: module),
      settings: settings,
    );
  }

  static AccountRole? _requiredRole(String? name) {
    if ({
      AppRouteNames.buyer,
      AppRouteNames.buyerHome,
      AppRouteNames.buyerCart,
      AppRouteNames.buyerCheckoutReview,
      AppRouteNames.buyerOrderDetails,
      AppRouteNames.buyerProduct,
    }.contains(name)) {
      return AccountRole.buyer;
    }

    if ({
      AppRouteNames.rider,
      AppRouteNames.riderDashboard,
      AppRouteNames.riderRequests,
      AppRouteNames.riderPickup,
      AppRouteNames.riderTransit,
      AppRouteNames.riderComplete,
      AppRouteNames.riderEarnings,
      AppRouteNames.riderHistory,
      AppRouteNames.riderMessages,
      AppRouteNames.riderAccount,
    }.contains(name)) {
      return AccountRole.rider;
    }

    return null;
  }
}
