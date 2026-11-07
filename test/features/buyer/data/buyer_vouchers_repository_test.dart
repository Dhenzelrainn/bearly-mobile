import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_vouchers_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_voucher_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'loads the authenticated wallet and parses category/status data',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _json(_wallet());
      });

      final wallet = await repository.getWallet();

      expect(request.method, 'GET');
      expect(request.url.path, '/api/mobile/buyer/vouchers');
      expect(request.headers['authorization'], 'Bearer voucher-session-token');
      expect(wallet.claimedCount, 1);
      expect(wallet.platform.single.canClaim, isTrue);
      expect(wallet.store.single.isClaimed, isTrue);
      expect(wallet.categories.single.key, 'discount');
      expect(wallet.available, hasLength(1));
      expect(wallet.claimed, hasLength(1));
    },
  );

  test('claims a normalized voucher code using the Buyer API', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return _json({'data': _voucher(id: 41, canClaim: true)});
    });

    final claimed = await repository.claim(code: '  bear-10  ');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/mobile/buyer/vouchers/claim');
    expect(jsonDecode(request.body), {'code': 'BEAR-10'});
    expect(claimed.source, 'platform');
    expect(claimed.id, 41);
  });

  test(
    'rejects wrong role and ambiguous claim inputs before sending',
    () async {
      var requests = 0;
      final auth = _auth((_) async {
        requests++;
        return _json(_wallet());
      }, role: AccountRole.rider);
      final repository = BuyerVouchersRepository(authService: auth);

      await expectLater(repository.getWallet(), throwsFormatException);
      expect(requests, 0);

      final buyerRepository = _repository((_) async {
        requests++;
        return _json(_wallet());
      });
      await expectLater(
        buyerRepository.claim(platformPromotionId: 41, code: 'BEAR-10'),
        throwsArgumentError,
      );
      expect(requests, 0);
    },
  );

  test('rejects malformed voucher responses', () async {
    final repository = _repository(
      (_) async => _json({
        'data': {'platform': [], 'store': []},
      }),
    );
    await expectLater(
      repository.getWallet(),
      throwsA(isA<BuyerVoucherFormatException>()),
    );
  });
}

BuyerVouchersRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerVouchersRepository(authService: _auth(handler));

AuthService _auth(
  Future<http.Response> Function(http.Request) handler, {
  AccountRole role = AccountRole.buyer,
}) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('https://api.example.test'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'voucher-session-token',
      )
      ..currentSession = AuthSession(
        id: 17,
        name: 'Buyer Example',
        email: 'buyer@example.test',
        role: role,
      );

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _wallet() => {
  'data': {
    'claimed_count': 1,
    'categories': [
      {'key': 'discount', 'label': 'Item discounts'},
    ],
    'platform': [_voucher(id: 41, canClaim: true)],
    'store': [_voucher(id: 52, source: 'store', claimed: true)],
  },
};

Map<String, Object?> _voucher({
  required int id,
  String source = 'platform',
  bool claimed = false,
  bool canClaim = false,
}) => {
  'source': source,
  'id': id,
  'name': 'Bearly Voucher $id',
  'title': 'Voucher discount',
  'value_label': '₱5.00',
  'min_spend_minor': 1000,
  'expires_at': '2026-12-01T23:59:59+08:00',
  'section': source == 'store' ? 'shop' : 'discount',
  'claimed': claimed,
  'can_claim': canClaim,
  'can_use': true,
  'availability_status': 'active',
  'availability_reason': null,
  'description': 'For eligible items.',
  'terms': 'Existing Bearly rules apply.',
  'code': null,
  'funding_type': source == 'store' ? 'seller' : 'platform',
};

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
