import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_city_handoffs.dart';
import 'logistics_waybill_lookup_page.dart';

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
  final Set<int> _selectedShipmentIds = {};
  int? _selectedCourierId;
  bool _isAssigningManifest = false;
  String? _manifestError;
  LogisticsCityHandoffsPage? _prefetchedRuns;
  String? _prefetchedRunsSearch;

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
      _selectedShipmentIds.clear();
      _selectedCourierId = null;
      _manifestError = null;
      _prefetchedRuns = null;
      _request = _fetch(page: page);
    });
  }

  Future<void> _refresh() async {
    final next = _fetch(page: 1);
    setState(() {
      _page = 1;
      _selectedShipmentIds.clear();
      _selectedCourierId = null;
      _manifestError = null;
      _prefetchedRuns = null;
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
      _selectedShipmentIds.clear();
      _selectedCourierId = null;
      _manifestError = null;
      final cachedRuns =
          view == 'runs' &&
              _prefetchedRuns != null &&
              _prefetchedRunsSearch == _search.text
          ? _prefetchedRuns
          : null;
      _request = cachedRuns == null
          ? _fetch(page: 1)
          : Future.value(cachedRuns);
    });
  }

  List<LogisticsManifestCandidate> _selectedCandidates(
    LogisticsCityHandoffsPage page,
  ) => page.manifestShipments
      .where((shipment) => _selectedShipmentIds.contains(shipment.id))
      .toList(growable: false);

  int _parcelCount(List<LogisticsManifestCandidate> shipments) =>
      shipments.fold(0, (total, shipment) => total + shipment.parcelCount);

  LogisticsAvailableCourier? _courierById(
    List<LogisticsAvailableCourier> couriers,
    int? id,
  ) {
    for (final courier in couriers) {
      if (courier.id == id) return courier;
    }
    return null;
  }

  Future<void> _openHandoffAcceptance(LogisticsCityHandoff handoff) async {
    if (handoff.waybill.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LogisticsWaybillLookupPage(
          repository: widget.repository,
          initialIdentifier: handoff.waybill,
          handoffEnabled: true,
        ),
      ),
    );
    if (mounted) _reload(page: 1);
  }

  Future<void> _confirmManifestAssignment(
    LogisticsCityHandoffsPage page,
  ) async {
    final selected = _selectedCandidates(page);
    final courier = _courierById(page.availableCouriers, _selectedCourierId);
    final parcelCount = _parcelCount(selected);
    if (_isAssigningManifest ||
        selected.isEmpty ||
        courier == null ||
        parcelCount > courier.parcelCapacity) {
      return;
    }

    final destination = selected.first.destinationProviderName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign Courier manifest'),
        content: Text(
          'Assign ${selected.length} shipment(s) with $parcelCount parcel(s) '
          'for $destination to ${courier.name}? Cargo stays at the origin until the Courier records departure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-city-manifest-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Assign manifest'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() {
      _isAssigningManifest = true;
      _manifestError = null;
    });
    try {
      final run = await widget.repository.assignCityHandoffManifest(
        courierProfileId: courier.id,
        shipmentIds: selected.map((shipment) => shipment.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _selectedShipmentIds.clear();
        _selectedCourierId = null;
        _isAssigningManifest = false;
        _page = 1;
        _request = widget.repository.cityHandoffs(
          view: 'outgoing',
          status: _status,
          search: _search.text,
          page: 1,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Manifest ${run.runNo} assigned.')),
      );
      try {
        final refreshedRuns = await widget.repository.cityHandoffs(
          view: 'runs',
          status: 'active',
          search: _search.text,
          page: 1,
        );
        if (mounted && _search.text == (refreshedRuns.search ?? '')) {
          setState(() {
            _prefetchedRuns = refreshedRuns;
            _prefetchedRunsSearch = _search.text;
          });
        }
      } catch (_) {
        // Switching to Courier Runs performs a fresh request if prefetch fails.
      }
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      setState(() => _manifestError = _assignmentError(error));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _manifestError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _manifestError =
              'The manifest could not be assigned. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigningManifest = false);
    }
  }

  String _assignmentError(ApiHttpException error) {
    final body = error.responseData;
    if (body is Map && body['message'] is String) {
      final message = (body['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    String? details;
    for (final messages in error.validationErrors.values) {
      if (messages.isNotEmpty) {
        details = messages.first;
        break;
      }
    }
    if (details != null && details.isNotEmpty) return details;
    return switch (error.statusCode) {
      401 => 'Your session expired. Sign in again to assign a manifest.',
      403 => 'This Logistics account is not eligible to assign manifests.',
      404 => 'A selected shipment or Courier is no longer available.',
      409 =>
        'Shipment or Courier eligibility changed. Refresh and review the manifest.',
      422 => 'Review the selected shipments and Courier, then try again.',
      429 => 'Too many assignment requests. Wait and try again.',
      _ => 'The server could not assign this manifest. Try again shortly.',
    };
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
              AbsorbPointer(
                absorbing: _isAssigningManifest,
                child: _viewSelector(scrollable: scrollTabs),
              ),
              const SizedBox(height: 8),
              if (stackFilters)
                Column(
                  children: [
                    AbsorbPointer(
                      absorbing: _isAssigningManifest,
                      child: _statusFilter(),
                    ),
                    const SizedBox(height: 8),
                    _searchFilter(),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AbsorbPointer(
                        absorbing: _isAssigningManifest,
                        child: _statusFilter(),
                      ),
                    ),
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
    enabled: !_isAssigningManifest,
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

    if (page.view == 'outgoing') {
      widgets.add(_manifestAssignmentCard(page));
    }

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
        if (handoff.direction == 'incoming' &&
            handoff.status == 'sent' &&
            handoff.acceptanceEligibility?.eligible == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('logistics-city-handoff-accept-${handoff.id}'),
                onPressed: () => _openHandoffAcceptance(handoff),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Review and accept handoff'),
              ),
            ),
          ),
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

  Widget _manifestAssignmentCard(LogisticsCityHandoffsPage page) {
    final selected = _selectedCandidates(page);
    final destinationId = selected.isEmpty
        ? null
        : selected.first.destinationProviderId;
    final destinationName = selected.isEmpty
        ? null
        : selected.first.destinationProviderName;
    final parcelCount = _parcelCount(selected);
    final courier = _courierById(page.availableCouriers, _selectedCourierId);
    final canAssign =
        selected.isNotEmpty &&
        courier != null &&
        courier.parcelCapacity >= parcelCount &&
        !_isAssigningManifest;

    return Card(
      key: const ValueKey('logistics-city-manifest-assignment'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready for Courier manifest',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Select fully received shipments for one destination. The server rechecks eligibility and Courier capacity before assignment.',
            ),
            const SizedBox(height: 10),
            Text(
              'Currently available verified Couriers',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Courier availability is advisory; the server rechecks each Courier’s eligibility and capacity when assigning.',
            ),
            if (page.availableCouriers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: page.availableCouriers
                    .map(
                      (option) => Chip(
                        avatar: const Icon(Icons.local_shipping_outlined),
                        label: Text(option.name),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (destinationName != null) ...[
              const SizedBox(height: 8),
              Text('Selected destination: $destinationName'),
            ],
            if (page.manifestShipments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No fully received cross-city shipments are currently ready for a manifest.',
                ),
              )
            else ...[
              const SizedBox(height: 8),
              ...page.manifestShipments.map((shipment) {
                final isSelected = _selectedShipmentIds.contains(shipment.id);
                final otherDestinationSelected =
                    destinationId != null &&
                    shipment.destinationProviderId != destinationId &&
                    !isSelected;
                return CheckboxListTile(
                  key: ValueKey(
                    'logistics-city-manifest-shipment-${shipment.id}',
                  ),
                  value: isSelected,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: _isAssigningManifest || otherDestinationSelected
                      ? null
                      : (checked) => setState(() {
                          if (checked == true) {
                            _selectedShipmentIds.add(shipment.id);
                          } else {
                            _selectedShipmentIds.remove(shipment.id);
                          }
                          final currentCourier = _courierById(
                            page.availableCouriers,
                            _selectedCourierId,
                          );
                          if (currentCourier != null &&
                              currentCourier.parcelCapacity <
                                  _parcelCount(_selectedCandidates(page))) {
                            _selectedCourierId = null;
                          }
                          _manifestError = null;
                        }),
                  title: Text(shipment.waybill),
                  subtitle: Text(
                    '${shipment.reference} · ${shipment.destinationProviderName}'
                    '${shipment.destinationLabel.isEmpty ? '' : ' · ${shipment.destinationLabel}'}\n'
                    '${shipment.parcelCount} parcel(s): ${shipment.parcels.map((parcel) => parcel.reference).join(', ')}',
                  ),
                );
              }),
              if (page.manifestPagination.total >
                  page.manifestPagination.perPage)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${page.manifestPagination.total} ready · page ${page.manifestPagination.currentPage} of ${page.manifestPagination.lastPage}',
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('logistics-city-manifest-next'),
                      tooltip: 'More ready shipments',
                      onPressed: page.manifestPagination.hasNext
                          ? () => _reload(
                              page: page.manifestPagination.currentPage + 1,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                'Selected: ${selected.length} shipment(s), $parcelCount parcel(s)',
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: const ValueKey('logistics-city-manifest-courier'),
                initialValue: _selectedCourierId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Courier',
                  border: OutlineInputBorder(),
                ),
                items: page.availableCouriers
                    .map(
                      (option) => DropdownMenuItem<int>(
                        value: option.id,
                        enabled:
                            option.id > 0 &&
                            option.parcelCapacity >= parcelCount,
                        child: Text(
                          '${option.name} · ${option.vehicleType} · ${option.parcelCapacity} parcel capacity',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    _isAssigningManifest || page.availableCouriers.isEmpty
                    ? null
                    : (value) => setState(() {
                        _selectedCourierId = value;
                        _manifestError = null;
                      }),
              ),
              if (page.availableCouriers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No currently eligible Courier is available. Eligibility is checked again when assigning.',
                  ),
                ),
            ],
            if (_manifestError != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('logistics-city-manifest-error'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_manifestError!),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('logistics-city-manifest-submit'),
                onPressed: canAssign
                    ? () => _confirmManifestAssignment(page)
                    : null,
                icon: _isAssigningManifest
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.assignment_ind_outlined),
                label: Text(
                  _isAssigningManifest ? 'Assigning…' : 'Assign manifest',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
