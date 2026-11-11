import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../buyer/models/buyer_catalog_models.dart'
    show formatPriceMinorUnits;
import '../data/logistics_repository.dart';
import '../models/logistics_cash_custody.dart';

class LogisticsCashCustodyPage extends StatefulWidget {
  const LogisticsCashCustodyPage({super.key, required this.repository});

  final LogisticsRepository repository;

  @override
  State<LogisticsCashCustodyPage> createState() =>
      _LogisticsCashCustodyPageState();
}

class _LogisticsCashCustodyPageState extends State<LogisticsCashCustodyPage> {
  static const _pageSize = 20;

  LogisticsCashCustody? _data;
  List<LogisticsCodCashCollection> _cod = const [];
  List<LogisticsRefundCashPayout> _refunds = const [];
  LogisticsCashCustodyPageMeta? _codMeta;
  LogisticsCashCustodyPageMeta? _refundMeta;
  Object? _error;
  bool _loading = true;
  bool _loadingCodMore = false;
  bool _loadingRefundMore = false;
  String? _actingCodAction;
  String? _actingRefundAction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.cashCustody(perPage: _pageSize);
      if (!mounted) return;
      setState(() {
        _data = result;
        _cod = result.codCollections.items;
        _refunds = result.refundCash.items;
        _codMeta = result.codCollections.meta;
        _refundMeta = result.refundCash.meta;
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

  Future<void> _loadMoreCod() async {
    final meta = _codMeta;
    if (meta == null || !meta.hasMore || _loadingCodMore) return;
    setState(() => _loadingCodMore = true);
    try {
      final result = await widget.repository.cashCustody(
        codPage: meta.currentPage + 1,
        refundPage: _refundMeta?.currentPage ?? 1,
        perPage: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _cod = [..._cod, ...result.codCollections.items];
        _codMeta = result.codCollections.meta;
        _data = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loadingCodMore = false);
    }
  }

  Future<void> _loadMoreRefunds() async {
    final meta = _refundMeta;
    if (meta == null || !meta.hasMore || _loadingRefundMore) return;
    setState(() => _loadingRefundMore = true);
    try {
      final result = await widget.repository.cashCustody(
        codPage: _codMeta?.currentPage ?? 1,
        refundPage: meta.currentPage + 1,
        perPage: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _refunds = [..._refunds, ...result.refundCash.items];
        _refundMeta = result.refundCash.meta;
        _data = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loadingRefundMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Custody')),
      body: _loading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) _errorCard(),
                  if (_data != null) ...[
                    _summaryCard(_data!),
                    const SizedBox(height: 18),
                    _sectionHeading(
                      'COD collections',
                      _data!.codCollectionCount,
                    ),
                    const SizedBox(height: 8),
                    if (_cod.isEmpty)
                      const _EmptySection(
                        message: 'No COD collection records for this provider.',
                      )
                    else
                      ..._cod.map(_codCard),
                    if (_codMeta?.hasMore == true)
                      _loadMoreButton(
                        'Load more COD records',
                        _loadingCodMore,
                        _loadMoreCod,
                      ),
                    const SizedBox(height: 18),
                    _sectionHeading(
                      'Active refund cash',
                      _data!.activeRefundCashCount,
                    ),
                    const SizedBox(height: 8),
                    if (_refunds.isEmpty)
                      const _EmptySection(
                        message:
                            'No active refund cash records for this provider.',
                      )
                    else
                      ..._refunds.map(_refundCard),
                    if (_refundMeta?.hasMore == true)
                      _loadMoreButton(
                        'Load more refund records',
                        _loadingRefundMore,
                        _loadMoreRefunds,
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(LogisticsCashCustody data) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.providerName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(label: 'COD records', count: data.codCollectionCount),
              _CountChip(
                label: 'Active refund cash',
                count: data.activeRefundCashCount,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Amounts and statuses reflect recorded transactions. Authorized cash receipt and remittance actions update custody records. Payment reconciliation is handled separately by Finance.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeading(String title, int count) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Text('$count'),
    ],
  );

  Widget _codCard(LogisticsCodCashCollection item) => Card(
    key: ValueKey('cod-${item.id}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      title: Text(item.collectionNo, softWrap: true),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusLabel(item.status),
            const SizedBox(height: 6),
            Text(
              'Collected ${_money(item.amountCollectedMinor)} / due ${_money(item.amountDueMinor)}',
            ),
            if (item.discrepancyMinor != 0)
              Text('Recorded discrepancy ${_money(item.discrepancyMinor)}'),
            if (item.riderName != null) Text('Rider: ${item.riderName}'),
          ],
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _amountLine(
          'Received by Logistics',
          item.amountReceivedByLogisticsMinor,
        ),
        _amountLine('Remitted to Finance', item.amountRemittedToFinanceMinor),
        _amountLine('Reconciled', item.amountReconciledMinor),
        if (item.paymentNo != null)
          _detailLine(
            'Payment',
            '${item.paymentNo} · ${_humanize(item.paymentStatus ?? 'unknown')}',
          ),
        if (item.paymentPaidAt != null)
          _detailLine('Payment completed', _date(item.paymentPaidAt)),
        for (final allocation in item.allocations)
          _detailLine(
            'Order allocation',
            [
              allocation.orderNo,
              allocation.sellerOrderNo,
              'due ${_money(allocation.amountDueMinor)}',
              'collected ${_money(allocation.amountCollectedMinor)}',
            ].whereType<String>().join(' · '),
          ),
        for (final entry in item.references.entries.where(
          (entry) => entry.value != null,
        ))
          _detailLine('${_humanize(entry.key)} reference', entry.value!),
        for (final entry in item.timestamps.entries.where(
          (entry) => entry.value != null,
        ))
          _detailLine(_humanize(entry.key), _date(entry.value)),
        if (item.canReceive || item.canRemit) ...[
          const Divider(height: 20),
          Text(
            'COD cash action',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          if (item.canReceive)
            _codActionButton(
              item,
              action: 'receive',
              label: 'Receive Rider cash',
            ),
          if (item.canRemit)
            _codActionButton(
              item,
              action: 'remit',
              label: 'Remit cash to Finance',
            ),
        ],
        _history(item.history),
      ],
    ),
  );

  Widget _codActionButton(
    LogisticsCodCashCollection item, {
    required String action,
    required String label,
  }) {
    final actionKey = '$action-${item.id}';
    final busy = _actingCodAction == actionKey;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: ValueKey('cod-action-$action-${item.id}'),
          onPressed: _actingCodAction == null && !_loading && _error == null
              ? () => _confirmCodAction(item, action)
              : null,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  action == 'receive' ? Icons.call_received : Icons.payments,
                ),
          label: Text(label),
        ),
      ),
    );
  }

