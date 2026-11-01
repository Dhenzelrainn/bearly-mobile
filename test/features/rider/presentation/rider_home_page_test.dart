import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('refreshes assigned delivery count after returning from list', (
    tester,
  ) async {
    var dashboardRequests = 0;
    final authService =
        AuthService(
            apiClient: ApiClient(
              httpClient: MockClient((request) async {
                expect(request.url.path, '/api/mobile/rider/dashboard');
                dashboardRequests++;
                final assignedDeliveries = dashboardRequests == 1 ? 1 : 0;
                return http.Response(
                  jsonEncode({
                    'rider': {
                      'name': 'Test Rider',
                      'work_type': 'local',
                      'capabilities': {
                        'local_pickup': true,
                        'local_delivery': true,
                      },
                      'vehicle_type': 'Motorcycle',
                      'plate_number': 'TEST-1',
                      'availability_status': 'available',
                      'logistics_provider': 'Test Logistics',
                    },
                    'metrics': {
                      'assigned_pickups': 0,
                      'pickup_in_progress': 0,
                      'assigned_deliveries': assignedDeliveries,
                      'out_for_delivery': assignedDeliveries,
                    },
                  }),
                  200,
                );
              }),
              baseUri: Uri.parse('http://127.0.0.1:8000'),
            ),
            tokenStore: _MemoryTokenStore()..token = 'test-token',
          )
          ..currentSession = const AuthSession(
            id: 18,
            name: 'Test Rider',
            email: 'rider@example.test',
            role: AccountRole.rider,
          );
    final repository = RiderRepository(authService: authService);

    await tester.pumpWidget(
      MaterialApp(
        home: RiderHomePage(repository: repository),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouteNames.riderTransit) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Return to dashboard'),
                  ),
                ),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delivery assignments'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final deliveryCard = find.ancestor(
      of: find.text('Delivery assignments'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: deliveryCard, matching: find.text('1 assigned')),
      findsOneWidget,
    );

    await tester.tap(find.text('Deliveries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to dashboard'));
    await tester.pumpAndSettle();

    expect(dashboardRequests, 2);
    await tester.scrollUntilVisible(
      find.text('Delivery assignments'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: deliveryCard, matching: find.text('0 assigned')),
      findsOneWidget,
    );
  });
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
