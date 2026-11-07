import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_vouchers_repository.dart';
import '../models/buyer_catalog_models.dart';
import '../models/buyer_voucher_models.dart';

class BuyerVouchersPage extends StatefulWidget {
  const BuyerVouchersPage({super.key, required this.repository});

  final BuyerVouchersDataSource repository;

  @override
  State<BuyerVouchersPage> createState() => _BuyerVouchersPageState();
}

class _BuyerVouchersPageState extends State<BuyerVouchersPage> {
  final _codeController = TextEditingController();
  BuyerVoucherWallet? _wallet;
  Object? _error;
  String? _actionMessage;
  String? _actionError;
  String _statusFilter = 'all';
  String? _categoryFilter;
  bool _loading = true;
  bool _claiming = false;
  Future<void>? _pending;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWallet());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() {
    final pending = _pending;
    if (pending != null) return pending;
    final request = _fetchWallet();
    _pending = request.whenComplete(() => _pending = null);
    return _pending!;
  }

  Future<void> _fetchWallet() async {
    setState(() {
      if (_wallet == null) _loading = true;
      _error = null;
    });
    try {
      final wallet = await widget.repository.getWallet();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _claimCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _claiming) return;
    await _claim(code: code);
  }

  Future<void> _claimVoucher(BuyerVoucher voucher) async {
    if (!voucher.canClaim || _claiming) return;
    await _claim(
      platformPromotionId: voucher.isStoreVoucher ? null : voucher.id,
      storePromotionId: voucher.isStoreVoucher ? voucher.id : null,
    );
  }

  Future<void> _claim({
    int? platformPromotionId,
    int? storePromotionId,
    String? code,
  }) async {
    setState(() {
      _claiming = true;
      _actionError = null;
      _actionMessage = null;
    });
    try {
      await widget.repository.claim(
        platformPromotionId: platformPromotionId,
        storePromotionId: storePromotionId,
        code: code,
      );
      if (!mounted) return;
      _codeController.clear();
      setState(() => _actionMessage = 'Voucher added to My Vouchers.');
      await _loadWallet();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionError =
            'This voucher could not be claimed. It may already be claimed, expired, exhausted, or not eligible.';
      });
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  List<BuyerVoucher> get _filteredVouchers {
    final wallet = _wallet;
    if (wallet == null) return const [];
    return wallet.vouchers
        .where((voucher) {
          final statusMatches = switch (_statusFilter) {
            'available' => voucher.canClaim,
            'claimed' => voucher.isClaimed,
            _ => true,
          };
          final categoryMatches =
              _categoryFilter == null || voucher.section == _categoryFilter;
          return statusMatches && categoryMatches;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Vouchers')),
    body: _loading && _wallet == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadWallet,
            child: ListView(
              key: const ValueKey('buyer-vouchers-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                Text(
                  'My Vouchers',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_wallet?.claimedCount ?? 0} claimed vouchers. Final eligibility and discounts are checked by Bearly at checkout.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
                ),
                const SizedBox(height: 16),
                _claimCodeCard(context),
                if (_actionMessage != null) ...[
                  const SizedBox(height: 8),
                  _notice(_actionMessage!, success: true),
                ],
                if (_actionError != null) ...[
                  const SizedBox(height: 8),
                  _notice(_actionError!),
                ],
                if (_error != null && _wallet == null) ...[
                  const SizedBox(height: 12),
                  _errorCard(),
                ] else ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip('All', 'all'),
                      _filterChip('Available', 'available'),
                      _filterChip('Claimed', 'claimed'),
                    ],
                  ),
                  if (_wallet?.categories.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final category in _wallet!.categories)
                          ChoiceChip(
                            key: ValueKey(
                              'buyer-voucher-category-${category.key}',
                            ),
                            label: Text(category.label),
                            selected: _categoryFilter == category.key,
                            onSelected: (selected) => setState(
                              () => _categoryFilter = selected
                                  ? category.key
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_filteredVouchers.isEmpty)
                    _emptyState(context)
                  else
                    for (final voucher in _filteredVouchers)
                      _voucherCard(context, voucher),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    _notice(
                      'Vouchers could not be refreshed. Pull down to retry.',
                    ),
                  ],
                ],
              ],
            ),
          ),
  );

  Widget _claimCodeCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Claim with a code',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('buyer-voucher-code-input'),
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Voucher code',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _claimCode(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('buyer-voucher-claim-code'),
                onPressed: _claiming ? null : _claimCode,
                child: _claiming
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Claim'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _filterChip(String label, String value) => ChoiceChip(
    key: ValueKey('buyer-voucher-filter-$value'),
    label: Text(label),
    selected: _statusFilter == value,
    onSelected: (_) => setState(() => _statusFilter = value),
  );

  Widget _voucherCard(BuildContext context, BuyerVoucher voucher) {
    final localizations = MaterialLocalizations.of(context);
    final expiry = voucher.expiresAt == null
        ? null
        : localizations.formatMediumDate(voucher.expiresAt!.toLocal());
    final actionText = voucher.isClaimed
        ? 'Claimed'
        : voucher.canClaim
        ? 'Claim'
        : voucher.autoApplies
        ? 'Applied automatically when eligible'
        : voucher.codeApplies
        ? 'Enter this code at checkout'
        : voucher.availabilityReason ?? 'Not available';
    return Card(
      key: ValueKey('buyer-voucher-${voucher.source}-${voucher.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    voucher.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  voucher.valueLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: BearlyColors.brown700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(voucher.title),
            const SizedBox(height: 5),
            Text(voucher.isStoreVoucher ? 'Store funded' : 'Bearly funded'),
            if (voucher.minimumSpendMinor > 0)
              Text(
                'Minimum spend ${formatPriceMinorUnits(voucher.minimumSpendMinor, currency: 'PHP')}',
              ),
            if (expiry != null) Text('Expires $expiry'),
            if (voucher.code != null) SelectableText('Code: ${voucher.code}'),
            if (voucher.description != null) Text(voucher.description!),
            if (voucher.terms != null) ...[
              const SizedBox(height: 3),
              Text(
                voucher.terms!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: voucher.canClaim
                  ? FilledButton.tonal(
                      key: ValueKey('buyer-voucher-claim-${voucher.id}'),
                      onPressed: _claiming
                          ? null
                          : () => _claimVoucher(voucher),
                      child: Text(_claiming ? 'Adding…' : 'Claim'),
                    )
                  : Text(
                      actionText,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: voucher.isClaimed
                            ? BearlyColors.success
                            : BearlyColors.muted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        const Icon(Icons.confirmation_number_outlined, size: 42),
        const SizedBox(height: 8),
        Text(
          'No vouchers in this view',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text('Claim a current offer or check back later.'),
      ],
    ),
  );

  Widget _errorCard() => Column(
    children: [
      const Text(
        'Vouchers could not be loaded. Check your connection and retry.',
      ),
      TextButton(onPressed: _loadWallet, child: const Text('Retry')),
    ],
  );

  Widget _notice(String message, {bool success = false}) => Container(
    key: ValueKey(success ? 'buyer-voucher-success' : 'buyer-voucher-error'),
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: success
          ? BearlyColors.success.withValues(alpha: .1)
          : BearlyColors.error.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message),
  );
}
