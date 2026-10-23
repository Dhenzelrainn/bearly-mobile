import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_location_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BuyerLocationRepository', () {
    test('parses PSGC province identifiers, labels, and metadata', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _jsonResponse([
          {'code': '043400000', 'name': 'Laguna', 'region': 'CALABARZON'},
        ]);
      });

      final provinces = await repository.fetchProvinces();

      expect(request.url.path, '/api/psgc/provinces');
      expect(request.headers['authorization'], isNull);
      expect(provinces.single.code, '043400000');
      expect(provinces.single.name, 'Laguna');
      expect(provinces.single.metadata, {'region': 'CALABARZON'});
    });

    test(
      'loads cities and barangays through selected PSGC parent codes',
      () async {
        final requests = <http.Request>[];
        final repository = _repository((request) async {
          requests.add(request);
          final data = request.url.path.endsWith('/cities')
              ? [
                  {
                    'code': '0434240000',
                    'name': 'City of Santa Rosa',
                    'type': 'City',
                    'province': 'Laguna',
                  },
                ]
              : [
                  {
                    'code': '0434240011',
                    'name': 'Balibago',
                    'status': 'Urban',
                    'city_municipality': 'City of Santa Rosa',
                  },
                ];
          return _jsonResponse({'data': data});
        });

        final cities = await repository.fetchCities('043400000');
        final barangays = await repository.fetchBarangays('0434240000');

        expect(requests.map((request) => request.url.path), [
          '/api/psgc/provinces/043400000/cities',
          '/api/psgc/cities/0434240000/barangays',
        ]);
        expect(cities.single.code, '0434240000');
        expect(cities.single.name, 'City of Santa Rosa');
        expect(cities.single.metadata['type'], 'City');
        expect(barangays.single.code, '0434240011');
        expect(barangays.single.name, 'Balibago');
        expect(
          barangays.single.metadata['city_municipality'],
          'City of Santa Rosa',
        );
      },
    );

    test(
      'queries postal options by city code or province and city names',
      () async {
        final requests = <http.Request>[];
        final repository = _repository((request) async {
          requests.add(request);
          return _jsonResponse({
            'options': [
              {'area': 'Makati Central', 'code': '1200'},
              {'area': 'Poblacion', 'code': '1210'},
            ],
          });
        });

        final byCode = await repository.fetchPostalCodes(
          cityCode: '0434240000',
        );
        final byNames = await repository.fetchPostalCodes(
          province: 'Laguna',
          city: 'Santa Rosa',
        );

        expect(requests[0].url.path, '/api/postal-codes');
        expect(requests[0].url.queryParameters, {'city_code': '0434240000'});
        expect(requests[1].url.queryParameters, {
          'province': 'Laguna',
          'city': 'Santa Rosa',
        });
        expect(byCode.map((option) => option.code), ['1200', '1210']);
        expect(byCode.first.area, 'Makati Central');
        expect(byNames.length, 2);
      },
    );

    test(
      'distinguishes successful empty lookups and resets dependent selections',
      () async {
        final repository = _repository((request) async {
          if (request.url.path == '/api/postal-codes') {
            return _jsonResponse({'options': []});
          }
          return _jsonResponse([]);
        });

        expect(await repository.fetchProvinces(), isEmpty);
        expect(await repository.fetchCities('043400000'), isEmpty);
        expect(await repository.fetchBarangays('0434240000'), isEmpty);
        expect(
          await repository.fetchPostalCodes(cityCode: '0434240000'),
          isEmpty,
        );

        const selection = BuyerLocationSelection(
          provinceCode: '043400000',
          cityCode: '0434240000',
          barangayCode: '0434240011',
        );
        final newProvince = selection.selectProvince('041000000');
        expect(newProvince.provinceCode, '041000000');
        expect(newProvince.cityCode, isNull);
        expect(newProvince.barangayCode, isNull);

        final newCity = selection.selectCity('0410001000');
        expect(newCity.provinceCode, '043400000');
        expect(newCity.cityCode, '0410001000');
        expect(newCity.barangayCode, isNull);
      },
    );

    test(
      'rejects malformed responses and invalid codes without hiding API errors',
      () async {
        var requestCount = 0;
        final invalidCodeRepository = _repository((_) async {
          requestCount++;
          return _jsonResponse([]);
        });
        await expectLater(
          invalidCodeRepository.fetchCities('Laguna'),
          throwsA(isA<ArgumentError>()),
        );
        expect(requestCount, 0);

        final malformedRepository = _repository(
          (_) async => _jsonResponse({'data': 'not-a-list'}),
        );
        await expectLater(
          malformedRepository.fetchProvinces(),
          throwsA(isA<BuyerShoppingFormatException>()),
        );

        final unavailableRepository = _repository(
          (_) async => _jsonResponse({'message': 'Unavailable.'}, 503),
        );
        await expectLater(
          unavailableRepository.fetchBarangays('0434240000'),
          throwsA(
            isA<ApiHttpException>().having(
              (error) => error.statusCode,
              'statusCode',
              503,
            ),
          ),
        );
      },
    );
  });
}

BuyerLocationRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerLocationRepository(
  apiClient: ApiClient(
    httpClient: MockClient(handler),
    baseUri: Uri.parse('https://api.example.test'),
  ),
);

http.Response _jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response(jsonEncode(value), statusCode);
