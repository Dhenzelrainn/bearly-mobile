import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AuthService', () {
    test(
      'login sends credentials and stores the Sanctum token securely',
      () async {
        late http.Request request;
        final store = MemoryTokenStore();
        final service = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((incoming) async {
              request = incoming;
              return http.Response(
                jsonEncode({
                  'token_type': 'Bearer',
                  'token': 'issued-token',
                  'user': {
                    'id': 14,
                    'name': 'Bea Buyer',
                    'email': 'bea@example.test',
                    'role': 'buyer',
                    'status': 'active',
                  },
                }),
                200,
              );
            }),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: store,
        );

        final session = await service.login(
          email: ' bea@example.test ',
          password: 'secret-password',
        );

        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/login');
        expect(request.headers['accept'], 'application/json');
        expect(jsonDecode(request.body), {
          'email': 'bea@example.test',
          'password': 'secret-password',
        });
        expect(session.role, AccountRole.buyer);
        expect(session.email, 'bea@example.test');
        expect(store.token, 'issued-token');
        expect(service.currentSession, same(session));
      },
    );

    test(
      'unchecked remember me keeps the token in memory for logout only',
      () async {
        final store = MemoryTokenStore()..token = 'previous-persistent-token';
        String? logoutAuthorization;
        final service = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/mobile/login')) {
                return http.Response(
                  jsonEncode({
                    'token': 'temporary-token',
                    'user': {
                      'id': 15,
                      'name': 'Bea Buyer',
                      'email': 'bea@example.test',
                      'role': 'buyer',
                      'status': 'active',
                    },
                  }),
                  200,
                );
              }
              logoutAuthorization = request.headers['authorization'];
              return http.Response('', 204);
            }),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: store,
        );

        await service.login(
          email: 'bea@example.test',
          password: 'password',
          rememberMe: false,
        );
        expect(store.token, isNull);

        await service.logout();

        expect(logoutAuthorization, 'Bearer temporary-token');
        expect(store.token, isNull);
      },
    );

    test(
      'login rejects an unsupported server role and revokes its token',
      () async {
        final requestedPaths = <String>[];
        final store = MemoryTokenStore();
        final service = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((request) async {
              requestedPaths.add(request.url.path);
              if (request.url.path.endsWith('/mobile/login')) {
                return http.Response(
                  jsonEncode({
                    'token': 'unsupported-token',
                    'user': {
                      'id': 4,
                      'name': 'Seller User',
                      'email': 'seller@example.test',
                      'role': 'seller',
                      'status': 'active',
                    },
                  }),
                  200,
                );
              }
              return http.Response('', 204);
            }),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: store,
        );

        await expectLater(
          service.login(email: 'seller@example.test', password: 'password'),
          throwsA(isA<AuthException>()),
        );

        expect(requestedPaths, ['/api/mobile/login', '/api/mobile/logout']);
        expect(store.token, isNull);
        expect(service.currentSession, isNull);
      },
    );

    test(
      'restore validates the token with /mobile/me and retains the session',
      () async {
        late http.Request request;
        final store = MemoryTokenStore()..token = 'saved-token';
        final service = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((incoming) async {
              request = incoming;
              return http.Response(
                jsonEncode({
                  'user': {
                    'id': 21,
                    'name': 'Rory Rider',
                    'email': 'rory@example.test',
                    'role': 'rider',
                    'status': 'active',
                  },
                }),
                200,
              );
            }),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: store,
        );

        final session = await service.restoreSession();

        expect(request.method, 'GET');
        expect(request.url.path, '/api/mobile/me');
        expect(request.headers['authorization'], 'Bearer saved-token');
        expect(session?.role, AccountRole.rider);
        expect(store.token, 'saved-token');
      },
    );

    test('restore clears an explicitly unauthorized token', () async {
      final store = MemoryTokenStore()..token = 'revoked-token';
      final service = AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(
            (_) async => http.Response('{"message":"Unauthenticated."}', 401),
          ),
          baseUri: Uri.parse('https://api.example.test'),
        ),
        tokenStore: store,
      );

      expect(await service.restoreSession(), isNull);
      expect(store.token, isNull);
      expect(service.currentSession, isNull);
    });

    test(
      'restore retains a token when the server is temporarily unavailable',
      () async {
        final store = MemoryTokenStore()..token = 'valid-but-offline-token';
        final service = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient(
              (_) async => http.Response('{"message":"Unavailable."}', 503),
            ),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: store,
        );

        await expectLater(
          service.restoreSession(),
          throwsA(isA<ApiHttpException>()),
        );
        expect(store.token, 'valid-but-offline-token');
      },
    );

    test(
      'session-aware requests attach the credential for every HTTP verb',
      () async {
        final requests = <http.Request>[];
        final service = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response('{"ok":true}', 200);
            }),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: MemoryTokenStore()..token = 'session-only-token',
        );
        const methods = AuthenticatedRequestMethod.values;

        for (final method in methods) {
          final methodName = method.name;
          final parsed = await service.requestWithSession<Map>(
            method: method,
            path: '/api/mobile/test/$methodName',
            queryParameters: {'method': methodName},
            body: method == AuthenticatedRequestMethod.get
                ? null
                : {'value': methodName},
            parse: (response) => response as Map,
          );
          expect(parsed['ok'], isTrue);
        }

        expect(requests.map((request) => request.method), [
          'GET',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
        ]);
        expect(
          requests.every(
            (request) =>
                request.headers['authorization'] == 'Bearer session-only-token',
          ),
          isTrue,
        );
        expect(requests.first.url.queryParameters, {'method': 'get'});
        expect(
          requests.skip(1).map((request) => jsonDecode(request.body)).toList(),
          [
            {'value': 'post'},
            {'value': 'put'},
            {'value': 'patch'},
            {'value': 'delete'},
          ],
        );
      },
    );

    test(
      'authenticated requests support Remember Me disabled in-memory sessions',
      () async {
        final store = MemoryTokenStore();
        final requests = <http.Request>[];
        final service = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((request) async {
              requests.add(request);
              if (request.url.path == '/api/mobile/login') {
                return http.Response(
                  jsonEncode({
                    'token': 'temporary-session-token',
                    'user': {
                      'id': 31,
                      'name': 'Bea Buyer',
                      'email': 'bea@example.test',
                      'role': 'buyer',
                      'status': 'active',
                    },
                  }),
                  200,
                );
              }
              return http.Response('{"saved":true}', 200);
            }),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: store,
        );
        await service.login(
          email: 'bea@example.test',
          password: 'test-password',
          rememberMe: false,
        );

        final response = await service.requestWithSession<bool>(
          method: AuthenticatedRequestMethod.put,
          path: '/api/mobile/buyer/wishlist/41',
          parse: (value) => (value as Map)['saved'] as bool,
        );

        expect(response, isTrue);
        expect(store.token, isNull);
        expect(
          requests.last.headers['authorization'],
          'Bearer temporary-session-token',
        );
        expect(requests.last.body, isEmpty);
        expect(
          requests.last.toString(),
          isNot(contains('temporary-session-token')),
        );
      },
    );

    test(
      '401 and 403 clear sessions but timeouts and server failures retain them',
      () async {
        for (final statusCode in [401, 403]) {
          final store = MemoryTokenStore()..token = 'session-token';
          final service = AuthService(
            apiClient: ApiClient(
              httpClient: MockClient(
                (_) async =>
                    http.Response('{"message":"Rejected."}', statusCode),
              ),
              baseUri: Uri.parse('https://api.example.test'),
            ),
            tokenStore: store,
          );

          await expectLater(
            service.requestWithSession<void>(
              method: AuthenticatedRequestMethod.delete,
              path: '/api/mobile/buyer/cart/items/71',
              parse: (_) {},
            ),
            throwsA(isA<ApiHttpException>()),
          );
          expect(store.token, isNull);
        }

        final timeoutStore = MemoryTokenStore()..token = 'valid-session-token';
        final timeoutService = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient((_) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return http.Response('{"ok":true}', 200);
            }),
            timeout: const Duration(milliseconds: 1),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: timeoutStore,
        );
        await expectLater(
          timeoutService.requestWithSession<Object?>(
            method: AuthenticatedRequestMethod.patch,
            path: '/api/mobile/buyer/addresses/23',
            body: {'street': 'Private address'},
            parse: (value) => value,
          ),
          throwsA(isA<ApiTimeoutException>()),
        );
        expect(timeoutStore.token, 'valid-session-token');

        final serverStore = MemoryTokenStore()..token = 'valid-session-token';
        final serverService = AuthService(
          apiClient: ApiClient(
            httpClient: MockClient(
              (_) async => http.Response('{"message":"Unavailable."}', 503),
            ),
            baseUri: Uri.parse('https://api.example.test'),
          ),
          tokenStore: serverStore,
        );
        await expectLater(
          serverService.requestWithSession<Object?>(
            method: AuthenticatedRequestMethod.patch,
            path: '/api/mobile/buyer/addresses/23',
            body: {'street': 'Private address'},
            parse: (value) => value,
          ),
          throwsA(isA<ApiHttpException>()),
        );
        expect(serverStore.token, 'valid-session-token');
      },
    );

    test(
      'logout clears local credentials when the server cannot be reached',
      () async {
        final store = MemoryTokenStore()..token = 'offline-logout-token';
        final service =
            AuthService(
                apiClient: ApiClient(
                  httpClient: MockClient((_) async {
                    throw http.ClientException('offline');
                  }),
                  baseUri: Uri.parse('https://api.example.test'),
                ),
                tokenStore: store,
              )
              ..currentSession = const AuthSession(
                id: 1,
                name: 'Buyer',
                email: 'buyer@example.test',
                role: AccountRole.buyer,
              );

        await service.logout();

        expect(store.token, isNull);
        expect(service.currentSession, isNull);
      },
    );
  });
}

class MemoryTokenStore implements SessionTokenStore {
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
