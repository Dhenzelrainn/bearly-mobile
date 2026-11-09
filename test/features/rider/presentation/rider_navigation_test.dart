import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/auth/presentation/logout_page.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/models/rider_assignment.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_account_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_assignment_pages.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_earnings_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_history_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_home_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_courier_runs_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_messages_page.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_module_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'dashboard and account use one secondary menu without shortcuts',
    (tester) async {
      await tester.pumpWidget(_navigationApp());
      await tester.pumpAndSettle();

      _expectPrimaryTabs(tester, selectedIndex: 0);
      await _openSecondaryMenu(tester);
      _expectSecondaryMenu(tester);

      await tester.tapAt(const Offset(12, 12));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();

      expect(find.text('Rider Account'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 4);
      await _openSecondaryMenu(tester);
      _expectSecondaryMenu(tester);
    },
  );

  testWidgets(
    'Local Rider navigation stays stable when opening protected tabs',
    (tester) async {
      final requestedPaths = <String>[];
      await tester.pumpWidget(
        _navigationApp(
          requestedPaths: requestedPaths,
          useProductionRoutes: true,
        ),
      );
      await tester.pumpAndSettle();

      _expectPrimaryTabs(tester, selectedIndex: 0);
      expect(
        requestedPaths.where((path) => path == '/api/mobile/rider/account'),
        isEmpty,
      );

      await tester.tap(find.text('Pickups').last);
      await tester.pump();
      final navigationBars = tester.widgetList<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBars, isNotEmpty);
      expect(
        navigationBars.every((bar) => bar.destinations.length == 5),
        isTrue,
      );
      expect(find.text('Checking Rider access'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Assigned Pickups'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 1);

      await tester.tap(find.text('Deliveries').last);
      await tester.pumpAndSettle();
      expect(find.text('Assigned Deliveries'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 2);

      expect(
        requestedPaths.where((path) => path == '/api/mobile/rider/account'),
        isEmpty,
      );
    },
  );

  testWidgets('local actions stay hidden until access is server verified', (
    tester,
  ) async {
    final accountResponse = Completer<http.Response>();
    final authService =
        AuthService(
            apiClient: ApiClient(
              httpClient: MockClient((request) => accountResponse.future),
              baseUri: Uri.parse('http://127.0.0.1:8000'),
            ),
            tokenStore: _MemoryTokenStore()..token = 'test-token',
          )
          ..currentSession = const AuthSession(
            id: 18,
            name: 'Mark Rider',
            email: 'mark@example.test',
            role: AccountRole.rider,
          );
    final repository = RiderRepository(authService: authService);

    await tester.pumpWidget(
      MaterialApp(
        home: RiderLocalFulfillmentGuard(
          repository: repository,
          currentRoute: AppRouteNames.riderRequests,
          child: const Scaffold(body: Text('Protected pickup actions')),
        ),
      ),
    );

    expect(find.text('Checking Rider access'), findsOneWidget);
    expect(find.text('Protected pickup actions'), findsNothing);

    accountResponse.complete(
      http.Response(
        jsonEncode({
          'data': {
            'name': 'Mark Rider',
            'email': 'mark@example.test',
            'account_status': 'active',
            'verification_status': 'approved',
            'availability_status': 'available',
            'work_type': 'courier',
            'capabilities': {'local_pickup': false, 'local_delivery': false},
            'vehicle': {'type': 'Van'},
            'logistics_provider': {},
            'sorting': {},
            'addresses': [],
            'documents': {},
          },
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local work unavailable'), findsOneWidget);
    expect(find.text('Protected pickup actions'), findsNothing);
    _expectCourierTabs(tester, selectedIndex: 0);
  });

  testWidgets(
    'Courier uses shared navigation and account without local fulfillment tabs',
    (tester) async {
      await tester.pumpWidget(_navigationApp(workType: 'courier'));
      await tester.pumpAndSettle();

      expect(find.text('Work type: Courier'), findsOneWidget);
      expect(find.text('Courier Runs'), findsOneWidget);
      _expectCourierTabs(tester, selectedIndex: 0);
      expect(find.text('Pickup assignments'), findsNothing);
      expect(find.text('Delivery assignments'), findsNothing);

      await tester.tap(find.text('Courier Runs'));
      await tester.pumpAndSettle();
      expect(
        find.text('No active Courier runs are assigned to you.'),
        findsOneWidget,
      );
      expect(find.text('Assigned Pickups'), findsNothing);
      expect(find.text('Assigned Deliveries'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      expect(find.text('Rider Account'), findsOneWidget);
      expect(find.text('Courier'), findsOneWidget);
      _expectCourierTabs(tester, selectedIndex: 2);

      await tester.tap(find.text('Earnings').last);
      await tester.pumpAndSettle();
      expect(find.text('Recent earnings'), findsOneWidget);
      expect(find.text('Courier daily earnings'), findsOneWidget);
      _expectCourierTabs(tester, selectedIndex: 1);
      expect(find.text('Pickup assignments'), findsNothing);
      expect(find.text('Delivery assignments'), findsNothing);

      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();

      await _openSecondaryMenu(tester);
      final menuItems = tester
          .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
          .map((item) => item.child)
          .whereType<Text>()
          .map((item) => item.data)
          .toList();
      expect(menuItems, ['Sign out']);
    },
  );

  testWidgets('Courier cannot open a local assignment screen directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _navigationApp(workType: 'courier', useProductionRoutes: true),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RiderHomePage));
    unawaited(Navigator.of(context).pushNamed(AppRouteNames.riderRequests));
    await tester.pumpAndSettle();

    expect(find.text('Local work unavailable'), findsOneWidget);
    expect(find.text('Assigned Pickups'), findsNothing);
    expect(
      find.text('There are no pickup assignments for you right now.'),
      findsNothing,
    );
    _expectCourierTabs(tester, selectedIndex: 0);
  });

  testWidgets(
    'dashboard to account to dashboard replaces tab stack and back works',
    (tester) async {
      final observer = _RouteStackObserver();
      final app = _navigationApp(observer: observer);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      expect(find.text('Rider Account'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 4);
      expect(observer.stack, hasLength(2));

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Mark Rider'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 0);
      expect(observer.stack, hasLength(1));

      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Mark Rider'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 0);
      expect(observer.stack, hasLength(1));
    },
  );

  testWidgets(
    'pickup and delivery screens share the same menu and selected tab',
    (tester) async {
      await tester.pumpWidget(_navigationApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pickups').last);
      await tester.pumpAndSettle();
      expect(
        find.text('There are no pickup assignments for you right now.'),
        findsOneWidget,
      );
      _expectPrimaryTabs(tester, selectedIndex: 1);
      await _openSecondaryMenu(tester);
      _expectSecondaryMenu(tester);

      await tester.tapAt(const Offset(12, 12));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deliveries').last);
      await tester.pumpAndSettle();
      expect(
        find.text('There are no delivery assignments for you right now.'),
        findsOneWidget,
      );
      _expectPrimaryTabs(tester, selectedIndex: 2);
      await _openSecondaryMenu(tester);
      _expectSecondaryMenu(tester);
    },
  );

  testWidgets('sign out remains available in the shared secondary menu', (
    tester,
  ) async {
    await tester.pumpWidget(_navigationApp());
    await tester.pumpAndSettle();

    await _openSecondaryMenu(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out route'), findsOneWidget);
  });

  testWidgets(
    'delivery history opens from the secondary menu and returns home',
    (tester) async {
      await tester.pumpWidget(_navigationApp());
      await tester.pumpAndSettle();

      await _openSecondaryMenu(tester);
      await tester.tap(find.text('Delivery history'));
      await tester.pumpAndSettle();

      expect(find.text('Delivery History'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 2);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Mark Rider'), findsOneWidget);
      _expectPrimaryTabs(tester, selectedIndex: 0);
    },
  );

  testWidgets(
    'Sign out invokes the existing logout flow and clears the session',
    (tester) async {
      var logoutRequests = 0;
      final tokenStore = _MemoryTokenStore()..token = 'test-token';
      final authService =
          AuthService(
              apiClient: ApiClient(
                httpClient: MockClient((request) async {
                  if (request.url.path == '/api/mobile/rider/dashboard') {
                    return http.Response(
                      jsonEncode({
                        'rider': {
                          'name': 'Mark Rider',
                          'vehicle_type': 'Motorcycle',
                          'plate_number': 'TEST-1',
                          'availability_status': 'available',
                          'logistics_provider': 'Bearly Logistics',
                        },
                        'metrics': {
                          'assigned_pickups': 0,
                          'pickup_in_progress': 0,
                          'assigned_deliveries': 0,
                          'out_for_delivery': 0,
                        },
                      }),
                      200,
                    );
                  }
                  if (request.url.path == '/api/mobile/logout') {
                    logoutRequests++;
                    return http.Response(
                      jsonEncode({'message': 'Logged out.'}),
                      200,
                    );
                  }
                  return http.Response('Not found', 404);
                }),
                baseUri: Uri.parse('http://127.0.0.1:8000'),
              ),
              tokenStore: tokenStore,
            )
            ..currentSession = const AuthSession(
              id: 18,
              name: 'Mark Rider',
              email: 'mark@example.test',
              role: AccountRole.rider,
            );
      final repository = RiderRepository(authService: authService);

      await tester.pumpWidget(
        MaterialApp(
          home: RiderHomePage(repository: repository),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => settings.name == AppRouteNames.logout
                ? LogoutPage(authService: authService)
                : const Scaffold(body: Text('Signed out')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSecondaryMenu(tester);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(logoutRequests, 1);
      expect(authService.currentSession, isNull);
      expect(await tokenStore.read(), isNull);
      expect(find.text('Signed out'), findsOneWidget);
    },
  );

  testWidgets(
    'Rider applicant review route remains available outside Rider tabs',
    (tester) async {
      final authService = AuthService();
      final cartController = BuyerCartController(authService: authService);
      final wishlistController = BuyerWishlistController(
        authService: authService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRouteNames.pending,
                  arguments: 'Rider',
                ),
                child: const Text('Review Rider application'),
              ),
            ),
          ),
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
            settings,
            authService: authService,
            cartController: cartController,
            wishlistController: wishlistController,
          ),
        ),
      );

      await tester.tap(find.text('Review Rider application'));
      await tester.pumpAndSettle();
      expect(
        find.text('Selected Logistics / Sorting Center'),
        findsOneWidget,
      );
    },
  );

  testWidgets('dashboard uses a correctly encoded zone separator', (
    tester,
  ) async {
    await tester.pumpWidget(_navigationApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pila / Pinagbayanan · Bearly Logistics'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Pila / Pinagbayanan · Bearly Logistics'), findsOneWidget);
    final malformedSeparator = String.fromCharCodes([
      0x00c3,
      0x201a,
      0x00c2,
      0x00b7,
    ]);
    expect(find.textContaining(malformedSeparator), findsNothing);
  });
}

void _expectPrimaryTabs(WidgetTester tester, {required int selectedIndex}) {
  final navigationBar = tester.widget<NavigationBar>(
    find.byType(NavigationBar),
  );
  expect(
    navigationBar.destinations.map(
      (destination) => (destination as NavigationDestination).label,
    ),
    ['Home', 'Pickups', 'Deliveries', 'Earnings', 'Account'],
  );
  expect(navigationBar.selectedIndex, selectedIndex);
}

void _expectCourierTabs(WidgetTester tester, {required int selectedIndex}) {
  final navigationBar = tester.widget<NavigationBar>(
    find.byType(NavigationBar),
  );
  expect(
    navigationBar.destinations.map(
      (destination) => (destination as NavigationDestination).label,
    ),
    ['Home', 'Earnings', 'Account'],
  );
  expect(navigationBar.selectedIndex, selectedIndex);
}

Future<void> _openSecondaryMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More Rider options'));
  await tester.pumpAndSettle();
}

void _expectSecondaryMenu(WidgetTester tester) {
  final menuItems = tester
      .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
      .map((item) => item.child)
      .whereType<Text>()
      .map((item) => item.data)
      .toList();
  expect(menuItems, ['Delivery history', 'Sign out']);
}

Widget _navigationApp({
  NavigatorObserver? observer,
  String workType = 'local',
  bool useProductionRoutes = false,
  List<String>? requestedPaths,
}) {
  final authService =
      AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((request) async {
              requestedPaths?.add(request.url.path);
              return switch (request.url.path) {
                '/api/mobile/rider/dashboard' => http.Response(
                  jsonEncode({
                    'rider': {
                      'name': 'Mark Rider',
                      'work_type': workType,
                      'capabilities': {
                        'local_pickup': workType != 'courier',
                        'local_delivery': workType != 'courier',
                      },
                      'vehicle_type': 'Motorcycle',
                      'plate_number': 'TEST-1',
                      'availability_status': 'available',
                      'logistics_provider': 'Bearly Logistics',
                      'current_zone': 'Pila / Pinagbayanan',
                      'current_zone_center': 'Bearly Logistics',
                    },
                    'metrics': {
                      'assigned_pickups': 0,
                      'pickup_in_progress': 0,
                      'assigned_deliveries': 0,
                      'out_for_delivery': 0,
                    },
                  }),
                  200,
                ),
                '/api/mobile/rider/account' => http.Response(
                  jsonEncode({
                    'data': {
                      'name': 'Mark Rider',
                      'email': 'mark@example.test',
                      'account_status': 'active',
                      'verification_status': 'approved',
                      'availability_status': 'available',
                      'work_type': workType,
                      'capabilities': {
                        'local_pickup': workType != 'courier',
                        'local_delivery': workType != 'courier',
                      },
                      'vehicle': {
                        'type': 'Motorcycle',
                        'model': 'Test Model',
                        'plate_number': 'TEST-1',
                        'parcel_capacity': 10,
                      },
                      'logistics_provider': {'name': 'Bearly Logistics'},
                      'sorting': {
                        'home_center': 'SC-1',
                        'current_zone': 'Pila / Pinagbayanan',
                        'current_zone_center': 'Bearly Logistics',
                      },
                      'addresses': [],
                      'documents': {},
                    },
                  }),
                  200,
                ),
                '/api/mobile/rider/pickups' || '/api/mobile/rider/deliveries' =>
                  http.Response(jsonEncode({'data': []}), 200),
                '/api/mobile/rider/history' => http.Response(
                  jsonEncode({
                    'data': [],
                    'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
                  }),
                  200,
                ),
                '/api/mobile/rider/earnings' => http.Response.bytes(
                  utf8.encode(jsonEncode(_emptyEarningsPayload(workType))),
                  200,
                ),
                '/api/mobile/rider/courier-runs' => http.Response(
                  jsonEncode({
                    'data': [],
                    'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
                  }),
                  200,
                ),
                _ => http.Response('Not found', 404),
              };
            }),
            baseUri: Uri.parse('http://127.0.0.1:8000'),
          ),
          tokenStore: _MemoryTokenStore()..token = 'test-token',
        )
        ..currentSession = const AuthSession(
          id: 18,
          name: 'Mark Rider',
          email: 'mark@example.test',
          role: AccountRole.rider,
        );
  final repository = RiderRepository(authService: authService);
  final cartController = BuyerCartController(authService: authService);
  final wishlistController = BuyerWishlistController(authService: authService);

  return MaterialApp(
    navigatorObservers: observer == null ? const [] : [observer],
    home: Builder(
      builder: (context) => RiderHomePage(
        repository: repository,
        onOpenCourierRuns: () async {
          await Navigator.of(context).pushNamed(AppRouteNames.riderCourierRuns);
        },
      ),
    ),
    onGenerateRoute: useProductionRoutes
        ? (settings) => AppRoutes.onGenerateRoute(
            settings,
            authService: authService,
            cartController: cartController,
            wishlistController: wishlistController,
          )
        : (settings) {
            final Widget page = switch (settings.name) {
              AppRouteNames.rider => Builder(
                builder: (context) => RiderHomePage(
                  repository: repository,
                  onOpenCourierRuns: () async {
                    await Navigator.of(
                      context,
                    ).pushNamed(AppRouteNames.riderCourierRuns);
                  },
                ),
              ),
              AppRouteNames.riderCourierRuns => RiderCourierRunsPage(
                repository: repository,
              ),
              AppRouteNames.riderRequests => RiderLocalFulfillmentGuard(
                repository: repository,
                currentRoute: settings.name,
                child: RiderAssignmentListPage(
                  repository: repository,
                  kind: RiderAssignmentKind.pickup,
                ),
              ),
              AppRouteNames.riderTransit => RiderLocalFulfillmentGuard(
                repository: repository,
                currentRoute: settings.name,
                child: RiderAssignmentListPage(
                  repository: repository,
                  kind: RiderAssignmentKind.delivery,
                ),
              ),
              AppRouteNames.riderEarnings => RiderEarningsPage(
                repository: repository,
              ),
              AppRouteNames.riderAccount => RiderAccountPage(
                repository: repository,
              ),
              AppRouteNames.riderHistory => RiderLocalFulfillmentGuard(
                repository: repository,
                currentRoute: settings.name,
                child: RiderHistoryPage(repository: repository),
              ),
              AppRouteNames.riderMessages => const RiderMessagesPage(),
              AppRouteNames.logout => const Scaffold(
                body: Center(child: Text('Sign out route')),
              ),
              _ => const Scaffold(body: Text('Unknown route')),
            };
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => page,
            );
          },
  );
}

Map<String, Object?> _emptyEarningsPayload(String workType) => {
  'data': {
    'work_type': workType,
    'currency': 'PHP',
    'summary': {
      'today': {'amount_minor': 0, 'amount': '₱0.00', 'entries': 0},
      'week': {'amount_minor': 0, 'amount': '₱0.00', 'entries': 0},
      'month': {'amount_minor': 0, 'amount': '₱0.00', 'entries': 0},
      'active_total_minor': 0,
      'active_total': '₱0.00',
      'active_entries': 0,
      'pickup_total_minor': 0,
      'pickup_total': '₱0.00',
      'delivery_total_minor': 0,
      'delivery_total': '₱0.00',
      'delivery_pending_minor': 0,
      'delivery_pending': '₱0.00',
      'courier_daily_minor': 0,
      'courier_daily': '₱0.00',
      'combined_total_minor': 0,
      'combined_total': '₱0.00',
      'payout_eligible_minor': 0,
      'payout_eligible': '₱0.00',
      'payout_paid_minor': 0,
      'payout_paid': '₱0.00',
      'payout_status': 'No payout due',
    },
    'courier_daily': workType == 'courier'
        ? {
            'rate_minor': 65000,
            'rate': '₱650.00',
            'today_work_date': '2026-11-06',
            'qualifying_days': 0,
            'total_minor': 0,
            'total': '₱0.00',
            'eligible_minor': 0,
            'eligible': '₱0.00',
            'paid_minor': 0,
            'paid': '₱0.00',
          }
        : null,
    'items': [],
    'meta': {
      'current_page': 1,
      'last_page': 1,
      'per_page': 20,
      'total': 0,
      'next_page': null,
    },
  },
};

class _RouteStackObserver extends NavigatorObserver {
  final List<Route<dynamic>> stack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) stack.remove(oldRoute);
    if (newRoute != null) stack.add(newRoute);
  }
}

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
