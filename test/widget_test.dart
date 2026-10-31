// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bearly_mobile/main.dart';

void main() {
  testWidgets('login is the initial screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      BearlyApp(authService: AuthService(tokenStore: _MemoryTokenStore())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back to Bearly'), findsOneWidget);
    expect(find.text('Continue as'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets(
    'selected Rider role opens the Rider dashboard after successful login',
    (WidgetTester tester) async {
      final service = AuthService(
        apiClient: ApiClient(
          httpClient: MockClient((request) async {
            if (request.url.path == '/api/mobile/login') {
              return http.Response(
                jsonEncode({
                  'token_type': 'Bearer',
                  'token': 'rider-token',
                  'user': {
                    'id': 27,
                    'name': 'Rory Rider',
                    'email': 'rory@example.test',
                    'role': 'rider',
                    'status': 'active',
                  },
                }),
                200,
              );
            }

            expect(request.url.path, '/api/mobile/rider/dashboard');
            expect(request.headers['authorization'], 'Bearer rider-token');
            return http.Response(
              jsonEncode({
                'rider': {
                  'name': 'Rory Rider',
                  'vehicle_type': 'Motorcycle',
                  'plate_number': 'TEST-27',
                  'availability_status': 'available',
                  'logistics_provider': 'Test Logistics',
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
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
        tokenStore: _MemoryTokenStore(),
      );

      await tester.pumpWidget(BearlyApp(authService: service));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login-role-rider')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'rory@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.ensureVisible(find.text('Sign In'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Rory Rider'), findsOneWidget);
      expect(service.currentSession?.role.name, 'rider');
    },
  );
}

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
