import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_rider.dart';

enum _RiderFilter { all, local, courier }

class LogisticsRidersPage extends StatefulWidget {
  const LogisticsRidersPage({super.key, required this.repository});

  final LogisticsRepository repository;

  @override
  State<LogisticsRidersPage> createState() => _LogisticsRidersPageState();
}

class _LogisticsRidersPageState extends State<LogisticsRidersPage> {
  late Future<List<LogisticsRider>> _riders;
  _RiderFilter _filter = _RiderFilter.all;

  @override
  void initState() {
    super.initState();
    _riders = widget.repository.riders();
  }

  Future<void> _refresh() async {
    final next = widget.repository.riders();
    setState(() {
      _riders = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder keeps the error state visible with a retry action.
    }
  }

  Future<void> _openRider(LogisticsRider rider) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouteNames.logisticsRiderDetails, arguments: rider.userId);
    if (!mounted) return;
    await _refresh();
  }

  List<LogisticsRider> _filtered(
    List<LogisticsRider> riders,
  ) => switch (_filter) {
    _RiderFilter.all => riders,
    _RiderFilter.local => riders.where((rider) => !rider.isCourier).toList(),
    _RiderFilter.courier => riders.where((rider) => rider.isCourier).toList(),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rider Management'),
      actions: [
        IconButton(
          key: const ValueKey('logistics-riders-refresh'),
          onPressed: _refresh,
          tooltip: 'Refresh Riders',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<LogisticsRider>>(
      future: _riders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _problem(
            'Could not load Riders linked to this Logistics provider.',
          );
        }
        final riders = snapshot.data ?? const <LogisticsRider>[];
        if (riders.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
                _empty(
                  'No Local Riders or Couriers are linked to this provider.',
                ),
              ],
            ),
          );
        }
        final visible = _filtered(riders);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const ValueKey('logistics-rider-roster'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Provider roster',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Read-only profiles and operational status for Riders associated with your Logistics account.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('All', _RiderFilter.all, riders.length),
                  _filterChip(
                    'Local Riders',
                    _RiderFilter.local,
                    riders.where((rider) => !rider.isCourier).length,
                  ),
                  _filterChip(
                    'Couriers',
                    _RiderFilter.courier,
                    riders.where((rider) => rider.isCourier).length,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  child: _empty(
                    _filter == _RiderFilter.courier
                        ? 'No Couriers are linked to this provider.'
                        : 'No Local Riders are linked to this provider.',
                  ),
                )
              else
                ...visible.map(_riderCard),
            ],
          ),
        );
      },
    ),
  );

  Widget _filterChip(String label, _RiderFilter value, int count) => ChoiceChip(
    key: ValueKey('logistics-rider-filter-${value.name}'),
    label: Text('$label ($count)'),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  Widget _riderCard(LogisticsRider rider) => Card(
    key: ValueKey('logistics-rider-${rider.userId}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        child: Icon(
          rider.isCourier ? Icons.airport_shuttle_outlined : Icons.two_wheeler,
        ),
      ),
      title: Text(rider.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rider.workTypeLabel),
            const SizedBox(height: 4),
            Text(
              '${_label(rider.operationalStatus)} · Account ${_label(rider.accountStatus)}',
            ),
            if (rider.currentZone != null) Text('Zone: ${rider.currentZone}'),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _openRider(rider),
    ),
  );

  Widget _problem(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
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

  Widget _empty(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class LogisticsRiderDetailsPage extends StatefulWidget {
  const LogisticsRiderDetailsPage({
    super.key,
    required this.repository,
    required this.riderUserId,
  });

  final LogisticsRepository repository;
  final int riderUserId;

  @override
  State<LogisticsRiderDetailsPage> createState() =>
      _LogisticsRiderDetailsPageState();
}

class _LogisticsRiderDetailsPageState extends State<LogisticsRiderDetailsPage> {
  late Future<LogisticsRider> _rider;

  @override
  void initState() {
    super.initState();
    _rider = widget.repository.rider(widget.riderUserId);
  }

  Future<void> _refresh() async {
    final next = widget.repository.rider(widget.riderUserId);
    setState(() {
      _rider = next;
    });
    try {
      await next;
    } catch (_) {
      // Keep the request error available for the retry control.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rider Details'),
      actions: [
        IconButton(
          key: const ValueKey('logistics-rider-details-refresh'),
          onPressed: _refresh,
          tooltip: 'Refresh Rider details',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsRider>(
      future: _rider,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load this provider-owned Rider profile.',
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
        final rider = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            child: Icon(
                              rider.isCourier
                                  ? Icons.airport_shuttle_outlined
                                  : Icons.two_wheeler,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rider.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(rider.workTypeLabel),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _statusChip('Account ${_label(rider.accountStatus)}'),
                          _statusChip(
                            'Verification ${_label(rider.verificationStatus)}',
                          ),
                          if (rider.applicationStatus != null)
                            _statusChip(
                              'Application ${_label(rider.applicationStatus!)}',
                            ),
                          _statusChip(_label(rider.operationalStatus)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _section('Vehicle', [
                _detail('Type', rider.vehicleType),
                if (rider.vehicleModel != null)
                  _detail('Model', rider.vehicleModel!),
                if (rider.plateNumber != null)
                  _detail('Plate number', rider.plateNumber!),
              ]),
              _section('Operations', [
                _detail('Availability', _label(rider.availabilityStatus)),
                _detail('Operational state', _label(rider.operationalStatus)),
                _detail('Active jobs', '${rider.activeJobs}'),
                _detail('Completed today', '${rider.completedToday}'),
                if (rider.capacity != null)
                  _detail(rider.capacityLabel, '${rider.capacity}'),
                if (rider.specializationLabel != null)
                  _detail('Local assignments', rider.specializationLabel!),
                if (rider.currentZone != null)
                  _detail('Current zone', rider.currentZone!),
                if (rider.homeSortingCenter != null)
                  _detail('Home sorting center', rider.homeSortingCenter!),
              ]),
            ],
          ),
        );
      },
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Widget _statusChip(String value) =>
      Chip(label: Text(value), visualDensity: VisualDensity.compact);
}

String _label(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
