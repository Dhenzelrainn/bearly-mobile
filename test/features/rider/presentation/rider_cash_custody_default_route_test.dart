import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Rider role fallback keeps Local Rider Cash Custody accessible', (
    tester,
  ) async {
    final auth = _auth();
    final cart = BuyerCartController(authService: auth);
    final wishlist = BuyerWishlistController(authService: auth);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouteNames.buyerHome),
              child: const Text('Open redirected home'),
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
    await tester.tap(find.text('Open redirected home'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cash Custody'));
    await tester.tap(find.text('Cash Custody'));
    await tester.pumpAndSettle();
    expect(find.text('Cash Custody'), findsOneWidget);
    expect(find.text('No cash custody records yet'), findsOneWidget);

    cart.dispose();
    wishlist.dispose();
  });
}

AuthService _auth() =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/api/mobile/rider/dashboard':
                return _json({
                  'rider': {
                    'name': 'Local Rider',
                    'work_type': 'local',
                    'capabilities': {
                      'local_pickup': true,
                      'local_delivery': true,
                    },
                    'vehicle_type': 'Motorcycle',
                    'availability_status': 'offline',
                    'logistics_provider': 'North Logistics',
                  },
                  'metrics': {
                    'assigned_pickups': 0,
                    'pickup_in_progress': 0,
                    'assigned_deliveries': 0,
                    'out_for_delivery': 0,
                  },
                });
              case '/api/mobile/rider/account':
                return _json({
                  'data': {
                    'name': 'Local Rider',
                    'email': 'rider@example.test',
                    'account_status': 'active',
                    'verification_status': 'approved',
                    'availability_status': 'offline',
                    'work_type': 'local',
                    'capabilities': {
                      'local_pickup': true,
                      'local_delivery': true,
                    },
                    'vehicle': {
                      'type': 'Motorcycle',
                      'model': '',
                      'plate_number': '',
                    },
                    'logistics_provider': {'name': 'North Logistics'},
                    'sorting': {
                      'home_center': '',
                      'current_zone': '',
                      'current_zone_center': '',
                    },
                    'addresses': [],
                    'documents': {},
                  },
                });
              case '/api/mobile/rider/cash-custody':
                return _json({
                  'data': {
                    'summary': {
                      'cod_collected_minor': 0,
                      'cod_handoff_pending_minor': 0,
                      'refund_cash_with_rider_minor': 0,
                    },
                    'cod_collections': [],
                    'refund_cash': [],
                  },
                });
              default:
                if (request.url.path.endsWith('/notifications/unread-count') ||
                    request.url.path.endsWith('/messages/unread-count')) {
                  return _json({
                    'data': {'unread_count': 0},
                  });
                }
                return _json({'message': 'Not found'}, 404);
            }
          }),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'local-rider-token',
      )
      ..currentSession = const AuthSession(
        id: 17,
        name: 'Local Rider',
        email: 'rider@example.test',
        role: AccountRole.rider,
      );

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
