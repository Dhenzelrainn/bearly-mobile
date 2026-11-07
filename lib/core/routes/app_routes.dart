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
import '../../features/buyer/data/buyer_deals_repository.dart';
import '../../features/buyer/data/buyer_vouchers_repository.dart';
import '../../features/buyer/data/buyer_chat_repository.dart';
import '../../features/buyer/data/buyer_notifications_repository.dart';
import '../../features/buyer/data/buyer_cart_controller.dart';
import '../../features/buyer/data/buyer_address_controller.dart';
import '../../features/buyer/data/buyer_checkout_repository.dart';
import '../../features/buyer/data/buyer_checkout_placement_controller.dart';
import '../../features/buyer/data/buyer_checkout_review_controller.dart';
import '../../features/buyer/data/buyer_location_repository.dart';
import '../../features/buyer/data/buyer_wishlist_controller.dart';
import '../../features/buyer/models/buyer_checkout_models.dart';
import '../../features/buyer/presentation/buyer_home_page.dart';
import '../../features/buyer/presentation/buyer_cart_page.dart';
import '../../features/buyer/presentation/buyer_checkout_review_page.dart';
import '../../features/buyer/presentation/buyer_order_details_page.dart';
import '../../features/buyer/presentation/buyer_product_detail_page.dart';
import '../../features/buyer/presentation/buyer_deals_page.dart';
import '../../features/buyer/presentation/buyer_vouchers_page.dart';
import '../../features/buyer/presentation/buyer_messages_page.dart';
import '../../features/buyer/presentation/buyer_chat_thread_page.dart';
import '../../features/buyer/presentation/buyer_notifications_page.dart';
import '../../features/notifications/presentation/mobile_notifications_page.dart';
import '../../features/rider/presentation/rider_home_page.dart';
import '../../features/rider/presentation/rider_assignment_pages.dart';
import '../../features/rider/data/rider_repository.dart';
import '../../features/rider/data/rider_notifications_repository.dart';
import '../../features/rider/data/rider_messages_repository.dart';
import '../../features/messaging/data/mobile_messaging_data_source.dart';
import '../../features/rider/models/rider_assignment.dart';
import '../../features/rider/presentation/rider_module_page.dart';
import '../../features/rider/presentation/rider_pending_page.dart';
import '../../features/rider/presentation/rider_register_page.dart';
import '../../features/logistics/data/logistics_repository.dart';
import '../../features/logistics/data/logistics_notifications_repository.dart';
import '../../features/logistics/data/logistics_messages_repository.dart';
import '../../features/logistics/presentation/logistics_home_page.dart';
import '../../features/logistics/presentation/logistics_messages_page.dart';

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
    final riderRepository = RiderRepository(authService: authService);
    final riderNotificationsRepository = RiderNotificationsRepository(
      authService: authService,
    );
    final riderMessagesRepository = RiderMessagesRepository(
      authService: authService,
    );
    final logisticsRepository = LogisticsRepository(authService: authService);
    final logisticsNotificationsRepository = LogisticsNotificationsRepository(
      authService: authService,
    );
    final logisticsMessagesRepository = LogisticsMessagesRepository(
      authService: authService,
    );
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

      final route = switch (sessionRole) {
        AccountRole.buyer => AppRouteNames.buyer,
        AccountRole.rider => AppRouteNames.rider,
        AccountRole.logistics => AppRouteNames.logisticsDashboard,
      };
      return MaterialPageRoute(
        builder: (_) => switch (sessionRole) {
          AccountRole.buyer => BuyerHomePage(
            authService: authService,
            cartController: cartController,
            wishlistController: wishlistController,
            checkoutRepository: resolveCheckoutRepository(),
            addressController: addressController,
            locationRepository: locationRepository,
          ),
          AccountRole.rider => RiderHomePage(
            repository: riderRepository,
            notificationsRepository: riderNotificationsRepository,
            messagesRepository: riderMessagesRepository,
          ),
          AccountRole.logistics => LogisticsHomePage(
            authService: authService,
            repository: logisticsRepository,
            notificationsRepository: logisticsNotificationsRepository,
            messagesRepository: logisticsMessagesRepository,
          ),
        },
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
            final buyNowSelection =
                settings.arguments is BuyerCheckoutBuyNowSelection
                ? settings.arguments! as BuyerCheckoutBuyNowSelection
                : null;
            return BuyerCheckoutReviewPage(
              addressController: resolvedAddressController,
              locationRepository: resolveLocationRepository(),
              reviewController: BuyerCheckoutReviewController(
                authService: authService,
                cartController: cartController,
                addressController: resolvedAddressController,
                checkoutRepository: resolvedCheckoutRepository,
                vouchersRepository: BuyerVouchersRepository(
                  authService: authService,
                ),
                buyNowSelection: buyNowSelection,
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
              onChatSeller: (id) => BuyerChatRepository(
                authService: authService,
              ).startProductConversation(id),
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
      case AppRouteNames.buyerDeals:
        return MaterialPageRoute(
          builder: (context) => BuyerDealsPage(
            repository: BuyerDealsRepository(authService: authService),
            vouchersRepository: BuyerVouchersRepository(
              authService: authService,
            ),
            onOpenProduct: (id) => Navigator.of(
              context,
            ).pushNamed(AppRouteNames.buyerProduct, arguments: id),
          ),
          settings: settings,
        );
      case AppRouteNames.buyerVouchers:
        return MaterialPageRoute(
          builder: (_) => BuyerVouchersPage(
            repository: BuyerVouchersRepository(authService: authService),
          ),
          settings: settings,
        );
      case AppRouteNames.buyerMessages:
        final chatRepository = BuyerChatRepository(authService: authService);
        return MaterialPageRoute(
          builder: (context) => BuyerMessagesPage(
            repository: chatRepository,
            onOpenConversation: (id) async {
              await Navigator.of(
                context,
              ).pushNamed(AppRouteNames.buyerChatThread, arguments: id);
            },
          ),
          settings: settings,
        );
      case AppRouteNames.buyerNotifications:
        final initialUnreadCount = settings.arguments is int
            ? settings.arguments! as int
            : 0;
        return MaterialPageRoute(
          builder: (_) => BuyerNotificationsPage(
            repository: BuyerNotificationsRepository(authService: authService),
            initialUnreadCount: initialUnreadCount,
          ),
          settings: settings,
        );
      case AppRouteNames.buyerChatThread:
        final conversationId = settings.arguments;
        if (conversationId is int && conversationId > 0) {
          return MaterialPageRoute(
            builder: (_) => BuyerChatThreadPage(
              repository: BuyerChatRepository(authService: authService),
              conversationId: conversationId,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => BuyerMessagesPage(
            repository: BuyerChatRepository(authService: authService),
            onOpenConversation: (_) async {},
          ),
          settings: settings,
        );
      case AppRouteNames.rider:
        return MaterialPageRoute(
          builder: (_) => RiderHomePage(
            repository: riderRepository,
            notificationsRepository: riderNotificationsRepository,
            messagesRepository: riderMessagesRepository,
          ),
          settings: settings,
        );
      case AppRouteNames.riderDashboard:
        return MaterialPageRoute(
          builder: (_) => RiderHomePage(
            repository: riderRepository,
            notificationsRepository: riderNotificationsRepository,
            messagesRepository: riderMessagesRepository,
          ),
          settings: settings,
        );
      case AppRouteNames.riderNotifications:
        final initialUnreadCount = settings.arguments is int
            ? settings.arguments! as int
            : 0;
        return MaterialPageRoute(
          builder: (_) => MobileNotificationsPage(
            repository: riderNotificationsRepository,
            initialUnreadCount: initialUnreadCount,
          ),
          settings: settings,
        );
      case AppRouteNames.logisticsDashboard:
        return MaterialPageRoute(
          builder: (_) => LogisticsHomePage(
            authService: authService,
            repository: logisticsRepository,
            notificationsRepository: logisticsNotificationsRepository,
            messagesRepository: logisticsMessagesRepository,
          ),
          settings: settings,
        );
      case AppRouteNames.logisticsMessages:
        return MaterialPageRoute(
          builder: (_) =>
              LogisticsMessagesPage(repository: logisticsMessagesRepository),
          settings: settings,
        );
      case AppRouteNames.logisticsNotifications:
        final initialUnreadCount = settings.arguments is int
            ? settings.arguments! as int
            : 0;
        return MaterialPageRoute(
          builder: (_) => MobileNotificationsPage(
            repository: logisticsNotificationsRepository,
            initialUnreadCount: initialUnreadCount,
          ),
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
        return _riderLocalRoute(
          settings,
          riderRepository,
          RiderAssignmentListPage(
            repository: riderRepository,
            kind: RiderAssignmentKind.pickup,
          ),
        );
      case AppRouteNames.riderPickup:
        return _riderLocalModule(RiderModule.pickup, settings, riderRepository);
      case AppRouteNames.riderTransit:
        return _riderLocalRoute(
          settings,
          riderRepository,
          RiderAssignmentListPage(
            repository: riderRepository,
            kind: RiderAssignmentKind.delivery,
          ),
        );
      case AppRouteNames.riderPickupDetail:
        final pickupNo = settings.arguments;
        if (pickupNo is! String || pickupNo.trim().isEmpty) {
          return _riderLocalRoute(
            settings,
            riderRepository,
            RiderAssignmentListPage(
              repository: riderRepository,
              kind: RiderAssignmentKind.pickup,
            ),
          );
        }
        return _riderLocalRoute(
          settings,
          riderRepository,
          RiderJobDetailPage(
            repository: riderRepository,
            kind: RiderAssignmentKind.pickup,
            jobId: pickupNo,
          ),
        );
      case AppRouteNames.riderDeliveryDetail:
        final shipmentNo = settings.arguments;
        if (shipmentNo is! String || shipmentNo.trim().isEmpty) {
          return _riderLocalRoute(
            settings,
            riderRepository,
            RiderAssignmentListPage(
              repository: riderRepository,
              kind: RiderAssignmentKind.delivery,
            ),
          );
        }
        return _riderLocalRoute(
          settings,
          riderRepository,
          RiderJobDetailPage(
            repository: riderRepository,
            kind: RiderAssignmentKind.delivery,
            jobId: shipmentNo,
          ),
        );
      case AppRouteNames.riderComplete:
        return _riderLocalModule(
          RiderModule.complete,
          settings,
          riderRepository,
        );
      case AppRouteNames.riderEarnings:
        return _riderModule(RiderModule.earnings, settings, riderRepository);
      case AppRouteNames.riderHistory:
        return _riderLocalModule(
          RiderModule.history,
          settings,
          riderRepository,
        );
      case AppRouteNames.riderMessages:
        return _riderModule(
          RiderModule.messages,
          settings,
          riderRepository,
          messagesRepository: riderMessagesRepository,
        );
      case AppRouteNames.riderAccount:
        return _riderModule(RiderModule.account, settings, riderRepository);
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
    RiderRepository repository, {
    MobileMessagingDataSource? messagesRepository,
  }) {
    return MaterialPageRoute(
      builder: (_) => RiderModulePage(
        module: module,
        repository: repository,
        messagesRepository: messagesRepository,
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _riderLocalModule(
    RiderModule module,
    RouteSettings settings,
    RiderRepository repository,
  ) => _riderLocalRoute(
    settings,
    repository,
    RiderModulePage(module: module, repository: repository),
  );

  static Route<dynamic> _riderLocalRoute(
    RouteSettings settings,
    RiderRepository repository,
    Widget child,
  ) => MaterialPageRoute(
    builder: (_) => RiderLocalFulfillmentGuard(
      repository: repository,
      currentRoute: settings.name,
      child: child,
    ),
    settings: settings,
  );

  static AccountRole? _requiredRole(String? name) {
    if ({
      AppRouteNames.buyer,
      AppRouteNames.buyerHome,
      AppRouteNames.buyerCart,
      AppRouteNames.buyerCheckoutReview,
      AppRouteNames.buyerOrderDetails,
      AppRouteNames.buyerProduct,
      AppRouteNames.buyerMessages,
      AppRouteNames.buyerChatThread,
      AppRouteNames.buyerNotifications,
      AppRouteNames.buyerDeals,
      AppRouteNames.buyerVouchers,
    }.contains(name)) {
      return AccountRole.buyer;
    }

    if ({
      AppRouteNames.rider,
      AppRouteNames.riderDashboard,
      AppRouteNames.riderRequests,
      AppRouteNames.riderPickupDetail,
      AppRouteNames.riderPickup,
      AppRouteNames.riderTransit,
      AppRouteNames.riderDeliveryDetail,
      AppRouteNames.riderComplete,
      AppRouteNames.riderEarnings,
      AppRouteNames.riderHistory,
      AppRouteNames.riderMessages,
      AppRouteNames.riderNotifications,
      AppRouteNames.riderAccount,
    }.contains(name)) {
      return AccountRole.rider;
    }

    if ({
      AppRouteNames.logisticsDashboard,
      AppRouteNames.logisticsMessages,
      AppRouteNames.logisticsNotifications,
    }.contains(name)) {
      return AccountRole.logistics;
    }

    return null;
  }
}
