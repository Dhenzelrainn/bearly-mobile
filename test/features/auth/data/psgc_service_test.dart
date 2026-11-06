import 'dart:convert';

import 'package:bearly_mobile/features/auth/data/psgc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PsgcService registration regions', () {
    test(
      'loads regions and then provinces from the selected region code',
      () async {
        final requests = <Uri>[];
        final service = PsgcService(
          client: MockClient((request) async {
            requests.add(request.url);
            if (request.url.path == '/api/v2/regions') {
              return http.Response(
                jsonEncode([
                  {'name': 'Calabarzon', 'code': '0400000000'},
                  {'name': 'Invalid code', 'code': '040000000'},
                ]),
                200,
              );
            }
            if (request.url.path == '/api/v2/regions/0400000000/provinces') {
              return http.Response(
                jsonEncode([
                  {'name': 'Laguna', 'code': '0434000000'},
                ]),
                200,
              );
            }

            return http.Response('Unexpected path', 404);
          }),
        );

        final regions = await service.regions();
        final provinces = await service.provincesForRegion(regions.single.code);

        expect(regions.map((region) => region.name), ['Calabarzon']);
        expect(regions.single.code, '0400000000');
        expect(provinces.single.name, 'Laguna');
        expect(requests.map((uri) => uri.path), [
          '/api/v2/regions',
          '/api/v2/regions/0400000000/provinces',
        ]);
      },
    );

    test('does not request provinces with an invalid region code', () async {
      var requested = false;
      final service = PsgcService(
        client: MockClient((_) async {
          requested = true;
          return http.Response('[]', 200);
        }),
      );

      expect(
        () => service.provincesForRegion('040000000'),
        throwsA(isA<PsgcException>()),
      );
      expect(requested, isFalse);
    });
  });
}
