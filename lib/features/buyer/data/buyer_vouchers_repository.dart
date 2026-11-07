import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_voucher_models.dart';

abstract interface class BuyerVouchersDataSource {
  Future<BuyerVoucherWallet> getWallet();

  Future<BuyerVoucher> claim({
    int? platformPromotionId,
    int? storePromotionId,
    String? code,
  });
}

/// Uses the same authenticated Buyer wallet and claim endpoints as the Web.
class BuyerVouchersRepository implements BuyerVouchersDataSource {
  BuyerVouchersRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  @override
  Future<BuyerVoucherWallet> getWallet() async {
    _requireBuyer();
    final response = await _authService.getWithSession(
      '/api/mobile/buyer/vouchers',
    );
    return BuyerVoucherWallet.fromJson(response);
  }

  @override
  Future<BuyerVoucher> claim({
    int? platformPromotionId,
    int? storePromotionId,
    String? code,
  }) async {
    _requireBuyer();
    final normalizedCode = code?.trim().toUpperCase();
    final selected = [
      platformPromotionId != null,
      storePromotionId != null,
      normalizedCode?.isNotEmpty == true,
    ].where((value) => value).length;
    if (selected != 1) {
      throw ArgumentError('Choose one voucher or enter one voucher code.');
    }
    if ((platformPromotionId != null && platformPromotionId < 1) ||
        (storePromotionId != null && storePromotionId < 1)) {
      throw ArgumentError('Voucher IDs must be positive.');
    }
    if (normalizedCode != null &&
        (normalizedCode.length > 40 ||
            !RegExp(r'^[A-Z0-9_-]+$').hasMatch(normalizedCode))) {
      throw ArgumentError.value(code, 'code');
    }

    final response = await _authService.requestWithSession<Object?>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/vouchers/claim',
      body: {
        'platform_promotion_id': ?platformPromotionId,
        'store_promotion_id': ?storePromotionId,
        if (normalizedCode != null && normalizedCode.isNotEmpty)
          'code': normalizedCode,
      },
      parse: (value) => value,
    );
    if (response is! Map || response['data'] is! Map) {
      throw const BuyerVoucherFormatException('claim.data');
    }
    return BuyerVoucher.fromJson(response['data']);
  }

  void _requireBuyer() {
    if (_authService.currentSession?.role != AccountRole.buyer) {
      throw const FormatException(
        'Sign in with a Buyer account to view vouchers.',
      );
    }
  }
}
