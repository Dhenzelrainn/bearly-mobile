import 'package:flutter/material.dart';

import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/pending_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/buyer/presentation/buyer_home_page.dart';
import '../../features/buyer/presentation/buyer_cart_page.dart';
import '../../features/buyer/data/buyer_product.dart';
import '../../features/buyer/presentation/buyer_product_detail_page.dart';
import '../../features/rider/presentation/rider_home_page.dart';
import '../../features/rider/presentation/rider_module_page.dart';
import '../../features/rider/presentation/rider_pending_page.dart';
import '../../features/rider/presentation/rider_register_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const landing = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const pending = '/application/pending';
  static const buyer = '/buyer';
  static const buyerHome = '/buyer/home';
  static const rider = '/rider';
  static const riderDashboard = '/rider/dashboard';
  static const riderRegister = '/rider/register';
  static const riderPending = '/rider/pending';
  static const riderRequests = '/rider/requests';
  static const riderPickup = '/rider/pickup';
  static const riderTransit = '/rider/transit';
  static const riderComplete = '/rider/complete';
  static const riderEarnings = '/rider/earnings';
  static const riderHistory = '/rider/history';
  static const riderMessages = '/rider/messages';
  static const riderAccount = '/rider/account';
  static const buyerCart = '/buyer/cart';
  static const buyerProduct = '/buyer/product';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case landing:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case register:
        return MaterialPageRoute(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordPage(),
          settings: settings,
        );
      case pending:
        return MaterialPageRoute(
          builder: (_) => PendingPage(roleLabel: settings.arguments as String?),
          settings: settings,
        );
      case buyer:
        return MaterialPageRoute(
          builder: (_) => const BuyerHomePage(),
          settings: settings,
        );
      case buyerHome:
        return MaterialPageRoute(
          builder: (_) => const BuyerHomePage(),
          settings: settings,
        );
      case buyerCart:
        return MaterialPageRoute(
          builder: (_) => const BuyerCartPage(),
          settings: settings,
        );
      case buyerProduct:
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
      case rider:
        return MaterialPageRoute(
          builder: (_) => const RiderHomePage(),
          settings: settings,
        );
      case riderDashboard:
        return MaterialPageRoute(
          builder: (_) => const RiderHomePage(),
          settings: settings,
        );
      case riderRegister:
        return MaterialPageRoute(
          builder: (_) => const RiderRegisterPage(),
          settings: settings,
        );
      case riderPending:
        return MaterialPageRoute(
          builder: (_) => const RiderPendingPage(),
          settings: settings,
        );
      case riderRequests:
        return _riderModule(RiderModule.requests, settings);
      case riderPickup:
        return _riderModule(RiderModule.pickup, settings);
      case riderTransit:
        return _riderModule(RiderModule.transit, settings);
      case riderComplete:
        return _riderModule(RiderModule.complete, settings);
      case riderEarnings:
        return _riderModule(RiderModule.earnings, settings);
      case riderHistory:
        return _riderModule(RiderModule.history, settings);
      case riderMessages:
        return _riderModule(RiderModule.messages, settings);
      case riderAccount:
        return _riderModule(RiderModule.account, settings);
      default:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
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
}
