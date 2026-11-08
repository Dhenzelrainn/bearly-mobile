import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_riders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Logistics dashboard opens provider roster and Rider details', (
    tester,
  ) async {
    var dashboardRequests = 0;
    var rosterRequests = 0;
    final auth = _auth((request) async {
      switch (request.url.path) {
        case '/api/mobile/logistics/dashboard':
          dashboardRequests++;
          return _json(_dashboard());
        case '/api/mobile/logistics/notifications/unread-count':
        case '/api/mobile/logistics/messages/unread-count':
          return _json({
            'data': {'unread_count': 0},
          });
        case '/api/mobile/logistics/riders':
          rosterRequests++;
          return _json(_roster());
        case '/api/mobile/logistics/riders/41':
          return _json({
            'data': {
              'provider': {'id': 3, 'name': 'North Logistics'},
              'rider': _rider(),
            },
          });
        default:
          return _json({'message': 'Not found'}, 404);
      }
    });
    final cart = BuyerCartController(authService: auth);
    final wishlist = BuyerWishlistController(authService: auth);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(AppRouteNames.logisticsDashboard),
              child: const Text('Open dashboard'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
          settings,
          authService: auth,
          cartController: cart,
          wishlistController: wishlist,
        ),
      ),
    );
    await tester.tap(find.text('Open dashboard'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('logistics-open-rider-management')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('logistics-open-rider-management')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LogisticsRidersPage), findsOneWidget);
    expect(find.text('Alex Rider'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('logistics-rider-41')));
    await tester.pumpAndSettle();
    expect(find.byType(LogisticsRiderDetailsPage), findsOneWidget);
    expect(find.text('Verification Approved'), findsOneWidget);
    expect(find.text('Local parcels'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(rosterRequests, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(dashboardRequests, 2);
    cart.dispose();
    wishlist.dispose();
  });
}

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('https://api.example.test'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'logistics-test-token',
      )
      ..currentSession = const AuthSession(
        id: 19,
        name: 'Logistics Operator',
        email: 'operator@example.test',
        role: AccountRole.logistics,
      );

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

Map<String, Object?> _dashboard() => {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics', 'status': 'active'},
    'sorting_center': {
      'id': 3,
      'name': 'North Center',
      'code': 'SC-NORTH',
      'status': 'active',
      'address': 'North District',
    },
    'setup_required': false,
    'metrics': {
      'received_today': 0,
      'awaiting_sorting': 0,
      'sorted_ready': 0,
      'dispatched_shipments': 0,
      'active_routes': 0,
      'sorting_exceptions': 0,
      'pending_pickup_requests': 0,
      'incoming_handoffs': 0,
    },
    'incoming': {'handoffs': [], 'parcels': []},
  },
};

Map<String, Object?> _roster() => {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'riders': [_rider()],
  },
};

Map<String, Object?> _rider() => {
  'id': 41,
  'user_id': 41,
  'profile_id': 141,
  'name': 'Alex Rider',
  'work_type': 'local',
  'work_type_label': 'Local Rider',
  'account_status': 'active',
  'verification_status': 'approved',
  'application_status': 'approved',
  'availability_status': 'available',
  'operational_status': 'assigned',
  'vehicle_type': 'Motorcycle',
  'vehicle_model': 'Cargo 150',
  'plate_number': 'ABC-1234',
  'current_zone': 'North Zone',
  'home_sorting_center': 'North Center',
  'specialization': 'both',
  'specialization_label': 'Pickup and delivery',
  'capacity': 8,
  'capacity_label': 'Local parcels',
  'active_jobs': 2,
  'completed_today': 1,
};

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
