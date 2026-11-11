import 'package:flutter/material.dart';

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
        for (final entry in item.timestamps.entries.where(
          (entry) => entry.value != null,
        ))
          _detailLine(_humanize(entry.key), _date(entry.value)),
        _history(item.history),
      ],
    ),
  );

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
