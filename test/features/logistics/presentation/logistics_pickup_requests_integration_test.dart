import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/models/logistics_dashboard.dart';
import 'package:bearly_mobile/features/logistics/models/logistics_pickup_request.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_pickup_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard opens Pickup Requests and returns to the dashboard', (
    tester,
  ) async {
    final auth = AuthService(apiClient: ApiClient(), tokenStore: _TokenStore());
    final repository = _FakeLogisticsRepository(auth);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsHomePage(authService: auth, repository: repository),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouteNames.logisticsPickupRequests) {
            return MaterialPageRoute<void>(
              builder: (_) =>
                  LogisticsPickupRequestsPage(repository: repository),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 3 &&
          find
              .byKey(const ValueKey('logistics-open-pickup-requests'))
              .evaluate()
              .isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -420));
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.byKey(const ValueKey('logistics-open-pickup-requests')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pickup Requests'), findsOneWidget);
    expect(find.text('No pickup requests match this status.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh dashboard'), findsOneWidget);
    expect(repository.dashboardLoads, 2);
  });
}

class _FakeLogisticsRepository extends LogisticsRepository {
  _FakeLogisticsRepository(AuthService auth) : super(authService: auth);

  int dashboardLoads = 0;

  @override
  Future<LogisticsDashboard> dashboard() async {
    dashboardLoads++;
    return const LogisticsDashboard(
      providerName: 'Sample Logistics',
      providerStatus: 'active',
      sortingCenter: null,
      setupRequired: false,
      metrics: LogisticsMetrics(
        receivedToday: 0,
        awaitingSorting: 0,
        sortedReady: 0,
        dispatchedShipments: 0,
        activeRoutes: 0,
        sortingExceptions: 0,
        pendingPickupRequests: 0,
        incomingHandoffs: 0,
      ),
      incomingHandoffs: [],
      incomingParcels: [],
    );
  }

  @override
  Future<LogisticsPickupRequestPage> pickupRequests({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async => const LogisticsPickupRequestPage(
    requests: [],
    currentPage: 1,
    lastPage: 1,
    total: 0,
  );
}

class _TokenStore implements SessionTokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}
