import 'package:flutter/material.dart';

import 'app_route_names.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/models/account_role.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/logout_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/pending_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/buyer/presentation/buyer_home_page.dart';
import '../../features/buyer/presentation/buyer_cart_page.dart';
import '../../features/buyer/models/buyer_product.dart';
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
  }) {
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
            ? const BuyerHomePage()
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
          builder: (_) => const BuyerHomePage(),
          settings: settings,
        );
      case AppRouteNames.buyerHome:
        return MaterialPageRoute(
          builder: (_) => const BuyerHomePage(),
          settings: settings,
        );
      case AppRouteNames.buyerCart:
        return MaterialPageRoute(
          builder: (_) => const BuyerCartPage(),
          settings: settings,
        );
      case AppRouteNames.buyerProduct:
        final product = settings.arguments;
        if (product is BuyerProduct) {
          return MaterialPageRoute(
            builder: (_) => BuyerProductDetailPage(product: product),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const BuyerHomePage(),
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
