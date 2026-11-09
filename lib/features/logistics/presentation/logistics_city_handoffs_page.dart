import 'package:flutter/material.dart';

import '../data/logistics_repository.dart';
import '../models/logistics_city_handoffs.dart';

class LogisticsCityHandoffsWorkspacePage extends StatefulWidget {
  const LogisticsCityHandoffsWorkspacePage({
    super.key,
    required this.repository,
  });

  final LogisticsRepository repository;

  @override
  State<LogisticsCityHandoffsWorkspacePage> createState() =>
      _LogisticsCityHandoffsPageState();
}

class _LogisticsCityHandoffsPageState
    extends State<LogisticsCityHandoffsWorkspacePage> {
  late Future<LogisticsCityHandoffsPage> _request;
  final TextEditingController _search = TextEditingController();
  String _view = 'incoming';
  String _status = 'sent';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _request = _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<LogisticsCityHandoffsPage> _fetch({int? page}) =>
      widget.repository.cityHandoffs(
        view: _view,
        status: _status,
        search: _search.text,
        page: page ?? _page,
      );

  void _reload({int page = 1}) {
    setState(() {
      _page = page;
      _request = _fetch(page: page);
    });
  }

  Future<void> _refresh() async {
    final next = _fetch(page: 1);
    setState(() {
      _page = 1;
      _request = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder keeps the error state visible with a retry action.
    }
  }

  void _selectView(String view) {
    if (view == _view) return;
    setState(() {
      _view = view;
      _status = view == 'runs' ? 'active' : 'sent';
      _page = 1;
      _request = _fetch(page: 1);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('City Handoffs')),
    body: Column(
      children: [
        _filters(),
        Expanded(
          child: FutureBuilder<LogisticsCityHandoffsPage>(
            future: _request,
            builder: (context, snapshot) => RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const ValueKey('logistics-city-handoffs-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _errorState()
                  else if (snapshot.hasData)
                    ..._content(snapshot.data!),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _filters() => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaledLabelSize = MediaQuery.textScalerOf(context).scale(16);
          final stackFilters =
              constraints.maxWidth < 400 || scaledLabelSize >= 19.2;
          final scrollTabs =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(14) > 16.8;

          return Column(
            children: [
              _viewSelector(scrollable: scrollTabs),
              const SizedBox(height: 8),
              if (stackFilters)
                Column(
                  children: [
                    _statusFilter(),
                    const SizedBox(height: 8),
                    _searchFilter(),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(flex: 2, child: _statusFilter()),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: _searchFilter()),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _viewSelector({required bool scrollable}) {
    const views = [
      (value: 'incoming', label: 'Incoming'),
      (value: 'outgoing', label: 'Outgoing'),
      (value: 'runs', label: 'Courier Runs'),
    ];

    if (scrollable) {
      return SingleChildScrollView(
        key: const ValueKey('logistics-city-handoffs-view-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final view in views)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('logistics-city-handoffs-tab-${view.value}'),
                  label: Text(view.label),
                  selected: _view == view.value,
                  showCheckmark: false,
                  onSelected: (_) => _selectView(view.value),
                ),
              ),
          ],
        ),
      );
    }

    return SegmentedButton<String>(
      key: const ValueKey('logistics-city-handoffs-view'),
      showSelectedIcon: false,
      segments: [
        for (final view in views)
          ButtonSegment(value: view.value, label: Text(view.label)),
      ],
      selected: {_view},
      onSelectionChanged: (selection) => _selectView(selection.first),
    );
  }

  Widget _statusFilter() => DropdownButtonFormField<String>(
    key: ValueKey('logistics-city-handoffs-status-$_view'),
    initialValue: _status,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Status',
      border: OutlineInputBorder(),
      isDense: true,
    ),
    items: _statusOptions()
        .map(
          (status) =>
              DropdownMenuItem(value: status, child: Text(_statusName(status))),
        )
        .toList(growable: false),
    onChanged: (value) {
      if (value == null) return;
      setState(() => _status = value);
      _reload();
    },
  );

  Widget _searchFilter() => TextField(
    key: const ValueKey('logistics-city-handoffs-search'),
    controller: _search,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => _reload(),
    decoration: InputDecoration(
      labelText: 'Search Waybill or run',
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: IconButton(
        tooltip: 'Search City Handoffs',
        onPressed: _reload,
        icon: const Icon(Icons.search),
      ),
    ),
  );

  List<String> _statusOptions() => _view == 'runs'
      ? const ['active', 'completed', 'all']
      : const ['sent', 'accepted', 'all'];

  List<Widget> _content(LogisticsCityHandoffsPage page) {
    final widgets = <Widget>[
      Text(
        page.providerName,
        key: const ValueKey('logistics-city-handoffs-provider'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        page.activeCenterName == null
            ? 'No active Sorting Center is configured.'
            : 'Active Sorting Center: ${page.activeCenterName}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
    ];

    if (page.view == 'runs') {
      if (page.runs.isEmpty) {
        widgets.add(_emptyState('No Courier runs match these filters.'));
      } else {
        widgets.addAll(page.runs.map(_runCard));
      }
    } else if (page.items.isEmpty) {
      widgets.add(
        _emptyState(
          page.view == 'incoming'
              ? 'No incoming City Handoffs match these filters.'
              : 'No outgoing City Handoffs match these filters.',
        ),
      );
    } else {
      widgets.addAll(page.items.map(_handoffCard));
    }

    if (page.view == 'outgoing' && page.availableCouriers.isNotEmpty) {
      widgets.add(_availableCouriers(page.availableCouriers));
    }
    if (page.pagination.total > 0) {
      widgets.add(_pagination(page.pagination));
    }
    return widgets;
  }

  Widget _handoffCard(LogisticsCityHandoff handoff) => Card(
    key: ValueKey('logistics-city-handoff-${handoff.id}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: Column(
      children: [
        ListTile(
          title: Text(
            handoff.waybill.isEmpty
                ? handoff.shipmentReference
                : handoff.waybill,
          ),
          subtitle: Text(
            '${handoff.origin.providerName}  →  ${handoff.destination.providerName}\n'
            '${_statusName(handoff.stage)} · ${handoff.parcelCount} parcel(s)',
          ),
          isThreeLine: true,
          trailing: _statusChip(handoff.status),
        ),
        if (handoff.run != null)
          ListTile(
            dense: true,
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text(
              '${handoff.run!.runNo} · ${_statusName(handoff.run!.status)}',
            ),
            subtitle: Text('Courier: ${handoff.run!.courierName}'),
          ),
        if (handoff.acceptanceEligibility != null)
          _eligibility(handoff.acceptanceEligibility!),
        ExpansionTile(
          key: ValueKey('logistics-city-handoff-details-${handoff.id}'),
          title: const Text('Waybill, parcels and history'),
          subtitle: Text(
            '${handoff.shipmentReference} · ${_statusName(handoff.purpose)}',
          ),
          children: [
            if (handoff.origin.sortingCenterName != null)
              _detail('Origin center', handoff.origin.sortingCenterName!),
            if (handoff.destination.sortingCenterName != null)
              _detail(
                'Destination center',
                handoff.destination.sortingCenterName!,
              ),
            ...handoff.parcels.map(
              (parcel) => _detail(
                parcel.reference,
                '${_statusName(parcel.status)}${parcel.currentCenter == null ? '' : ' · ${parcel.currentCenter}'}',
              ),
            ),
            _detail('Sent', _date(handoff.sentAt)),
            if (handoff.acceptedAt != null)
              _detail('Accepted', _date(handoff.acceptedAt)),
            ...handoff.history.map(_historyTile),
          ],
        ),
      ],
    ),
  );

  Widget _runCard(LogisticsCityRun run) => Card(
    key: ValueKey('logistics-city-run-${run.id}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      initiallyExpanded: false,
      title: Text(run.runNo),
      subtitle: Text(
        '${run.origin.providerName}  →  ${run.destination.providerName}\n'
        '${run.courier.name} · ${run.statusLabel} · ${run.shipmentCount} shipment(s) · ${run.parcelCount} parcel(s)',
      ),
      trailing: _statusChip(run.status),
      children: [
        if (run.origin.sortingCenterName != null)
          _detail('Origin center', run.origin.sortingCenterName!),
        _detail('Courier work type', run.courier.workType ?? 'Unknown'),
        if (run.courier.vehicleType != null)
          _detail('Vehicle', run.courier.vehicleType!),
        if (run.courier.parcelCapacity != null)
          _detail('Verified parcel capacity', '${run.courier.parcelCapacity}'),
        _detail('Assigned', _date(run.assignedAt)),
        if (run.loadedAt != null) _detail('Cargo loaded', _date(run.loadedAt)),
        if (run.departedAt != null) _detail('Departed', _date(run.departedAt)),
        if (run.arrivedAt != null) _detail('Arrived', _date(run.arrivedAt)),
        if (run.completedAt != null)
          _detail('Completed', _date(run.completedAt)),
        const Divider(),
        for (final shipment in run.shipments)
          ExpansionTile(
            key: ValueKey(
              'logistics-city-run-shipment-${run.id}-${shipment.reference}',
            ),
            title: Text(
              shipment.waybill.isEmpty ? shipment.reference : shipment.waybill,
            ),
            subtitle: Text(
              '${_statusName(shipment.status)} · ${shipment.parcels.length} parcel(s)'
              '${shipment.handoffStatus == null ? '' : ' · handoff ${_statusName(shipment.handoffStatus!)}'}',
            ),
            children: shipment.parcels
                .map(
                  (parcel) =>
                      _detail(parcel.reference, _statusName(parcel.status)),
                )
                .toList(growable: false),
          ),
        const Divider(),
        ...run.history.map(_historyTile),
      ],
    ),
  );

  Widget _availableCouriers(List<LogisticsAvailableCourier> couriers) => Card(
    key: const ValueKey('logistics-city-handoffs-available-couriers'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currently available verified Couriers',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'The Web manifest workflow rechecks each Courier and the selected parcel capacity before assignment.',
          ),
          const SizedBox(height: 8),
          ...couriers.map(
            (courier) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(courier.name),
              subtitle: Text(
                '${courier.vehicleType} · ${courier.parcelCapacity} parcel capacity',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _eligibility(LogisticsCityAcceptanceEligibility eligibility) =>
      Container(
        key: const ValueKey('logistics-city-handoff-acceptance-eligibility'),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: eligibility.eligible
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(eligibility.message),
      );

  Widget _historyTile(LogisticsCityHistoryEvent event) => ListTile(
    dense: true,
    leading: const Icon(Icons.history),
    title: Text(_statusName(event.event)),
    subtitle: Text(
      [
        if (event.fromStatus != null || event.toStatus != null)
          '${event.fromStatus == null ? '' : _statusName(event.fromStatus!)}'
              '${event.fromStatus != null && event.toStatus != null ? ' → ' : ''}'
              '${event.toStatus == null ? '' : _statusName(event.toStatus!)}',
        if (event.actor != null) event.actor!,
        _date(event.occurredAt),
      ].where((value) => value.isNotEmpty).join(' · '),
    ),
  );

  Widget _detail(String label, String value) =>
      ListTile(dense: true, title: Text(label), subtitle: Text(value));

  Widget _pagination(LogisticsCityHandoffsPagination pagination) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 4,
      children: [
        Text(
          '${pagination.total} records · page ${pagination.currentPage} of ${pagination.lastPage}',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('logistics-city-handoffs-previous'),
              tooltip: 'Previous page',
              onPressed: pagination.hasPrevious
                  ? () => _reload(page: pagination.currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const ValueKey('logistics-city-handoffs-next'),
              tooltip: 'Next page',
              onPressed: pagination.hasNext
                  ? () => _reload(page: pagination.currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statusChip(String status) => Chip(label: Text(_statusName(status)));

  Widget _emptyState(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 52),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 44),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _errorState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(Icons.error_outline, size: 42),
        const SizedBox(height: 8),
        const Text('City Handoffs could not be loaded.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('logistics-city-handoffs-retry'),
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  static String _statusName(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static String _date(DateTime? value) {
    if (value == null) return 'Not recorded';
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour:$minute $period';
  }
}
