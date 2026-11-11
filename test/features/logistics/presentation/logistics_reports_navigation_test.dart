import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('dashboard opens Reports and refreshes on return', (
    tester,
  ) async {
    var dashboardReads = 0;
    final auth = _auth((request) async {
      if (request.url.path == '/api/mobile/logistics/dashboard') {
        dashboardReads++;
        return http.Response(jsonEncode(_dashboard()), 200);
      }
      if (request.url.path == '/api/mobile/logistics/reports') {
        return http.Response(jsonEncode(_reports()), 200);
      }
      return http.Response('Not found', 404);
    });
    final cart = BuyerCartController(authService: auth);
    final wishlist = BuyerWishlistController(authService: auth);

    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsHomePage(
          authService: auth,
          repository: LogisticsRepository(authService: auth),
        ),
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
          settings,
          authService: auth,
          cartController: cart,
          wishlistController: wishlist,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('logistics-open-reports')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('logistics-open-reports')));
    await tester.pumpAndSettle();
    expect(find.text('Operations summary'), findsOneWidget);
    expect(find.text('Parcel throughput'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(dashboardReads, 2);

    cart.dispose();
    wishlist.dispose();
  });
}

Map<String, Object?> _dashboard() => {
  'data': {
    'provider': {'id': 3, 'name': 'Victoria Logistics', 'status': 'active'},
    'sorting_center': {
      'id': 3,
      'name': 'Victoria Sorting Center',
      'code': 'SC-VIC-3',
      'status': 'active',
      'address': 'Victoria, Laguna',
    },
    'setup_required': false,
    'metrics': {
      'received_today': 1,
      'awaiting_sorting': 2,
      'sorted_ready': 1,
      'dispatched_shipments': 4,
      'active_routes': 1,
      'sorting_exceptions': 0,
      'pending_pickup_requests': 0,
      'incoming_handoffs': 0,
    },
    'incoming': {'handoffs': [], 'parcels': []},
  },
};

Map<String, Object?> _reports() => {
  'data': {
    'period': {
      'from': '2026-11-05',
      'to': '2026-11-11',
      'timezone': 'Asia/Manila',
    },
    'summary': {
      'parcel_throughput': 1,
      'delivered_parcels': 1,
      'success_rate_percent': 100,
      'resolved_delivery_outcomes': 1,
      'average_sort_time': '30m',
    },
    'daily_throughput': [
      {'label': 'Nov 11', 'parcel_count': 1},
    ],
    'delivery_status_breakdown': [
      {'label': 'Delivered', 'value': 1, 'share': 100},
    ],
    'rider_performance': [],
  },
};

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'logistics-test-token',
      )
      ..currentSession = const AuthSession(
        id: 19,
        name: 'Logistics Operator',
        email: 'operator@example.test',
        role: AccountRole.logistics,
      );

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
