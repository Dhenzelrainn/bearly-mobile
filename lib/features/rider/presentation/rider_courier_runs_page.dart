import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/rider_repository.dart';
import '../models/rider_courier_run.dart';

class RiderCourierRunsPage extends StatefulWidget {
  const RiderCourierRunsPage({super.key, required this.repository});

  final RiderRepository repository;

  @override
  State<RiderCourierRunsPage> createState() => _RiderCourierRunsPageState();
}

class _RiderCourierRunsPageState extends State<RiderCourierRunsPage> {
  String _view = 'active';
  RiderCourierRunPage? _result;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (!refresh) _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.courierRuns(view: _view);
      if (!mounted) return;
      setState(() {
        _result = page;
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

  Future<void> _loadMore() async {
    final current = _result;
    if (current == null || !current.hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await widget.repository.courierRuns(
        view: _view,
        page: current.currentPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _result = RiderCourierRunPage(
          runs: [...current.runs, ...next.runs],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openRun(RiderCourierRun run) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RiderCourierRunDetailsPage(
          repository: widget.repository,
          runId: run.id,
        ),
      ),
    );
    if (mounted) await _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Courier Runs')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'active', label: Text('Active')),
              ButtonSegment(value: 'history', label: Text('Completed')),
            ],
            selected: {_view},
            onSelectionChanged: (selected) {
              setState(() {
                _view = selected.first;
                _result = null;
              });
              unawaited(_load());
            },
          ),
        ),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        message: _errorMessage(_error!),
        actionLabel: 'Retry',
        onAction: () => unawaited(_load()),
      );
    }

    final runs = _result?.runs ?? const <RiderCourierRun>[];
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (runs.isEmpty)
            _MessageState(
              icon: Icons.local_shipping_outlined,
              message: _view == 'active'
                  ? 'No active Courier runs are assigned to you.'
                  : 'No completed Courier runs are available yet.',
              compact: true,
            )
          else
            ...runs.map(
              (run) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(
                      run.runNo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        '${_statusLabel(run.status)} · ${run.shipments.length} shipment(s) · ${run.parcelCount} parcel(s)\n'
                        '${run.originCenter.isEmpty ? run.originProvider : run.originCenter} → ${run.destinationProvider}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openRun(run),
                  ),
                ),
              ),
            ),
          if (_result?.hasMore == true)
            Center(
              child: OutlinedButton.icon(
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
      ),
    );
  }
}

class RiderCourierRunDetailsPage extends StatefulWidget {
  const RiderCourierRunDetailsPage({
    super.key,
    required this.repository,
    required this.runId,
  });

  final RiderRepository repository;
  final int runId;

  @override
  State<RiderCourierRunDetailsPage> createState() =>
      _RiderCourierRunDetailsPageState();
}

class _RiderCourierRunDetailsPageState
    extends State<RiderCourierRunDetailsPage> {
  RiderCourierRun? _run;
  Object? _error;
  bool _loading = true;
  bool _performingAction = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final run = await widget.repository.courierRunDetail(widget.runId);
      if (mounted) {
        setState(() {
          _run = run;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _runAction(RiderCourierRunAction action) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action.label),
        content: Text(_confirmationText(action.key)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || _performingAction) return;
    setState(() => _performingAction = true);
    try {
      final updated = await widget.repository.performCourierRunAction(
        widget.runId,
        action.key,
      );
      if (!mounted) return;
      setState(() => _run = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${action.label} recorded.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _performingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Courier Run Details')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _MessageState(
            icon: Icons.cloud_off_outlined,
            message: _errorMessage(_error!),
            actionLabel: 'Retry',
            onAction: () => unawaited(_load()),
          )
        : _details(_run!),
  );

  Widget _details(RiderCourierRun run) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(run.runNo, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Chip(label: Text(_statusLabel(run.status))),
        Card(
          child: ListTile(
            leading: const Icon(Icons.route_outlined),
            title: Text(
              run.originCenter.isEmpty ? run.originProvider : run.originCenter,
            ),
            subtitle: Text(
              'Origin: ${run.originProvider}\nDestination: ${run.destinationProvider}',
            ),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manifest (${run.shipments.length} shipments · ${run.parcelCount} parcels)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...run.shipments.map(
          (shipment) => Card(
            child: ExpansionTile(
              title: Text(
                shipment.waybillNo.isEmpty
                    ? shipment.shipmentNo
                    : shipment.waybillNo,
              ),
              subtitle: Text(
                '${shipment.shipmentNo} · ${_statusLabel(shipment.status)} · ${shipment.parcels.length} parcel(s)',
              ),
              children: shipment.parcels
                  .map(
                    (parcel) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.qr_code_2_rounded),
                      title: Text(parcel.parcelNo),
                      subtitle: Text(
                        [
                          _statusLabel(parcel.status),
                          if (parcel.currentSortingCenter.isNotEmpty)
                            parcel.currentSortingCenter,
                        ].join(' · '),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        if (run.availableActions.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...run.availableActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                onPressed: _performingAction ? null : () => _runAction(action),
                icon: _performingAction
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(action.label),
              ),
            ),
          ),
        ] else if (run.status == 'arrived')
          const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_top_rounded),
              title: Text('Waiting for destination Logistics'),
              subtitle: Text(
                'Arrival is recorded. Destination Logistics must accept the Waybills before this run can be completed.',
              ),
            ),
          )
        else if (run.status == 'exception')
          const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber_rounded),
              title: Text('Run on hold'),
              subtitle: Text(
                'Contact your Logistics provider for the next step.',
              ),
            ),
          ),
        if (run.events.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Run history', style: Theme.of(context).textTheme.titleMedium),
          ...run.events.map(
            (event) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.circle,
                size: 9,
                color: BearlyColors.brown700,
              ),
              title: Text(_statusLabel(event.type.replaceAll('_', ' '))),
              subtitle: Text(
                [
                  if (event.fromStatus != null || event.toStatus != null)
                    '${_statusLabel(event.fromStatus ?? '')} → ${_statusLabel(event.toStatus ?? '')}',
                  if (event.reason?.isNotEmpty == true) event.reason!,
                  if (event.occurredAt != null) _formatDate(event.occurredAt!),
                ].join(' · '),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38, color: BearlyColors.brown700),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
    return compact
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
            child: content,
          )
        : Center(
            child: Padding(padding: const EdgeInsets.all(24), child: content),
          );
  }
}

String _statusLabel(String status) => status
    .split(RegExp(r'[_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _confirmationText(String action) => switch (action) {
  'start_loading' =>
    'Confirm that you are at the origin facility and ready to load this manifest.',
  'loaded' =>
    'Confirm that all listed shipments and parcels are loaded. The server will verify the manifest is still at origin.',
  'depart' => 'Record that you are departing with the complete manifest.',
  'arrive' =>
    'Record arrival at the destination. This does not transfer custody or accept the Waybills.',
  _ => 'Confirm this run update.',
};

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _errorMessage(Object error) {
  if (error is ApiHttpException && error.responseData is Map) {
    final body = Map<String, Object?>.from(error.responseData as Map);
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) return message;
  }
  return 'Courier runs could not be loaded. Check your connection and retry.';
}
