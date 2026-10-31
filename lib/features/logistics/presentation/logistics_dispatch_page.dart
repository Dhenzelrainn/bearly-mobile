import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_dispatch.dart';

class LogisticsDispatchPage extends StatefulWidget {
  const LogisticsDispatchPage({super.key, required this.repository});

  final LogisticsRepository repository;

  @override
  State<LogisticsDispatchPage> createState() => _LogisticsDispatchPageState();
}

class _LogisticsDispatchPageState extends State<LogisticsDispatchPage> {
  late Future<LogisticsDispatchBoard> _board;
  final Map<int, int?> _selectedRiders = {};
  int? _submittingZoneId;
  bool _needsReconciliation = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _board = widget.repository.dispatchBoard();
  }

  Future<void> _refresh() async {
    final next = widget.repository.dispatchBoard();
    setState(() {
      _board = next;
      _error = null;
    });
    try {
      await next;
      if (!mounted) return;
      setState(() => _needsReconciliation = false);
    } catch (_) {
      // Keep dispatch blocked after an uncertain POST until a fresh read works.
    }
  }

  Future<void> _confirmDispatch(LogisticsDispatchZone zone) async {
    final riderId = _selectedRiders[zone.id];
    final rider = zone.riders
        .where((candidate) => candidate.id == riderId)
        .firstOrNull;
    if (rider == null ||
        zone.readyCount != zone.parcels.length ||
        _submittingZoneId != null ||
        _needsReconciliation) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('logistics-dispatch-confirm-dialog'),
        scrollable: true,
        title: const Text('Review delivery dispatch'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dispatch all ${zone.readyCount} ready parcel(s) in ${zone.code} to:',
            ),
            const SizedBox(height: 8),
            Text(rider.name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Text('Waybills', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ...zone.parcels.map(
              (parcel) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(parcel.waybill, softWrap: true),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-confirm-dispatch'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dispatch parcels'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submittingZoneId = zone.id;
      _error = null;
      _message = null;
    });

    try {
      final result = await widget.repository.dispatchZone(
        zoneId: zone.id,
        riderProfileId: rider.id,
      );
      if (!mounted) return;
      setState(() {
        _message =
            'Server confirmed ${result.batchReference}: ${result.parcels.length} parcel(s) dispatched to ${result.riderName}.';
        _selectedRiders.remove(zone.id);
        _board = Future.value(result.refreshedBoard);
        _needsReconciliation = false;
      });

      // Read once more after the server confirmation so the visible board is
      // current even if other dispatch activity happened concurrently.
      final refreshed = widget.repository.dispatchBoard();
      setState(() => _board = refreshed);
      try {
        await refreshed;
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Dispatch was confirmed as ${result.batchReference}, but the board could not refresh. Use Refresh before dispatching again.',
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      final uncertain = _isUncertain(error);
      setState(() {
        _needsReconciliation = uncertain;
        _error = uncertain
            ? 'The dispatch result is uncertain. Refresh the board from the server before trying again.'
            : _requestMessage(error);
      });
    } finally {
      if (mounted) setState(() => _submittingZoneId = null);
    }
  }

  bool _isUncertain(Object error) =>
      error is ApiTimeoutException ||
      error is ApiTransportException ||
      error is ApiFormatException ||
      error is FormatException ||
      (error is ApiHttpException && error.statusCode >= 500) ||
      (error is AuthSessionChangedException &&
          error.requestMayHaveReachedServer);

  String _requestMessage(Object error) {
    if (error is ApiHttpException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'This Logistics account is no longer authorized to dispatch.';
      }
      if (error.statusCode == 404) {
        return 'The Sorting Zone or Rider is no longer available. Refresh the board.';
      }
      if (error.statusCode == 409) {
        return 'The dispatch is no longer eligible because parcel, zone, or Rider state changed. Refresh the board.';
      }
      final validation = error.validationErrors.values
          .expand((messages) => messages)
          .firstOrNull;
      if (validation != null && validation.isNotEmpty) return validation;
    }
    return 'Could not dispatch these parcels. Check the board and try again.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Delivery Dispatch'),
      actions: [
        IconButton(
          onPressed: _submittingZoneId == null ? _refresh : null,
          tooltip: 'Refresh dispatch board',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsDispatchBoard>(
      future: _board,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final unauthorized =
              snapshot.error is ApiHttpException &&
              ((snapshot.error! as ApiHttpException).statusCode == 401 ||
                  (snapshot.error! as ApiHttpException).statusCode == 403);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_message != null) ...[
                    Text(_message!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                  ],
                  Icon(
                    unauthorized
                        ? Icons.lock_outline
                        : Icons.cloud_off_outlined,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error ??
                        (unauthorized
                            ? 'Your Logistics account is not authorized to view delivery dispatch.'
                            : 'Could not load the delivery dispatch board. Check your connection and retry.'),
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final board = snapshot.data;
        if (board == null) {
          return const Center(
            child: Text('The dispatch board is unavailable.'),
          );
        }
        return _boardBody(board);
      },
    ),
  );

  Widget _boardBody(LogisticsDispatchBoard board) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(board.providerName, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${board.sortingCenter.name} · ${board.sortingCenter.code}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          _notice(_message!, isError: false),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _notice(_error!, isError: true),
          if (_needsReconciliation)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                key: const ValueKey(
                  'logistics-refresh-after-uncertain-dispatch',
                ),
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh from server'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (board.zones.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No sorted parcels are ready for delivery dispatch.'),
            ),
          )
        else
          ...board.zones.map(_zoneCard),
      ],
    ),
  );

  Widget _zoneCard(LogisticsDispatchZone zone) {
    final selectedRider = zone.riders
        .where((rider) => rider.id == _selectedRiders[zone.id])
        .firstOrNull;

    return Card(
      key: ValueKey('logistics-dispatch-zone-card-${zone.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${zone.code} · ${zone.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${zone.readyCount} ready parcel(s) · ${zone.coverage}'),
            if (zone.routingIssues > 0)
              Text(
                '${zone.routingIssues} sorted parcel(s) do not match this zone.',
              ),
            const SizedBox(height: 8),
            ...zone.parcels.map(
              (parcel) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.local_shipping_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(parcel.waybill, softWrap: true),
                          const SizedBox(height: 2),
                          Text(
                            '${parcel.reference} · ${parcel.shipmentReference} · ${parcel.status}',
                            softWrap: true,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (zone.riders.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No eligible Rider has capacity for this entire zone batch.',
                ),
              )
            else ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: ValueKey('logistics-dispatch-rider-${zone.id}'),
                initialValue: _selectedRiders[zone.id],
                isExpanded: true,
                itemHeight: null,
                selectedItemBuilder: (context) => zone.riders
                    .map(
                      (rider) => Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: rider.name,
                          child: Text(
                            rider.name,
                            key: ValueKey(
                              'logistics-dispatch-rider-name-${zone.id}-${rider.id}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            semanticsLabel: rider.name,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
                decoration: const InputDecoration(
                  labelText: 'Eligible Rider',
                  border: OutlineInputBorder(),
                ),
                items: zone.riders
                    .map(
                      (rider) => DropdownMenuItem<int>(
                        value: rider.id,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 176,
                          ),
                          child: Text(
                            '${rider.name} · ${rider.remaining} of ${rider.capacity} capacity available',
                            softWrap: true,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _submittingZoneId == null && !_needsReconciliation
                    ? (value) =>
                          setState(() => _selectedRiders[zone.id] = value)
                    : null,
              ),
              if (selectedRider != null) ...[
                const SizedBox(height: 4),
                Padding(
                  key: ValueKey('logistics-dispatch-rider-capacity-${zone.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${selectedRider.remaining} of ${selectedRider.capacity} capacity available',
                    softWrap: true,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('logistics-dispatch-zone-${zone.id}'),
                  onPressed:
                      _selectedRiders[zone.id] != null &&
                          _submittingZoneId == null &&
                          !_needsReconciliation &&
                          zone.readyCount == zone.parcels.length
                      ? () => _confirmDispatch(zone)
                      : null,
                  icon: _submittingZoneId == zone.id
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.outbox_outlined),
                  label: Text(
                    _submittingZoneId == zone.id
                        ? 'Dispatching…'
                        : 'Review dispatch',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notice(String text, {required bool isError}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? Colors.red.shade50 : Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: isError ? Colors.red.shade900 : Colors.green.shade900,
      ),
    ),
  );
}

extension _DispatchFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
