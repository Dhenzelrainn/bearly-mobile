import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/rider_cash_custody_repository.dart';
import '../models/rider_cash_custody.dart';

class RiderCashCustodyPage extends StatefulWidget {
  const RiderCashCustodyPage({super.key, required this.repository});

  final RiderCashCustodyDataSource repository;

  @override
  State<RiderCashCustodyPage> createState() => _RiderCashCustodyPageState();
}

class _RiderCashCustodyPageState extends State<RiderCashCustodyPage> {
  late Future<RiderCashCustody> _request;

  @override
  void initState() {
    super.initState();
    _request = widget.repository.load();
  }

  Future<void> _refresh() async {
    final request = widget.repository.load();
    setState(() {
      _request = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cash Custody'),
      leading: BackButton(onPressed: () => Navigator.maybePop(context)),
    ),
    body: FutureBuilder<RiderCashCustody>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState();
        }
        final custody = snapshot.data;
        if (custody == null) return _errorState();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: custody.isEmpty ? _emptyState() : _custodyList(custody),
        );
      },
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Cash custody could not be loaded. Check your connection and retry.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () =>
                setState(() => _request = widget.repository.load()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _emptyState() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: const [
      SizedBox(height: 100),
      Icon(Icons.account_balance_wallet_outlined, size: 48),
      SizedBox(height: 12),
      Text(
        'No cash custody records yet',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 6),
      Text(
        'Recorded COD collections and assigned refund cash will appear here.',
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _custodyList(RiderCashCustody custody) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: [
      Text(
        'Read-only financial records from Bearly.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
      ),
      const SizedBox(height: 12),
      _summaryCard(
        'COD collected',
        custody.summary.codCollectedMinor,
        Icons.payments_outlined,
      ),
      const SizedBox(height: 8),
      _summaryCard(
        'COD awaiting Logistics handoff',
        custody.summary.codHandoffPendingMinor,
        Icons.local_shipping_outlined,
      ),
      const SizedBox(height: 8),
      _summaryCard(
        'Refund cash currently with you',
        custody.summary.refundCashWithRiderMinor,
        Icons.account_balance_wallet_outlined,
      ),
      if (custody.codCollections.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text(
          'COD collection history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final record in custody.codCollections) _codCard(record),
      ],
      if (custody.refundCash.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text(
          'Refund cash assignments',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final record in custody.refundCash) _refundCard(record),
      ],
    ],
  );

  Widget _summaryCard(String label, int amountMinor, IconData icon) => Card(
    child: ListTile(
      leading: Icon(icon, color: BearlyColors.brown800),
      title: Text(label),
      trailing: Text(
        _money(amountMinor),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _codCard(RiderCodCashRecord record) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.collectionNo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _statusChip(record.status),
            ],
          ),
          const SizedBox(height: 10),
          _amountLine('Amount due', record.amountDueMinor),
          _amountLine('Cash collected', record.amountCollectedMinor),
          if (record.discrepancyMinor != 0)
            _amountLine('Recorded difference', record.discrepancyMinor),
          _dateLine('Collected', record.collectedAt),
          _dateLine('Received by Logistics', record.logisticsReceivedAt),
          _dateLine('Remitted to Finance', record.remittedToFinanceAt),
          _dateLine('Reconciled', record.reconciledAt),
          if (record.logisticsReference case final reference?)
            _textLine('Logistics reference', reference),
          if (record.financeRemittanceReference case final reference?)
            _textLine('Finance remittance reference', reference),
          if (record.financeReference case final reference?)
            _textLine('Finance reference', reference),
          if (record.events.isNotEmpty) ...[
            const Divider(height: 22),
            for (final event in record.events) _eventLine(event),
          ],
        ],
      ),
    ),
  );

  Widget _refundCard(RiderRefundCashRecord record) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.payoutNo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _statusChip(record.status),
            ],
          ),
          const SizedBox(height: 10),
          _amountLine('Refund cash', record.amountMinor),
          _dateLine('Assigned', record.assignedAt),
          _dateLine('Received by Rider', record.receivedByRiderAt),
          _dateLine('Delivery started', record.startedAt),
          _dateLine('Buyer handoff', record.deliveredAt),
          _dateLine('Logistics verified', record.logisticsVerifiedAt),
          _dateLine('Completed', record.completedAt),
          if (record.acknowledgmentReference case final reference?)
            _textLine('Acknowledgment reference', reference),
          if (record.events.isNotEmpty) ...[
            const Divider(height: 22),
            for (final event in record.events) _eventLine(event),
          ],
        ],
      ),
    ),
  );

  Widget _statusChip(String status) =>
      Chip(visualDensity: VisualDensity.compact, label: Text(_label(status)));

  Widget _amountLine(String label, int amountMinor) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          _money(amountMinor),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _dateLine(String label, DateTime? value) {
    if (value == null) return const SizedBox.shrink();
    return _textLine(label, _dateTime(value));
  }

  Widget _textLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Widget _eventLine(RiderCashCustodyEvent event) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label(event.type),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (event.status case final status?) Text('Status: ${_label(status)}'),
        if (event.reference case final reference?)
          Text('Reference: $reference'),
        if (event.amountMinor case final amount?)
          Text('Amount: ${_money(amount)}'),
        if (event.at case final date?) Text(_dateTime(date)),
        if (event.note case final note?) Text(note),
      ],
    ),
  );

  String _money(int minor) =>
      '${minor < 0 ? '-₱' : '₱'}${(minor.abs() / 100).toStringAsFixed(2)}';

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }

  String _label(String value) {
    final words = value.replaceAll('_', ' ').split(' ');
    if (words.isEmpty) return value;
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
