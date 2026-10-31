import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/presentation/session_startup_page.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('restored Logistics session routes to its dashboard', (
    tester,
  ) async {
    final store = _MemoryTokenStore()..token = 'saved-logistics-token';
    final auth = AuthService(
      apiClient: ApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/mobile/me') {
            expect(
              request.headers['authorization'],
              'Bearer saved-logistics-token',
            );
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 19,
                  'name': 'Victoria Operator',
                  'email': 'operator@example.test',
                  'role': 'logistics',
                  'status': 'active',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/api/mobile/logistics/dashboard') {
            return http.Response(
              jsonEncode({
                'data': {
                  'provider': {
                    'id': 3,
                    'name': 'Victoria Logistics',
                    'status': 'active',
                  },
                  'sorting_center': null,
                  'setup_required': true,
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
              }),
              200,
            );
          }
          return http.Response('', 404);
        }),
        baseUri: Uri.parse('http://127.0.0.1:8000'),
      ),
      tokenStore: store,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SessionStartupPage(authService: auth),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouteNames.logisticsDashboard) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => LogisticsHomePage(
                authService: auth,
                repository: LogisticsRepository(authService: auth),
              ),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Wrong destination')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Victoria Logistics'), findsOneWidget);
    expect(find.text('Wrong destination'), findsNothing);
    expect(store.token, 'saved-logistics-token');
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
