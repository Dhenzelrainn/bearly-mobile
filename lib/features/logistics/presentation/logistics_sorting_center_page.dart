import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_dispatch.dart';
import '../models/logistics_sorting_workspace.dart';

class LogisticsSortingCenterPage extends StatefulWidget {
  const LogisticsSortingCenterPage({
    super.key,
    required this.repository,
    this.onOpenSortingQueue,
    this.onOpenDispatchBoard,
  });

  final LogisticsRepository repository;
  final Future<void> Function()? onOpenSortingQueue;
  final Future<void> Function()? onOpenDispatchBoard;

  @override
  State<LogisticsSortingCenterPage> createState() =>
      _LogisticsSortingCenterPageState();
}

class _LogisticsSortingCenterPageState
    extends State<LogisticsSortingCenterPage> {
  final _searchController = TextEditingController();
  late Future<LogisticsSortingWorkspace> _workspace;
  String _status = 'awaiting_sorting';
  String _searchTerm = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _workspace = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<LogisticsSortingWorkspace> _load() =>
      widget.repository.sortingCenterWorkspace(
        status: _status,
        search: _searchTerm,
        page: _page,
      );

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _workspace = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder keeps the error and retry control visible.
    }
  }

  Future<void> _changeStatus(String? status) async {
    if (status == null || status == _status) return;
    setState(() {
      _status = status;
      _page = 1;
    });
    await _refresh();
  }

  Future<void> _submitSearch() async {
    setState(() {
      _searchTerm = _searchController.text.trim();
      _page = 1;
    });
    await _refresh();
  }

  Future<void> _movePage(int page) async {
    setState(() => _page = page);
    await _refresh();
  }

  Future<void> _openOperationalScreen(
    Future<void> Function()? openScreen,
  ) async {
    if (openScreen == null) return;
    await openScreen();
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sorting Center'),
      actions: [
        IconButton(
          key: const ValueKey('logistics-refresh-sorting-center'),
          onPressed: _refresh,
          tooltip: 'Refresh Sorting Center',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsSortingWorkspace>(
      future: _workspace,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _error(snapshot.error!);
        final workspace = snapshot.data;
        if (workspace == null) {
          return _error(const FormatException('Sorting Center unavailable.'));
        }
        return _workspaceBody(workspace);
      },
    ),
  );

  Widget _error(Object error) {
    final denied =
        error is ApiHttpException &&
        (error.statusCode == 401 || error.statusCode == 403);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              denied ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'Your Logistics account does not have an active Sorting Center assigned.'
                  : 'Could not load the Sorting Center. Check your connection and retry.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
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

  Widget _workspaceBody(LogisticsSortingWorkspace workspace) {
    if (workspace.setupRequired || workspace.sortingCenter == null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.warehouse_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              workspace.setupMessage ??
                  'An active Sorting Center must be assigned before parcel sorting can be viewed.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final center = workspace.sortingCenter!;
    final dispatchReadiness = workspace.dispatchReadiness;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.warehouse_outlined),
              ),
              title: Text(center.name),
              subtitle: Text('${center.code} · ${center.address}'),
              trailing: _statusChip(center.status),
            ),
          ),
          _operationalLinks(),
          _metrics(workspace.metrics),
          _zones(workspace.zones),
          if (dispatchReadiness != null) _dispatchReadiness(dispatchReadiness),
          const SizedBox(height: 12),
          Text('Parcel records', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const ValueKey('sorting-center-status-filter'),
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'awaiting_sorting',
                child: Text('Awaiting Sorting'),
              ),
              DropdownMenuItem(value: 'sorted', child: Text('Sorted')),
              DropdownMenuItem(value: 'exceptions', child: Text('Exceptions')),
              DropdownMenuItem(value: 'all', child: Text('All center records')),
            ],
            onChanged: _changeStatus,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('sorting-center-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: const InputDecoration(
                    labelText:
                        'Search Parcel, Waybill, shipment or destination',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('sorting-center-search-submit'),
                onPressed: _submitSearch,
                tooltip: 'Search parcels',
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (workspace.parcels.isEmpty)
            _emptyState(workspace.statusFilter)
          else ...[
            for (final parcel in workspace.parcels) _parcelCard(parcel),
            _pagination(workspace.pagination),
          ],
        ],
      ),
    );
  }

  Widget _operationalLinks() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue operations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Sorting and dispatch actions stay in their existing workflows.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('sorting-center-open-queue'),
              onPressed: widget.onOpenSortingQueue == null
                  ? null
                  : () => _openOperationalScreen(widget.onOpenSortingQueue),
              icon: const Icon(Icons.sort_rounded),
              label: const Text('Open Sorting Queue'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('sorting-center-open-dispatch'),
              onPressed: widget.onOpenDispatchBoard == null
                  ? null
                  : () => _openOperationalScreen(widget.onOpenDispatchBoard),
              icon: const Icon(Icons.outbox_outlined),
              label: const Text('Open Dispatch Board'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _metrics(LogisticsSortingWorkspaceMetrics metrics) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metricChip('Awaiting', metrics.awaitingSorting),
        _metricChip('Sorted', metrics.sorted),
        _metricChip('Exceptions', metrics.exceptions),
      ],
    ),
  );

  Widget _metricChip(String label, int count) => Chip(
    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
    label: Text('$label · $count'),
  );

  Widget _zones(List<LogisticsSortingWorkspaceZone> zones) => Card(
    child: ExpansionTile(
      key: const ValueKey('sorting-center-zones'),
      title: Text('Provider zones (${zones.length})'),
      children: zones.isEmpty
          ? const [
              ListTile(title: Text('No zones are configured at this center.')),
            ]
          : zones
                .map(
                  (zone) => ListTile(
                    dense: true,
                    title: Text('${zone.code} · ${zone.name}'),
                    subtitle: Text(zone.coverage),
                    trailing: _statusChip(zone.status),
                  ),
                )
                .toList(growable: false),
    ),
  );

  Widget _dispatchReadiness(LogisticsDispatchBoard board) => Card(
    child: ExpansionTile(
      key: const ValueKey('sorting-center-dispatch-readiness'),
      title: const Text('Dispatch readiness'),
      subtitle: const Text(
        'Read-only eligibility from current parcel and Rider state',
      ),
      children: board.zones.isEmpty
          ? const [
              ListTile(title: Text('No active delivery zones are available.')),
            ]
          : board.zones.map(_dispatchZone).toList(growable: false),
    ),
  );

  Widget _dispatchZone(LogisticsDispatchZone zone) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${zone.code} · ${zone.name}'),
          subtitle: Text(
            '${zone.readyCount} ready parcels · ${zone.routingIssues} routing issues',
          ),
        ),
        if (zone.riders.isNotEmpty)
          Text(
            'Same-zone eligible: ${zone.riders.map((rider) => '${rider.name} (${rider.remaining} slots)').join(', ')}',
          )
        else if (zone.readyCount > 0)
          const Text(
            'No same-zone Local Rider currently has capacity for the full zone batch.',
          ),
        if (zone.nearbyRiders.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Other-zone Local Rider candidates: ${zone.nearbyRiders.map((rider) => '${rider.name} · ${rider.zoneCode} · ${rider.remaining} slots${rider.distanceLabel == null ? '' : ' · ${rider.distanceLabel}'} · ${rider.gpsStatusLabel}${rider.recommended ? ' · closest estimate' : ''}').join('; ')}',
          ),
        ],
        if (zone.proximityMessage?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              zone.proximityMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
            ),
          ),
        const Divider(height: 18),
      ],
    ),
  );

  Widget _parcelCard(LogisticsSortingWorkspaceParcel parcel) => Card(
    key: ValueKey('sorting-center-parcel-${parcel.id}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  parcel.waybill,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _statusChip(parcel.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Parcel ${parcel.reference} · Piece ${parcel.pieceSequence} of ${parcel.pieceCount}',
          ),
          Text(
            'Shipment ${parcel.shipmentReference} · ${_purposeLabel(parcel.purpose)}',
          ),
          const SizedBox(height: 4),
          Text(
            parcel.destination.isEmpty
                ? 'Destination unavailable'
                : parcel.destination,
          ),
          Text(
            parcel.currentZone == null
                ? 'Current zone: not assigned'
                : 'Current zone: ${parcel.currentZone!.code} · ${parcel.currentZone!.name}',
          ),
          if (parcel.pieceCount > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Waybill pieces',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final piece in parcel.pieces)
              Text(
                '${piece.sequence}. ${piece.reference} · ${piece.status}${piece.currentZone == null ? '' : ' · ${piece.currentZone}'}',
              ),
          ],
          if (parcel.products.isNotEmpty) ...[
            const Divider(height: 22),
            for (final product in parcel.products)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ProductThumbnail(
                  imageUrl: product.imageUrl,
                  size: 48,
                  semanticLabel: product.name,
                ),
                title: Text(
                  product.name.isEmpty ? 'Purchased item' : product.name,
                ),
                subtitle: Text(
                  [
                    if (product.variant.isNotEmpty) product.variant,
                    'Qty ${product.quantity}',
                  ].join(' · '),
                ),
              ),
          ],
          if (parcel.matchingZones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Matching active zones',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final zone in parcel.matchingZones)
              Text('${zone.code} · ${zone.name} — ${zone.coverage}'),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No active zone currently covers this destination.'),
            ),
          if (parcel.sortingHistory.isNotEmpty)
            ExpansionTile(
              key: ValueKey('sorting-history-${parcel.id}'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Sorting history'),
              children: parcel.sortingHistory
                  .map(
                    (event) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(_eventLabel(event.event)),
                      subtitle: Text(
                        [
                          if (event.fromStatus?.isNotEmpty == true)
                            '${event.fromStatus} → ${event.toStatus ?? ''}',
                          if (event.sortingZone?.isNotEmpty == true)
                            'Zone ${event.sortingZone}',
                          if (event.sortingCenter?.isNotEmpty == true)
                            'Center ${event.sortingCenter}',
                          if (event.occurredAt != null)
                            _dateTime(event.occurredAt!),
                        ].join(' · '),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    ),
  );

  Widget _pagination(LogisticsSortingWorkspacePagination page) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Page ${page.currentPage} of ${page.lastPage} · ${page.total} parcels',
        ),
        Row(
          children: [
            IconButton(
              key: const ValueKey('sorting-center-previous-page'),
              onPressed: page.currentPage > 1
                  ? () => _movePage(page.currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous page',
            ),
            IconButton(
              key: const ValueKey('sorting-center-next-page'),
              onPressed: page.hasMorePages
                  ? () => _movePage(page.currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Next page',
            ),
          ],
        ),
      ],
    ),
  );

  Widget _emptyState(String status) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        _searchTerm.isNotEmpty
            ? 'No center parcels match this search.'
            : switch (status) {
                'sorted' => 'No sorted parcels are recorded at this center.',
                'exceptions' =>
                  'No sorting exception parcels are recorded at this center.',
                'all' => 'No sorting records are available at this center.',
                _ => 'No received parcels are waiting at this center.',
              },
      ),
    ),
  );

  Widget _statusChip(String status) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(status.replaceAll('_', ' ')),
  );

  String _purposeLabel(String purpose) => switch (purpose) {
    'return' => 'Return to Seller',
    'outbound' => 'Buyer delivery',
    '' => 'Shipment',
    _ => purpose.replaceAll('_', ' '),
  };

  String _eventLabel(String event) => event
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }
}