  Future<void> _confirmCodAction(
    LogisticsCodCashCollection item,
    String action,
  ) async {
    final receive = action == 'receive';
    final countMinor = receive
        ? item.amountCollectedMinor
        : (item.amountReceivedByLogisticsMinor ?? item.amountCollectedMinor);
    final amountController = TextEditingController(
      text: _amountText(countMinor),
    );
    var confirmed = false;
    final amount = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            receive ? 'Confirm COD cash received' : 'Confirm Finance handoff',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Collection ${item.collectionNo}'),
                if (item.riderName != null) Text('Rider: ${item.riderName}'),
                const SizedBox(height: 8),
                Text('COD due: ${_money(item.amountDueMinor)}'),
                Text('Rider recorded: ${_money(item.amountCollectedMinor)}'),
                if (item.discrepancyMinor != 0)
                  Text('Recorded difference: ${_money(item.discrepancyMinor)}'),
                const SizedBox(height: 12),
                TextField(
                  key: ValueKey('cod-action-amount-${item.id}'),
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: receive
                        ? 'Cash physically received'
                        : 'Cash accepted by Finance',
                    prefixText: '₱ ',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  receive
                      ? 'Count the cash physically received from the Rider. The acknowledged amount must match the Rider-recorded collection. Any difference between the COD due and Rider-collected amount remains subject to Finance review.'
                      : 'Record this only after physically handing the cash to Finance. This records remittance; Finance must reconcile it separately.',
                ),
                CheckboxListTile(
                  key: ValueKey('cod-action-confirm-$action-${item.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: confirmed,
                  onChanged: (value) =>
                      setDialogState(() => confirmed = value ?? false),
                  title: Text(
                    receive
                        ? 'I physically received and counted this cash.'
                        : 'I physically handed this cash to Finance.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey('cod-action-submit-$action-${item.id}'),
              onPressed:
                  confirmed &&
                      RegExp(
                        r'^\d{1,8}(?:\.\d{1,2})?$',
                      ).hasMatch(amountController.text.trim())
                  ? () => Navigator.of(
                      dialogContext,
                    ).pop(amountController.text.trim())
                  : null,
              child: Text(receive ? 'Confirm receipt' : 'Record remittance'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    if (amount == null || !mounted) return;

    final actionKey = '$action-${item.id}';
    setState(() => _actingCodAction = actionKey);
    try {
      final result = receive
          ? await widget.repository.receiveCodCash(
              collectionId: item.id,
              actualAmount: amount,
            )
          : await widget.repository.remitCodCash(
              collectionId: item.id,
              actualAmount: amount,
            );
      await _load();
      if (!mounted) return;
      final reference = receive
          ? result.logisticsReference
          : result.financeRemittanceReference;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            receive
                ? 'COD receipt recorded${reference == null ? '.' : ': $reference.'}'
                : 'Finance remittance recorded. Finance reconciliation is still required${reference == null ? '.' : ': $reference.'}',
          ),
        ),
      );
    } catch (error) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_codActionError(error, refreshed: _error == null)),
        ),
      );
    } finally {
      if (mounted) setState(() => _actingCodAction = null);
    }
  }

  String _codActionError(Object error, {required bool refreshed}) {
    if (error is ApiHttpException) {
      return switch (error.statusCode) {
        401 || 403 => 'Your Logistics account cannot perform this cash action.',
        404 => 'This COD collection is no longer available to this provider.',
        409 =>
          refreshed
              ? 'The COD collection changed or this action is no longer available. Cash Custody was refreshed.'
              : 'The COD collection changed. Its current state could not be loaded; refresh Cash Custody before trying again.',
        422 =>
          '${_validationMessage(error)} ${refreshed ? 'Cash Custody was refreshed.' : 'Refresh Cash Custody before trying again.'}',
        _ =>
          refreshed
              ? 'The cash action failed. Cash Custody was refreshed.'
              : 'The cash action failed and its current state could not be loaded. Refresh Cash Custody before trying again.',
      };
    }
    if (error is ApiTimeoutException || error is ApiTransportException) {
      return refreshed
          ? 'The request may have reached Bearly. Cash Custody was refreshed; check the current state before trying again.'
          : 'The request may have reached Bearly, but the latest state could not be loaded. Refresh Cash Custody before trying again.';
    }
    return refreshed
        ? 'The cash action could not be confirmed. Cash Custody was refreshed; check its current state before trying again.'
        : 'The cash action could not be confirmed and its latest state could not be loaded. Refresh Cash Custody before trying again.';
  }

  String _validationMessage(ApiHttpException error) {
    for (final messages in error.validationErrors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return 'The amount or confirmation was rejected.';
  }

  Widget _refundCard(LogisticsRefundCashPayout item) => Card(
    key: ValueKey('refund-${item.id}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      title: Text(item.payoutNo, softWrap: true),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusLabel(item.status),
            const SizedBox(height: 6),
            Text('Recorded amount ${_money(item.amountMinor)}'),
            if (item.refundNo != null) Text('Refund: ${item.refundNo}'),
            if (item.returnNo != null) Text('Return: ${item.returnNo}'),
            if (item.riderName != null) Text('Rider: ${item.riderName}'),
          ],
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (item.acknowledgmentReference != null)
          _detailLine('Acknowledgment', item.acknowledgmentReference!),
        for (final entry in item.references.entries.where(
          (entry) => entry.value != null,
        ))
          _detailLine('${_humanize(entry.key)} reference', entry.value!),
        if (item.amountReturnedToLogisticsMinor != null)
          _detailLine(
            'Rider recorded cash returned',
            _money(item.amountReturnedToLogisticsMinor!),
          ),
        if (item.failureReason != null)
          _detailLine('Last delivery attempt', item.failureReason!),
        for (final entry in item.timestamps.entries.where(
          (entry) => entry.value != null,
        ))
          _detailLine(_humanize(entry.key), _date(entry.value)),
        if (item.actions.canReceive ||
            item.actions.canAssign ||
            item.actions.canConfirmReturn ||
            item.actions.canViewSlip ||
            item.actions.canViewProof ||
            item.actions.canVerifyProof) ...[
          const Divider(height: 20),
          Text(
            'Refund cash actions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (item.actions.canReceive)
            _refundActionButton(
              item,
              action: 'receive',
              label: 'Acknowledge cash received',
              icon: Icons.call_received,
              onPressed: () => _receiveRefundCash(item),
            ),
          if (item.actions.canAssign)
            _refundActionButton(
              item,
              action: 'assign',
              label: 'Assign Local Rider',
              icon: Icons.delivery_dining,
              onPressed: () => _assignRefundCash(item),
            ),
          if (item.actions.canConfirmReturn)
            _refundActionButton(
              item,
              action: 'confirm-return',
              label: 'Confirm returned cash',
              icon: Icons.assignment_return,
              onPressed: () => _confirmRefundCashReturn(item),
            ),
          if (item.actions.canViewSlip)
            _refundActionButton(
              item,
              action: 'slip',
              label: 'View paper acknowledgment',
              icon: Icons.receipt_long,
              onPressed: () => _viewRefundAcknowledgmentSlip(item),
            ),
          if (item.actions.canViewProof)
            _refundActionButton(
              item,
              action: 'proof',
              label: 'View signed Buyer proof',
              icon: Icons.verified_outlined,
              onPressed: () => _viewRefundSignedProof(item),
            ),
          if (item.actions.canVerifyProof)
            _refundActionButton(
              item,
              action: 'verify',
              label: 'Verify Buyer proof',
              icon: Icons.fact_check_outlined,
              onPressed: () => _verifyRefundReceipt(item),
            ),
          if (item.status == 'awaiting_finance_completion')
            const Text(
              'Logistics verification is complete. Finance must record the final payout.',
            ),
        ],
        _history(item.history),
      ],
    ),
  );

  Widget _refundActionButton(
    LogisticsRefundCashPayout item, {
    required String action,
    required String label,
    required IconData icon,
    required Future<void> Function() onPressed,
  }) {
    final actionKey = '$action-${item.id}';
    final busy = _actingRefundAction == actionKey;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: ValueKey('refund-action-$action-${item.id}'),
          onPressed:
              _actingRefundAction == null &&
                  _actingCodAction == null &&
                  !_loading &&
                  _error == null
              ? onPressed
              : null,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }

  Future<void> _receiveRefundCash(LogisticsRefundCashPayout item) async {
    final values = await _cashConfirmationDialog(
      item,
      title: 'Confirm refund cash received',
      amountLabel: 'Cash physically received from Finance',
      referenceLabel: 'Logistics receipt reference',
      confirmationLabel:
          'I physically received and counted this exact cash amount.',
    );
    if (values == null || !mounted) return;
    await _submitRefundMutation(
      item,
      action: 'receive',
      successMessage: 'Refund cash receipt recorded.',
      request: () => widget.repository.receiveRefundCash(
        payoutId: item.id,
        expectedAmountMinor: item.amountMinor,
        actualAmount: values.$1,
        reference: values.$2,
      ),
    );
  }

  Future<void> _confirmRefundCashReturn(LogisticsRefundCashPayout item) async {
    final values = await _cashConfirmationDialog(
      item,
      title: 'Confirm cash returned by Rider',
      amountLabel: 'Cash physically received from Rider',
      referenceLabel: 'Logistics return receipt reference',
      confirmationLabel:
          'I counted and physically received the full cash amount.',
    );
    if (values == null || !mounted) return;
    await _submitRefundMutation(
      item,
      action: 'confirm-return',
      successMessage:
          'Returned refund cash confirmed. A Rider can now be assigned.',
      request: () => widget.repository.confirmRefundCashReturn(
        payoutId: item.id,
        expectedAmountMinor: item.amountMinor,
        actualAmount: values.$1,
        reference: values.$2,
      ),
    );
  }

  Future<(String, String)?> _cashConfirmationDialog(
    LogisticsRefundCashPayout item, {
    required String title,
    required String amountLabel,
    required String referenceLabel,
    required String confirmationLabel,
  }) async {
    var amountValue = _amountText(item.amountMinor);
    var referenceValue = '';
    var confirmed = false;
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payout ${item.payoutNo}'),
                const SizedBox(height: 6),
                Text('Recorded amount: ${_money(item.amountMinor)}'),
                const SizedBox(height: 10),
                TextFormField(
                  key: ValueKey('refund-amount-${item.id}'),
                  initialValue: amountValue,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: amountLabel,
                    prefixText: '₱ ',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => amountValue = value),
                ),
                TextFormField(
                  key: ValueKey('refund-reference-${item.id}'),
                  initialValue: referenceValue,
                  maxLength: 150,
                  decoration: InputDecoration(labelText: referenceLabel),
                  onChanged: (value) =>
                      setDialogState(() => referenceValue = value),
                ),
                CheckboxListTile(
                  key: ValueKey('refund-confirm-${item.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: confirmed,
                  onChanged: (value) =>
                      setDialogState(() => confirmed = value ?? false),
                  title: Text(confirmationLabel),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey('refund-submit-${item.id}'),
              onPressed:
                  confirmed &&
                      _cashAmountMatches(amountValue, item.amountMinor) &&
                      referenceValue.trim().isNotEmpty &&
                      referenceValue.trim().length <= 150
                  ? () => Navigator.of(
                      dialogContext,
                    ).pop((amountValue.trim(), referenceValue.trim()))
                  : null,
              child: const Text('Confirm cash action'),
            ),
          ],
        ),
      ),
    );
    return values;
  }

  bool _cashAmountMatches(String value, int expectedMinor) {
    final match = RegExp(
      r'^(\d{1,8})(?:\.(\d{1,2}))?$',
    ).firstMatch(value.trim());
    if (match == null) return false;
    final minor =
        int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
    return minor == expectedMinor;
  }

  Future<void> _assignRefundCash(LogisticsRefundCashPayout item) async {
    final actionKey = 'assign-${item.id}';
    setState(() => _actingRefundAction = actionKey);
    late final List<LogisticsRefundCashRiderChoice> riders;
    try {
      riders = await widget.repository.eligibleRefundCashRiders(
        payoutId: item.id,
      );
    } catch (error) {
      await _load();
      if (!mounted) return;
      setState(() => _actingRefundAction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_refundActionError(error, refreshed: _error == null)),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _actingRefundAction = null);
    if (riders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No eligible available Local Riders. Refresh before trying again.',
          ),
        ),
      );
      return;
    }

    int? selectedRiderId;
    var confirmed = false;
    final riderId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign refund cash to Local Rider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payout ${item.payoutNo} · ${_money(item.amountMinor)}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('refund-rider-choice-${item.id}'),
                  initialValue: selectedRiderId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Eligible Local Rider',
                  ),
                  items: riders
                      .map(
                        (rider) => DropdownMenuItem<int>(
                          value: rider.userId,
                          child: Text(
                            rider.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setDialogState(() => selectedRiderId = value),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: ValueKey('refund-assign-confirm-${item.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: confirmed,
                  onChanged: (value) =>
                      setDialogState(() => confirmed = value ?? false),
                  title: const Text(
                    'I will hand the physical cash and printed acknowledgment to this Rider.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey('refund-assign-submit-${item.id}'),
              onPressed: confirmed && selectedRiderId != null
                  ? () => Navigator.of(dialogContext).pop(selectedRiderId)
                  : null,
              child: const Text('Assign Rider'),
            ),
          ],
        ),
      ),
    );
    if (riderId == null || !mounted) return;
    await _submitRefundMutation(
      item,
      action: 'assign',
      successMessage:
          'Local Rider assigned. Use the acknowledgment reference and give the Rider the printed slip with the cash.',
      request: () => widget.repository.assignRefundCash(
        payoutId: item.id,
        riderUserId: riderId,
      ),
    );
  }

  Future<void> _verifyRefundReceipt(LogisticsRefundCashPayout item) async {
    var noteValue = '';
    var confirmed = false;
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Verify Buyer signed proof'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Payout ${item.payoutNo} · ${_money(item.amountMinor)}'),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('refund-verification-note-${item.id}'),
                  initialValue: noteValue,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Verification note',
                  ),
                  onChanged: (value) => setDialogState(() => noteValue = value),
                ),
                CheckboxListTile(
                  key: ValueKey('refund-verify-confirm-${item.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: confirmed,
                  onChanged: (value) =>
                      setDialogState(() => confirmed = value ?? false),
                  title: const Text(
                    'I reviewed the signed Buyer proof and matched it to this payout.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey('refund-verify-submit-${item.id}'),
              onPressed:
                  confirmed &&
                      noteValue.trim().length >= 5 &&
                      noteValue.trim().length <= 1000
                  ? () => Navigator.of(dialogContext).pop(noteValue.trim())
                  : null,
              child: const Text('Verify for Finance'),
            ),
          ],
        ),
      ),
    );
    if (note == null || !mounted) return;
    await _submitRefundMutation(
      item,
      action: 'verify',
      successMessage: 'Buyer proof verified. Finance must complete the refund.',
      request: () => widget.repository.verifyRefundCashReceipt(
        payoutId: item.id,
        verificationNote: note,
      ),
    );
  }

  Future<void> _viewRefundAcknowledgmentSlip(
    LogisticsRefundCashPayout item,
  ) async {
    final actionKey = 'slip-${item.id}';
    setState(() => _actingRefundAction = actionKey);
    try {
      final slip = await widget.repository.refundCashAcknowledgmentSlip(
        payoutId: item.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Buyer cash refund acknowledgment'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailLine('Acknowledgment reference', slip.reference),
                _detailLine(
                  'Delivery attempt',
                  '${slip.deliveryAttemptNumber}',
                ),
                _detailLine('Cash refund amount', _money(slip.amountMinor)),
                _detailLine('Buyer / recipient', slip.buyerOrRecipientName),
                if (slip.refundNo != null)
                  _detailLine('Refund ID', slip.refundNo!),
                _detailLine('Cash payout ID', slip.payoutNo),
                if (slip.orderNo != null)
                  _detailLine('Order ID', slip.orderNo!),
                if (slip.riderName != null)
                  _detailLine('Assigned Rider', slip.riderName!),
                _detailLine('Logistics provider', slip.providerName),
                const SizedBox(height: 8),
                Text(slip.buyerConfirmation),
                for (final label in slip.signatureLabels) ...[
                  const SizedBox(height: 8),
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  const Divider(),
                  const Text('Printed name · Signature · Date and time'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _refundActionError(error, refreshed: _error == null),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _actingRefundAction = null);
    }
  }

  Future<void> _viewRefundSignedProof(LogisticsRefundCashPayout item) async {
    final actionKey = 'proof-${item.id}';
    setState(() => _actingRefundAction = actionKey);
    try {
      final proof = await widget.repository.refundCashSignedProof(
        payoutId: item.id,
      );
      if (!mounted) return;
      final mimeType = proof.contentType!.split(';').first.trim();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Signed Buyer proof'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: mimeType == 'application/pdf'
                ? PdfViewer.data(
                    Uint8List.fromList(proof.bytes),
                    sourceName: 'Signed Buyer acknowledgment.pdf',
                  )
                : InteractiveViewer(
                    child: Image.memory(
                      Uint8List.fromList(proof.bytes),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Text(
                              'The signed proof image could not be displayed.',
                            ),
                          ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _refundActionError(error, refreshed: _error == null),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _actingRefundAction = null);
    }
  }

  Future<void> _submitRefundMutation(
    LogisticsRefundCashPayout item, {
    required String action,
    required String successMessage,
    required Future<LogisticsRefundCashActionResult> Function() request,
  }) async {
    if (_actingRefundAction != null) return;
    setState(() => _actingRefundAction = '$action-${item.id}');
    try {
      await request();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_refundActionError(error, refreshed: _error == null)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actingRefundAction = null);
    }
  }

  String _refundActionError(Object error, {required bool refreshed}) {
    if (error is ApiHttpException) {
      return switch (error.statusCode) {
        401 ||
        403 => 'Your Logistics account cannot perform this refund cash action.',
        404 =>
          'This payout, slip, or proof is no longer available to this provider.',
        409 =>
          refreshed
              ? 'The payout changed or is no longer eligible. Cash Custody was refreshed.'
              : 'The payout changed; refresh Cash Custody before trying again.',
        422 =>
          '${_refundValidationMessage(error)} ${refreshed ? 'Cash Custody was refreshed.' : 'Refresh before trying again.'}',
        _ =>
          refreshed
              ? 'The refund cash request failed. Cash Custody was refreshed.'
              : 'The request failed and the latest state could not be loaded.',
      };
    }
    if (error is ApiTimeoutException || error is ApiTransportException) {
      return refreshed
          ? 'The request may have reached Bearly. Cash Custody was refreshed; inspect the current state before any retry.'
          : 'The request may have reached Bearly, but current state could not be loaded. Refresh before any retry.';
    }
    return refreshed
        ? 'The request could not be confirmed. Cash Custody was refreshed; inspect its current state before any retry.'
        : 'The request could not be confirmed and current state could not be loaded. Refresh before any retry.';
  }

  String _refundValidationMessage(ApiHttpException error) {
    for (final messages in error.validationErrors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return 'The amount, reference, Rider, or verification note was rejected.';
  }

  Widget _history(List<LogisticsCashCustodyHistoryEvent> events) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Text(
          'Transaction history',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        for (final event in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              [
                _humanize(event.type),
                if (event.from != null || event.to != null)
                  '${event.from == null ? '' : '${_humanize(event.from!)} → '}${event.to == null ? '' : _humanize(event.to!)}',
                if (event.amountMinor != null) _money(event.amountMinor!),
                if (event.reference != null) event.reference!,
                if (event.occurredAt != null) _date(event.occurredAt),
              ].join(' · '),
              softWrap: true,
            ),
          ),
      ],
    );
  }

  Widget _amountLine(String label, int? amountMinor) => amountMinor == null
      ? const SizedBox.shrink()
      : _detailLine(label, _money(amountMinor));

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text('$label: $value', softWrap: true),
  );

  Widget _loadMoreButton(String label, bool loading, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      );

  Widget _errorCard() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cash custody information could not be loaded.'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _load, child: const Text('Try again')),
          ),
        ],
      ),
    ),
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $count'));
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.status);
  final String status;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(_humanize(status)),
      ),
    ),
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

String _money(int minor) {
  return formatPriceMinorUnits(minor, currency: 'PHP');
}

String _amountText(int minor) =>
    '${minor ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _date(String? value) {
  if (value == null) return '—';
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final period = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} $hour:$minute $period';
}
