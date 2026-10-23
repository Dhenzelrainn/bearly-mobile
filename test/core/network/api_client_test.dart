import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient', () {
    test('joins base paths and safely encodes query parameters', () async {
      late http.Request request;
      final httpClient = MockClient((incoming) async {
        request = incoming;
        return http.Response('{"ok":true}', 200);
      });
      final api = ApiClient(
        httpClient: httpClient,
        baseUri: Uri.parse('https://example.test/api///'),
      );

      await api.get(
        '/catalog/items?fixed=keep&replace=old&multi=one&multi=two',
        queryParameters: {
          'search': 'bearly & fresh',
          'replace': 'new value',
          'multi': ['first', 'second'],
          'omit': null,
        },
      );

      expect(request.url.path, '/api/catalog/items');
      expect(request.url.queryParameters['fixed'], 'keep');
      expect(request.url.queryParameters['search'], 'bearly & fresh');
      expect(request.url.queryParameters['replace'], 'new value');
      expect(request.url.queryParametersAll['multi'], ['first', 'second']);
      expect(request.url.queryParameters.containsKey('omit'), isFalse);
    });

    test('serializes JSON requests and decodes successful JSON responses', () async {
      late http.Request request;
      final httpClient = MockClient((incoming) async {
        request = incoming;
        return http.Response('{"id":7,"name":"Bearly"}', 201);
      });
      final api = ApiClient(httpClient: httpClient);

      final result = await api.post(
        '/items',
        body: {'name': 'Bearly', 'active': true},
      );

      expect(request.method, 'POST');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {'name': 'Bearly', 'active': true});
      expect(result, {'id': 7, 'name': 'Bearly'});
    });

    test('supports all required methods and treats empty success as null', () async {
      final methods = <String>[];
      final httpClient = MockClient((request) async {
        methods.add(request.method);
        return http.Response('', 204);
      });
      final api = ApiClient(httpClient: httpClient);

      expect(await api.get('/items'), isNull);
      expect(await api.post('/items', body: {'name': 'x'}), isNull);
      expect(await api.put('/items/1', body: {'name': 'y'}), isNull);
      expect(await api.patch('/items/1', body: {'name': 'z'}), isNull);
      expect(await api.delete('/items/1'), isNull);
      expect(methods, ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);
    });

    test('maps common Laravel HTTP statuses to structured errors', () async {
      for (final statusCode in [401, 403, 404, 409, 422, 429, 500]) {
        final secret = 'Bearer test-secret-token';
        final httpClient = MockClient((_) async {
          return http.Response(
            jsonEncode({
              'message': secret,
              if (statusCode == 422)
                'errors': {
                  'email': ['The email field is required.'],
                  'profile': {
                    'phone': ['The phone field is invalid.'],
                  },
                },
            }),
            statusCode,
          );
        });
        final api = ApiClient(httpClient: httpClient);

        try {
          await api.get('/private', headers: {'Authorization': secret});
          fail('Expected HTTP $statusCode to produce an API error.');
        } on ApiHttpException catch (error) {
          expect(error.statusCode, statusCode);
          expect(error.toString(), isNot(contains(secret)));
          expect(error.message, isNot(contains(secret)));
          expect(error.responseWasJson, isTrue);
          if (statusCode == 422) {
            expect(error.kind, ApiErrorKind.validation);
            expect(error.validationErrors['email'], ['The email field is required.']);
            expect(error.validationErrors['profile.phone'], [
              'The phone field is invalid.',
            ]);
          }
        }
      }
    });

    test('extracts validation errors from nested Laravel response data', () async {
      final httpClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'data': {
              'errors': {
                'password': ['The password is too short.'],
              },
            },
          }),
          422,
        );
      });
      final api = ApiClient(httpClient: httpClient);

      try {
        await api.post('/register', body: {'password': 'x'});
        fail('Expected a validation error.');
      } on ApiHttpException catch (error) {
        expect(error.validationErrors['password'], ['The password is too short.']);
      }
    });

    test('preserves non-JSON HTTP errors and rejects malformed success JSON', () async {
      final errorClient = MockClient((_) async {
        return http.Response('upstream proxy error', 503);
      });
      final errorApi = ApiClient(httpClient: errorClient);
      await expectLater(
        errorApi.get('/items'),
        throwsA(
          isA<ApiHttpException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.responseWasJson, 'responseWasJson', isFalse),
        ),
      );

      final malformedClient = MockClient((_) async {
        return http.Response('{not-json', 200);
      });
      final malformedApi = ApiClient(httpClient: malformedClient);
      await expectLater(
        malformedApi.get('/items'),
        throwsA(isA<ApiFormatException>().having(
          (error) => error.statusCode,
          'statusCode',
          200,
        )),
      );
    });

    test('distinguishes timeouts from transport failures', () async {
      final slowClient = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });
      final slowApi = ApiClient(
        httpClient: slowClient,
        timeout: const Duration(milliseconds: 1),
      );
      await expectLater(slowApi.get('/slow'), throwsA(isA<ApiTimeoutException>()));

      final failingClient = MockClient((_) async {
        throw http.ClientException('connection failed with Bearer hidden-token');
      });
      final failingApi = ApiClient(httpClient: failingClient);
      try {
        await failingApi.get('/offline');
        fail('Expected a transport error.');
      } on ApiTransportException catch (error) {
        expect(error.toString(), isNot(contains('hidden-token')));
      }
    });
  });
}
