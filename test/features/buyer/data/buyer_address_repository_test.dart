import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_address_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BuyerAddressRepository', () {
    test(
      'parses an empty address list and exact response key casing',
      () async {
        final repository = _repository(
          (_) async => _jsonResponse({'data': []}),
        );

        expect(await repository.fetchAddresses(), isEmpty);
      },
    );

    test('parses saved address fields and nullable coordinates', () async {
      final repository = _repository(
        (_) async => _jsonResponse({
          'data': [_address()],
        }),
      );

      final addresses = await repository.fetchAddresses();
      final address = addresses.single;

      expect(address.id, 23);
      expect(address.label, 'Home');
      expect(address.name, 'Bea Buyer');
      expect(address.phone, '+639171234567');
      expect(address.province, 'Laguna');
      expect(address.city, 'Santa Rosa');
      expect(address.barangay, 'Balibago');
      expect(address.postal, '4026');
      expect(address.street, 'Maple Street');
      expect(address.isDefault, isTrue);
      expect(address.latitude, 14.3121);
      expect(address.longitude, 121.1115);
      expect(
        () => BuyerAddress.fromJson(_address()..remove('isDefault')),
        throwsA(isA<BuyerShoppingFormatException>()),
      );
    });

    test(
      'creates with Laravel write names and no ownership or price fields',
      () async {
        late http.Request request;
        final repository = _repository((incoming) async {
          request = incoming;
          return _jsonResponse({'data': _address()});
        });

        final created = await repository.createAddress(
          const BuyerAddressCreate(
            name: 'Bea Buyer',
            phone: '+639171234567',
            province: 'Laguna',
            city: 'Santa Rosa',
            barangay: 'Balibago',
            postal: '4026',
            street: 'Maple Street',
            label: 'Home',
            cityCode: '0434240000',
            isDefault: false,
            latitude: 14.3121,
            longitude: 121.1115,
          ),
        );

        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/buyer/addresses');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'name': 'Bea Buyer',
          'phone': '+639171234567',
          'province': 'Laguna',
          'city': 'Santa Rosa',
          'barangay': 'Balibago',
          'postal': '4026',
          'street': 'Maple Street',
          'label': 'Home',
          'city_code': '0434240000',
          'is_default': false,
          'latitude': 14.3121,
          'longitude': 121.1115,
        });
        expect(body.containsKey('isDefault'), isFalse);
        expect(body.containsKey('user_id'), isFalse);
        expect(body.containsKey('product_id'), isFalse);
        expect(created.id, 23);
      },
    );

    test(
      'partial PATCH sends only supplied fields including explicit nulls',
      () async {
        late http.Request request;
        final repository = _repository((incoming) async {
          request = incoming;
          return _jsonResponse({'data': _address()});
        });

        await repository.updateAddress(
          addressId: 23,
          changes: BuyerAddressPatch({
            'street': 'Updated Street',
            'is_default': false,
            'latitude': null,
            'longitude': null,
          }),
        );

        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/mobile/buyer/addresses/23');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'street': 'Updated Street',
          'is_default': false,
          'latitude': null,
          'longitude': null,
        });
        expect(body.containsKey('name'), isFalse);
        expect(body.containsKey('phone'), isFalse);
        expect(body.containsKey('isDefault'), isFalse);
        expect(body.containsKey('user_id'), isFalse);
        expect(
          () => BuyerAddressPatch({'user_id': 5}),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => BuyerAddressPatch({'isDefault': true}),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('sets the default through the dedicated PATCH endpoint', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _jsonResponse({'data': _address()});
      });

      final address = await repository.setDefaultAddress(23);

      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/mobile/buyer/addresses/23/default');
      expect(request.body, isEmpty);
      expect(address.isDefault, isTrue);
    });

    test('treats Laravel data:null delete response as successful', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _jsonResponse({
          'data': null,
          'message': 'Address deleted successfully.',
        });
      });

      await expectLater(repository.deleteAddress(23), completes);

      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/mobile/buyer/addresses/23');
      expect(request.body, isEmpty);
    });

    test('preserves field validation errors and malformed responses', () async {
      final invalidRepository = _repository(
        (_) async => _jsonResponse({
          'message': 'The given data was invalid.',
          'errors': {
            'contact_number': ['The phone number is invalid.'],
          },
        }, 422),
      );
      await expectLater(
        invalidRepository.createAddress(_createAddress()),
        throwsA(
          isA<ApiHttpException>().having(
            (error) => error.validationErrors['contact_number'],
            'contact number errors',
            ['The phone number is invalid.'],
          ),
        ),
      );

      final malformedRepository = _repository(
        (_) async => _jsonResponse({'message': 'Successful but missing data.'}),
      );
      await expectLater(
        malformedRepository.fetchAddresses(),
        throwsA(isA<BuyerShoppingFormatException>()),
      );
    });
  });
}

BuyerAddressCreate _createAddress() => const BuyerAddressCreate(
  name: 'Bea Buyer',
  phone: '+639171234567',
  province: 'Laguna',
  city: 'Santa Rosa',
  barangay: 'Balibago',
  postal: '4026',
  street: 'Maple Street',
  label: 'Home',
);

Map<String, Object?> _address() => {
  'id': 23,
  'label': 'Home',
  'name': 'Bea Buyer',
  'phone': '+639171234567',
  'province': 'Laguna',
  'city': 'Santa Rosa',
  'barangay': 'Balibago',
  'postal': '4026',
  'street': 'Maple Street',
  'isDefault': true,
  'latitude': 14.3121,
  'longitude': 121.1115,
};

BuyerAddressRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerAddressRepository(
  authService: AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: MemoryTokenStore()..token = 'test-session-token',
  ),
);

http.Response _jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response(jsonEncode(value), statusCode);

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
