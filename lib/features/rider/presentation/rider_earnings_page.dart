import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/rider_repository.dart';
import '../models/rider_earnings.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderEarningsPage extends StatefulWidget {
  const RiderEarningsPage({super.key, required this.repository});

  final RiderRepository repository;

  @override
  State<RiderEarningsPage> createState() => _RiderEarningsPageState();
}

class _RiderEarningsPageState extends State<RiderEarningsPage> {
  RiderEarningsData? _earnings;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  String? _error;
  String? _paginationError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh && _refreshing) return;
    if (refresh) {
      setState(() {
        _refreshing = true;
        _paginationError = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await widget.repository.earnings();
      if (!mounted) return;
      setState(() {
        _earnings = result;
        _error = null;
        _paginationError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load earnings. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final current = _earnings;
    if (current == null || !current.hasMore || _loadingMore) return;

    setState(() {
      _loadingMore = true;
      _paginationError = null;
    });
    try {
      final next = await widget.repository.earnings(
        page: current.currentPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _earnings = current.copyWith(
          entries: [...current.entries, ...next.entries],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _paginationError = 'Could not load more earnings. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    currentRoute: AppRouteNames.riderEarnings,
    title: 'Earnings',
    subtitle: 'Your recorded earnings and payout status.',
    supportsLocalFulfillment:
        widget.repository.lastKnownWorkAccess?.supportsLocalFulfillment == true,
    onRefresh: () => _load(refresh: true),
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    if (_loading && _earnings == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _earnings == null) {
      return _message(
        _error!,
        icon: Icons.cloud_off_outlined,
        action: TextButton.icon(
          onPressed: () => _load(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );
    }

    final earnings = _earnings;
    if (earnings == null) {
      return _message('Earnings are unavailable right now.');
    }

    final summary = earnings.summary;
    final isCourier = earnings.workType == 'courier';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          _message(
            _error!,
            action: TextButton(
              onPressed: () => _load(refresh: true),
              child: const Text('Retry'),
            ),
          ),
        _totalCard(context, summary.combinedTotal, earnings.currency),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Earnings summary'),
        const SizedBox(height: 8),
        _periodCard(context, 'Today', summary.today),
        _periodCard(context, 'This week', summary.week),
        _periodCard(context, 'This month', summary.month),
        const SizedBox(height: 8),
        _summaryRow(context, 'Recorded ledger total', summary.activeTotal),
        _summaryRow(
          context,
          'Delivery awaiting eligibility',
          summary.deliveryPending,
        ),
        if (summary.pickupHeldMinor > 0)
          _summaryRow(context, 'Pickup held for review', summary.pickupHeld),
        _summaryRow(context, 'Available for payout', summary.payoutEligible),
        _summaryRow(context, 'Paid', summary.payoutPaid),
        _summaryRow(context, 'Payout status', summary.payoutStatus),
        if (isCourier && earnings.courierDaily != null) ...[
          const SizedBox(height: 14),
          _sectionTitle(context, 'Courier daily earnings'),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow(
                    context,
                    'Recorded daily total',
                    earnings.courierDaily!.total,
                  ),
                  _summaryRow(
                    context,
                    'Qualifying workdays',
                    '${earnings.courierDaily!.qualifyingDays}',
                  ),
                  _summaryRow(
                    context,
                    'Daily rate',
                    earnings.courierDaily!.rate,
                  ),
                  _summaryRow(
                    context,
                    'Available for payout',
                    earnings.courierDaily!.eligible,
                  ),
                  _summaryRow(context, 'Paid', earnings.courierDaily!.paid),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _sectionTitle(context, 'Recent earnings'),
        const SizedBox(height: 8),
        if (earnings.entries.isEmpty)
          _message('No earnings have been recorded for this account yet.')
        else ...[
          Text(
            'Showing ${earnings.entries.length} of ${earnings.total} records',
          ),
          const SizedBox(height: 8),
          ...earnings.entries.map((entry) => _earningCard(context, entry)),
          if (_paginationError != null)
            _message(
              _paginationError!,
              action: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: const Text('Retry'),
              ),
            ),
          if (earnings.hasMore)
            Center(
              child: TextButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_loadingMore ? 'Loading' : 'Load more'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _totalCard(BuildContext context, String amount, String currency) =>
      Card(
        color: BearlyColors.brown900,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Combined recorded earnings · $currency',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 5),
              Text(
                amount,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );

  Widget _periodCard(
    BuildContext context,
    String label,
    RiderEarningsPeriod period,
  ) => Card(
    color: Colors.white,
    child: ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: Text(label),
      subtitle: Text(
        '${period.entries} active ${period.entries == 1 ? 'entry' : 'entries'}',
      ),
      trailing: Text(
        period.amount,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: Theme.of(context).textTheme.titleLarge);

  Widget _summaryRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      );

  Widget _earningCard(BuildContext context, RiderEarningRecord entry) => Card(
    color: Colors.white,
    child: ListTile(
      isThreeLine: true,
      leading: CircleAvatar(
        backgroundColor: BearlyColors.cream100,
        child: Icon(
          entry.isCourierDaily
              ? Icons.local_shipping_outlined
              : Icons.receipt_long_outlined,
          color: BearlyColors.brown900,
        ),
      ),
      title: Text(entry.job.isEmpty ? entry.typeLabel : entry.job),
      subtitle: Text(
        [
          entry.workDate.isNotEmpty
              ? 'Work date ${entry.workDate}'
              : entry.earnedAt,
          entry.typeLabel,
          entry.source,
          entry.statusLabel,
        ].where((value) => value.isNotEmpty).join(' · '),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        entry.amount,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );

  Widget _message(String message, {IconData? icon, Widget? action}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          if (icon != null) Icon(icon, size: 36, color: BearlyColors.muted),
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
