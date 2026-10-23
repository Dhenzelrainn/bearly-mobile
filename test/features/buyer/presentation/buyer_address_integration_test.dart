import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_address_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_address_repository.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_location_repository.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_addresses_page.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_address_form_page.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Buyer address integration', () {
    testWidgets('loads authoritative addresses and sets one default by ID', (
      tester,
    ) async {
      final harness = _AddressHarness(
        addresses: [
          _address(31, isDefault: true),
          _address(44, name: 'Second Recipient'),
        ],
      );
      await _pumpAddresses(tester, harness);

      expect(find.text('Bea Buyer'), findsOneWidget);
      expect(find.text('+639171234567'), findsNWidgets(2));
      expect(find.text('Home'), findsNWidgets(2));
      expect(find.text('Maple Street'), findsNWidgets(2));
      expect(find.text('Balibago, Santa Rosa'), findsNWidgets(2));
      expect(find.text('Laguna 4026'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('buyer-address-default-31')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('buyer-address-menu-44')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as default'));
      await tester.pumpAndSettle();

      expect(
        harness.requests.any(
          (request) =>
              request.method == 'PATCH' &&
              request.url.path == '/api/mobile/buyer/addresses/44/default',
        ),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('buyer-address-default-31')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('buyer-address-default-44')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('buyer-address-default-31')).evaluate(),
        isEmpty,
      );
      expect(
        harness.requests.any(
          (request) => request.url.path.contains('checkout'),
        ),
        isFalse,
      );
    });

    testWidgets('empty list and retry state never show demo addresses', (
      tester,
    ) async {
      final harness = _AddressHarness(
        failAddressFetches: 1,
        addresses: const [],
      );
      await _pumpAddresses(tester, harness);

      expect(find.byKey(const ValueKey('buyer-address-retry')), findsOneWidget);
      expect(find.text('Maple Street'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('buyer-address-retry')));
      await tester.pumpAndSettle();
      expect(find.text('No saved delivery addresses'), findsOneWidget);
    });

    testWidgets('creates with Laravel fields and PSGC returned codes', (
      tester,
    ) async {
      final harness = _AddressHarness(addresses: const []);
      await _pumpAddresses(tester, harness);
      expect(harness.controller.isLoading, isFalse);
      expect(harness.controller.isMutating, isFalse);
      expect(harness.controller.addresses, isEmpty);
      expect(
        tester
            .widget<FloatingActionButton>(
              find.byKey(const ValueKey('buyer-address-add')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('buyer-address-add')));
      await tester.pumpAndSettle();
      expect(find.byType(BuyerAddressFormPage), findsOneWidget);
      expect(find.byKey(const ValueKey('buyer-address-name')), findsOneWidget);

      await _enter(tester, 'buyer-address-name', 'Bea New');
      await _enter(tester, 'buyer-address-phone', '+63 917 123 4567');
      await _choose(tester, 'buyer-address-province', 'Laguna');
      await _choose(tester, 'buyer-address-city', 'Santa Rosa');
      await _choose(tester, 'buyer-address-barangay', 'Balibago');
      await _enter(tester, 'buyer-address-street', 'Pine Road');
      await _enter(tester, 'buyer-address-postal', '4026');
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-address-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-address-submit')));
      await tester.pumpAndSettle();

      final create = harness.requests.singleWhere(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/mobile/buyer/addresses',
      );
      final body = jsonDecode(create.body) as Map<String, dynamic>;
      expect(body, {
        'name': 'Bea New',
        'phone': '+63 917 123 4567',
        'province': 'Laguna',
        'city': 'Santa Rosa',
        'barangay': 'Balibago',
        'postal': '4026',
        'street': 'Pine Road',
        'label': 'Home',
        'city_code': '0434240000',
      });
      expect(body.containsKey('user_id'), isFalse);
      expect(body.containsKey('is_default'), isFalse);
      expect(find.text('Bea New'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buyer-address-default-1')),
        findsOneWidget,
      );
      expect(
        harness.requests.where(
          (request) => request.url.path.startsWith('/api/psgc/'),
        ),
        hasLength(3),
      );
    });

    testWidgets('edit preserves values and PATCH sends only changed fields', (
      tester,
    ) async {
      final harness = _AddressHarness(
        addresses: [_address(57, isDefault: true)],
      );
      await _pumpAddresses(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-address-menu-57')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(
        _field(tester, 'buyer-address-name').controller?.text,
        'Bea Buyer',
      );
      expect(
        _field(tester, 'buyer-address-phone').controller?.text,
        '+639171234567',
      );
      expect(
        _field(tester, 'buyer-address-street').controller?.text,
        'Maple Street',
      );
      await _enter(tester, 'buyer-address-street', 'Oak Avenue');
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-address-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-address-submit')));
      await tester.pumpAndSettle();

      final patch = harness.requests.singleWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.url.path == '/api/mobile/buyer/addresses/57',
      );
      expect(jsonDecode(patch.body), {'street': 'Oak Avenue'});
      expect(find.text('Oak Avenue'), findsOneWidget);
    });

    testWidgets('Laravel validation errors remain on fields and keep input', (
      tester,
    ) async {
      final harness = _AddressHarness(addresses: const [], failCreate: true);
      await _pumpAddresses(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-address-add')));
      await tester.pumpAndSettle();

      await _enter(tester, 'buyer-address-name', 'Bea New');
      await _enter(tester, 'buyer-address-phone', '123456789');
      await _choose(tester, 'buyer-address-province', 'Laguna');
      await _choose(tester, 'buyer-address-city', 'Santa Rosa');
      await _choose(tester, 'buyer-address-barangay', 'Balibago');
      await _enter(tester, 'buyer-address-street', 'Pine Road');
      await _enter(tester, 'buyer-address-postal', '4026');
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-address-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-address-submit')));
      await tester.pumpAndSettle();

      expect(
        harness.requests.any((request) => request.method == 'POST'),
        isTrue,
      );
      await tester.drag(
        find.byKey(const ValueKey('buyer-address-form-scroll')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Use an international format.'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('buyer-address-form-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('This postal code is unavailable.'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('buyer-address-form-scroll')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      expect(_field(tester, 'buyer-address-name').controller?.text, 'Bea New');
      expect(find.byType(BuyerAddressFormPage), findsOneWidget);
    });

    testWidgets('failed delete keeps the confirmed address visible', (
      tester,
    ) async {
      final harness = _AddressHarness(
        addresses: [_address(62)],
        failDelete: true,
      );
      await _pumpAddresses(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-address-menu-62')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-address-delete-confirm-62')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('buyer-address-62')), findsOneWidget);
      expect(
        harness.requests.any(
          (request) =>
              request.method == 'DELETE' &&
              request.url.path == '/api/mobile/buyer/addresses/62',
        ),
        isTrue,
      );
    });

    testWidgets('deleting the default shows Laravel-promoted default', (
      tester,
    ) async {
      final harness = _AddressHarness(
        addresses: [
          _address(80, isDefault: true),
          _address(81, name: 'Promoted Recipient'),
        ],
      );
      await _pumpAddresses(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-address-menu-80')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buyer-address-delete-confirm-80')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('buyer-address-80')), findsNothing);
      expect(
        find.byKey(const ValueKey('buyer-address-default-81')),
        findsOneWidget,
      );
      expect(
        harness.requests.any(
          (request) =>
              request.method == 'DELETE' &&
              request.url.path == '/api/mobile/buyer/addresses/80',
        ),
        isTrue,
      );
    });

    testWidgets('province and city changes reset dependent location choices', (
      tester,
    ) async {
      final harness = _AddressHarness(addresses: const []);
      await _pumpAddresses(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-address-add')));
      await tester.pumpAndSettle();
      await _choose(tester, 'buyer-address-province', 'Laguna');
      await _choose(tester, 'buyer-address-city', 'Santa Rosa');
      await _choose(tester, 'buyer-address-barangay', 'Balibago');

      await _choose(tester, 'buyer-address-city', 'Biñan');
      await tester.pumpAndSettle();
      var barangay = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('buyer-address-barangay')),
      );
      expect(barangay.initialValue, isNull);

      await _choose(tester, 'buyer-address-barangay', 'Balibago');
      await _choose(tester, 'buyer-address-province', 'Batangas');
      await tester.pumpAndSettle();
      final city = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('buyer-address-city')),
      );
      barangay = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('buyer-address-barangay')),
      );
      expect(city.initialValue, isNull);
      expect(barangay.initialValue, isNull);
      expect(
        harness.requests.any(
          (request) =>
              request.url.path == '/api/psgc/provinces/041000000/cities',
        ),
        isTrue,
      );
    });

    testWidgets('late postal results from an old location are ignored', (
      tester,
    ) async {
      final harness = _AddressHarness(
        addresses: const [],
        delayPostalLookup: true,
      );
      await _pumpAddresses(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-address-add')));
      await tester.pumpAndSettle();
      await _choose(tester, 'buyer-address-province', 'Laguna');

      await tester.tap(find.byKey(const ValueKey('buyer-address-city')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Santa Rosa').last);
      await tester.pump();
      expect(harness.delayedPostalLookup?.isCompleted, isFalse);

      await tester.tap(find.byKey(const ValueKey('buyer-address-province')));
      await tester.pump();
      await tester.tap(find.text('Batangas').last);
      await tester.pump();
      harness.completeDelayedPostalLookup();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('buyer-postal-option-4026')),
        findsNothing,
      );
    });

    testWidgets('Buyer Account opens the functional address list', (
      tester,
    ) async {
      final harness = _AddressHarness(addresses: [_address(90)]);
      await tester.pumpWidget(
        MaterialApp(
          home: BuyerHomePage(
            authService: harness.auth,
            cartController: BuyerCartController(authService: harness.auth),
            wishlistController: BuyerWishlistController(
              authService: harness.auth,
            ),
            locationRepository: harness.locationRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery addresses'));
      await tester.pumpAndSettle();

      expect(find.text('Delivery addresses'), findsOneWidget);
      expect(find.byKey(const ValueKey('buyer-address-90')), findsOneWidget);
    });

    testWidgets('postal lookup failure still allows manual valid entry', (
      tester,
    ) async {
      final harness = _AddressHarness(
        addresses: const [],
        failPostalLookup: true,
      );
      await _pumpAddresses(tester, harness);
      await tester.tap(find.byKey(const ValueKey('buyer-address-add')));
      await tester.pumpAndSettle();
      await _enter(tester, 'buyer-address-name', 'Bea New');
      await _enter(tester, 'buyer-address-phone', '+639171234567');
      await _choose(tester, 'buyer-address-province', 'Laguna');
      await _choose(tester, 'buyer-address-city', 'Santa Rosa');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Postal lookup is unavailable'),
        findsOneWidget,
      );
      await _choose(tester, 'buyer-address-barangay', 'Balibago');
      await _enter(tester, 'buyer-address-street', 'Pine Road');
      await _enter(tester, 'buyer-address-postal', '4026');
      await tester.ensureVisible(
        find.byKey(const ValueKey('buyer-address-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('buyer-address-submit')));
      await tester.pumpAndSettle();
      expect(
        harness.requests.any((request) => request.method == 'POST'),
        isTrue,
      );
    });

    test('account changes clear previous address state', () async {
      final harness = _AddressHarness(addresses: [_address(71)]);
      await harness.controller.refresh(force: true);
      expect(harness.controller.addresses!.single.id, 71);

      harness.auth.currentSession = _buyerSession(2);
      expect(harness.controller.synchronizeSession(), isTrue);
      expect(harness.controller.addresses, isNull);
      expect(harness.controller.loadError, isNull);

      await harness.controller.refresh(force: true);
      expect(harness.controller.addresses, isNotNull);
      harness.controller.clear();
      expect(harness.controller.addresses, isNull);
    });
  });
}

Future<void> _pumpAddresses(
  WidgetTester tester,
  _AddressHarness harness,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BuyerAddressesPage(
        controller: harness.controller,
        locationRepository: harness.locationRepository,
        onSignInAgain: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

TextFormField _field(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key)));

Map<String, Object?> _address(
  int id, {
  String name = 'Bea Buyer',
  bool isDefault = false,
  String street = 'Maple Street',
}) => {
  'id': id,
  'label': 'Home',
  'name': name,
  'phone': '+639171234567',
  'province': 'Laguna',
  'city': 'Santa Rosa',
  'barangay': 'Balibago',
  'postal': '4026',
  'street': street,
  'isDefault': isDefault,
  'latitude': null,
  'longitude': null,
};

http.Response _json(Object? data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

class _AddressHarness {
  _AddressHarness({
    required List<Map<String, Object?>> addresses,
    this.failAddressFetches = 0,
    this.failCreate = false,
    this.failDelete = false,
    this.failPostalLookup = false,
    this.delayPostalLookup = false,
  }) : addresses = addresses
           .map((value) => Map<String, Object?>.of(value))
           .toList() {
    apiClient = ApiClient(
      httpClient: MockClient(_handle),
      baseUri: Uri.parse('https://api.example.test'),
    );
    auth = AuthService(apiClient: apiClient, tokenStore: _MemoryTokenStore());
    auth.currentSession = _buyerSession(1);
    controller = BuyerAddressController(
      authService: auth,
      repository: BuyerAddressRepository(authService: auth),
    );
    locationRepository = BuyerLocationRepository(apiClient: apiClient);
  }

  final List<Map<String, Object?>> addresses;
  final List<http.Request> requests = [];
  int failAddressFetches;
  final bool failCreate;
  final bool failDelete;
  final bool failPostalLookup;
  final bool delayPostalLookup;
  late final ApiClient apiClient;
  late final AuthService auth;
  late final BuyerAddressController controller;
  late final BuyerLocationRepository locationRepository;
  int _nextId = 1;
  Completer<http.Response>? delayedPostalLookup;

  void completeDelayedPostalLookup() {
    delayedPostalLookup?.complete(
      _json({
        'options': [
          {'area': 'Old city', 'code': '4026'},
        ],
      }),
    );
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/mobile/buyer/addresses') {
      if (failAddressFetches > 0) {
        failAddressFetches--;
        return _json({'message': 'Unavailable'}, 503);
      }
      return _json({'data': addresses, 'message': 'Addresses retrieved.'});
    }
    if (request.method == 'POST' && path == '/api/mobile/buyer/addresses') {
      if (failCreate) {
        return _json({
          'message': 'Invalid address',
          'errors': {
            'phone': ['Use an international format.'],
            'postal': ['This postal code is unavailable.'],
          },
        }, 422);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final isDefault = addresses.isEmpty || body['is_default'] == true;
      if (isDefault) {
        for (final address in addresses) {
          address['isDefault'] = false;
        }
      }
      final saved = <String, Object?>{
        ...body,
        'id': _nextId++,
        'isDefault': isDefault,
        'latitude': body['latitude'],
        'longitude': body['longitude'],
      };
      saved.remove('city_code');
      saved.remove('is_default');
      addresses.add(saved);
      return _json({'data': saved, 'message': 'Address added.'}, 201);
    }
    if (request.method == 'PATCH' && path.endsWith('/default')) {
      final id = int.parse(
        path.split('/').elementAt(path.split('/').length - 2),
      );
      for (final address in addresses) {
        address['isDefault'] = address['id'] == id;
      }
      final selected = addresses.singleWhere((address) => address['id'] == id);
      return _json({'data': selected, 'message': 'Default updated.'});
    }
    if (request.method == 'PATCH' &&
        path.startsWith('/api/mobile/buyer/addresses/')) {
      final id = int.parse(path.split('/').last);
      final selected = addresses.singleWhere((address) => address['id'] == id);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      selected.addAll(body);
      return _json({'data': selected, 'message': 'Address updated.'});
    }
    if (request.method == 'DELETE' &&
        path.startsWith('/api/mobile/buyer/addresses/')) {
      if (failDelete) return _json({'message': 'Missing'}, 404);
      final id = int.parse(path.split('/').last);
      final index = addresses.indexWhere((address) => address['id'] == id);
      if (index >= 0) {
        final wasDefault = addresses[index]['isDefault'] == true;
        addresses.removeAt(index);
        if (wasDefault && addresses.isNotEmpty) {
          addresses.first['isDefault'] = true;
        }
      }
      return _json({'data': null, 'message': 'Address deleted.'});
    }
    if (request.method == 'GET' && path == '/api/psgc/provinces') {
      return _json([
        {'code': '043400000', 'name': 'Laguna'},
        {'code': '041000000', 'name': 'Batangas'},
      ]);
    }
    if (request.method == 'GET' && path.endsWith('/cities')) {
      final data = path.contains('043400000')
          ? [
              {'code': '0434240000', 'name': 'Santa Rosa'},
              {'code': '0434030000', 'name': 'Biñan'},
            ]
          : [
              {'code': '0410001000', 'name': 'Tanauan'},
            ];
      return _json({'data': data});
    }
    if (request.method == 'GET' && path.endsWith('/barangays')) {
      return _json({
        'data': [
          {'code': '0434240011', 'name': 'Balibago'},
          {'code': '0434240012', 'name': 'Dila'},
        ],
      });
    }
    if (request.method == 'GET' && path == '/api/postal-codes') {
      if (failPostalLookup) return _json({'message': 'Unavailable'}, 503);
      if (delayPostalLookup) {
        delayedPostalLookup = Completer<http.Response>();
        return delayedPostalLookup!.future;
      }
      return _json({
        'options': [
          {'area': 'Santa Rosa', 'code': '4026'},
        ],
      });
    }
    return _json({'message': 'Unexpected mocked request: $path'}, 500);
  }
}

AuthSession _buyerSession(int id) => AuthSession(
  id: id,
  name: 'Buyer $id',
  email: 'buyer$id@example.test',
  role: AccountRole.buyer,
);

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'mock-token';

  @override
  Future<void> write(String token) async {}
}
