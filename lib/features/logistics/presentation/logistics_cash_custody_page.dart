import 'package:flutter/material.dart';

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
            'Amounts and stages below reflect recorded transactions. This screen does not change custody or payment status.',
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
        _history(item.history),
      ],
    ),
  );

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
  final absolute = minor.abs();
  final sign = minor < 0 ? '-' : '';
  return '$sign₱${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
}

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
