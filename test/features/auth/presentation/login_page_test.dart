import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/auth/presentation/login_page.dart';
import 'package:bearly_mobile/features/auth/widgets/role_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows three selectable roles and the L1 login subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          authService: _authService((_) async => http.Response('{}', 401)),
        ),
      ),
    );

    expect(find.text('Sign in to your Bearly account.'), findsOneWidget);
    expect(find.text('Buyer'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Logistics'), findsOneWidget);
    expect(
      tester
          .widget<RoleCard>(find.byKey(const ValueKey('login-role-buyer')))
          .selected,
      isTrue,
    );

    await tester.tap(find.text('Logistics'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<RoleCard>(find.byKey(const ValueKey('login-role-logistics')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<RoleCard>(find.byKey(const ValueKey('login-role-buyer')))
          .selected,
      isFalse,
    );
  });

  testWidgets('eligible Logistics login follows the server-verified role', (
    tester,
  ) async {
    late http.Request loginRequest;
    final authService = _authService((request) async {
      if (request.url.path == '/api/mobile/login') {
        loginRequest = request;
        return http.Response(
          jsonEncode({
            'token': 'logistics-session-token',
            'user': {
              'id': 19,
              'name': 'Logistics Operator',
              'email': 'operator@example.test',
              'role': 'logistics',
              'status': 'active',
            },
          }),
          200,
        );
      }
      return http.Response('', 204);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(authService: authService),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Text(
              settings.name == AppRouteNames.logisticsDashboard
                  ? 'Logistics dashboard reached'
                  : 'Wrong destination',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Logistics'));
    await tester.pumpAndSettle();
    await _fillAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(jsonDecode(loginRequest.body)['role'], 'logistics');
    expect(find.text('Logistics dashboard reached'), findsOneWidget);
    expect(authService.currentSession?.role, AccountRole.logistics);
  });

  for (final role in [AccountRole.buyer, AccountRole.rider]) {
    testWidgets('${role.label} sign-in still routes to its own destination', (
      tester,
    ) async {
      late http.Request loginRequest;
      final authService = _authService((request) async {
        if (request.url.path == '/api/mobile/login') {
          loginRequest = request;
          return http.Response(
            jsonEncode({
              'token': '${role.apiValue}-token',
              'user': {
                'id': 30,
                'name': '${role.label} Account',
                'email': '${role.apiValue}@example.test',
                'role': role.apiValue,
                'status': 'active',
              },
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(authService: authService),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('${role.label} home')),
          ),
        ),
      );

      if (role != AccountRole.buyer) {
        await tester.tap(find.text(role.label));
        await tester.pumpAndSettle();
      }
      await _fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(jsonDecode(loginRequest.body)['role'], role.apiValue);
      expect(find.text('${role.label} home'), findsOneWidget);
      expect(authService.currentSession?.role, role);
    });
  }
}

AuthService _authService(
  Future<http.Response> Function(http.Request) handler,
) => AuthService(
  apiClient: ApiClient(
    httpClient: MockClient(handler),
    baseUri: Uri.parse('http://127.0.0.1:8000'),
  ),
  tokenStore: _MemoryTokenStore(),
);

Future<void> _fillAndSubmit(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'operator@example.test');
  await tester.enterText(fields.at(1), 'password');
  final signIn = find.text('Sign In');
  await tester.ensureVisible(signIn);
  await tester.pumpAndSettle();
  await tester.tap(signIn);
  await tester.pump();
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
