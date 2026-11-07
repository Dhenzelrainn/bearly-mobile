import 'dart:async';

import 'package:bearly_mobile/features/buyer/data/buyer_vouchers_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_voucher_models.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_vouchers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads wallet, claims by code, and refreshes claimed state', (
    tester,
  ) async {
    final pending = Completer<BuyerVoucherWallet>();
    final repository = _FakeVouchers()..responses.add(pending.future);
    await tester.pumpWidget(
      MaterialApp(home: BuyerVouchersPage(repository: repository)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(_wallet());
    await tester.pumpAndSettle();
    expect(find.text('Wallet Voucher'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('buyer-voucher-claim-code')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('buyer-voucher-claim-11')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('buyer-voucher-code-input')),
      'CODE-5',
    );
    await tester.tap(find.byKey(const ValueKey('buyer-voucher-claim-code')));
    await tester.pumpAndSettle();
    expect(repository.claimedCodes, ['CODE-5']);
    expect(find.text('Voucher added to My Vouchers.'), findsOneWidget);
    expect(find.text('Claimed'), findsNWidgets(2));
    expect(repository.walletCalls, 2);
  });

  testWidgets('shows empty and retryable error states', (tester) async {
    final repository = _FakeVouchers()
      ..errors.add(StateError('offline'))
      ..responses.add(Future.value(_emptyWallet()));
    await tester.pumpWidget(
      MaterialApp(home: BuyerVouchersPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be loaded'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No vouchers in this view'), findsOneWidget);
  });
}

class _FakeVouchers implements BuyerVouchersDataSource {
  final List<Future<BuyerVoucherWallet>> responses = [];
  final List<Object> errors = [];
  final List<String> claimedCodes = [];
  BuyerVoucherWallet wallet = _wallet();
  int walletCalls = 0;

  @override
  Future<BuyerVoucherWallet> getWallet() async {
    walletCalls++;
    if (errors.isNotEmpty) throw errors.removeAt(0);
    if (responses.isNotEmpty) wallet = await responses.removeAt(0);
    return wallet;
  }

  @override
  Future<BuyerVoucher> claim({
    int? platformPromotionId,
    int? storePromotionId,
    String? code,
  }) async {
    if (code != null) claimedCodes.add(code);
    wallet = _claimedWallet();
    return wallet.platform.single;
  }
}

BuyerVoucherWallet _wallet() => BuyerVoucherWallet(
  platform: [
    const BuyerVoucher(
      source: 'platform',
      id: 11,
      name: 'Wallet Voucher',
      title: 'Save on eligible items',
      valueLabel: '₱5.00',
      minimumSpendMinor: 1000,
      expiresAt: null,
      section: 'discount',
      claimed: false,
      canClaim: true,
      canUse: true,
      autoApplies: false,
      codeApplies: false,
      availabilityStatus: 'active',
      availabilityReason: null,
      description: 'A sample voucher from the API.',
      terms: null,
      code: null,
      fundingType: 'platform',
    ),
  ],
  store: const [],
  claimedCount: 0,
  categories: const [
    BuyerVoucherCategory(key: 'discount', label: 'Item discounts'),
  ],
);

BuyerVoucherWallet _claimedWallet() => BuyerVoucherWallet(
  platform: [
    const BuyerVoucher(
      source: 'platform',
      id: 11,
      name: 'Wallet Voucher',
      title: 'Save on eligible items',
      valueLabel: '₱5.00',
      minimumSpendMinor: 1000,
      expiresAt: null,
      section: 'discount',
      claimed: true,
      canClaim: false,
      canUse: true,
      autoApplies: false,
      codeApplies: false,
      availabilityStatus: 'active',
      availabilityReason: null,
      description: 'A sample voucher from the API.',
      terms: null,
      code: null,
      fundingType: 'platform',
    ),
  ],
  store: const [],
  claimedCount: 1,
  categories: const [
    BuyerVoucherCategory(key: 'discount', label: 'Item discounts'),
  ],
);

BuyerVoucherWallet _emptyWallet() => BuyerVoucherWallet(
  platform: const [],
  store: const [],
  claimedCount: 0,
  categories: const [],
);
