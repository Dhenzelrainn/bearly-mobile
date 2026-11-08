import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
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
  bool _savingAction = false;

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

  Future<void> _editCapacity(LogisticsRider rider) async {
    final formKey = GlobalKey<FormState>();
    var selectedCapacity = rider.capacity ?? 0;
    final capacity = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Local Rider parcel capacity'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const ValueKey('logistics-rider-capacity-input'),
            initialValue: '${rider.capacity ?? ''}',
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maximum active parcels',
              helperText: 'Enter a whole number from 1 to 1000.',
            ),
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed < 1 || parsed > 1000) {
                return 'Enter a whole number from 1 to 1000.';
              }
              return null;
            },
            onSaved: (value) => selectedCapacity = int.parse(value!.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-rider-capacity-save'),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(dialogContext, selectedCapacity);
            },
            child: const Text('Save capacity'),
          ),
        ],
      ),
    );
    if (capacity == null || !mounted) return;

    await _saveLocalAction(
      () => widget.repository.updateRiderCapacity(
        userId: rider.userId,
        parcelCapacity: capacity,
      ),
      successMessage: (_) => 'Local Rider capacity updated.',
    );
  }

  Future<void> _editSpecialization(LogisticsRider rider) async {
    final formKey = GlobalKey<FormState>();
    var specialization = rider.specialization ?? 'both';
    var reason = '';
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Local pickup and delivery work'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('logistics-rider-specialization-input'),
                  initialValue: specialization,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'both',
                      child: Text('Pickup and delivery'),
                    ),
                    DropdownMenuItem(
                      value: 'pickup_only',
                      child: Text('Pickup only'),
                    ),
                    DropdownMenuItem(
                      value: 'delivery_only',
                      child: Text('Delivery only'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => specialization = value);
                    }
                  },
                  validator: (value) => value == null
                      ? 'Choose a Local Rider specialization.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('logistics-rider-specialization-reason'),
                  initialValue: '',
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 5
                      ? 'Enter a reason of at least 5 characters.'
                      : null,
                  onSaved: (value) => reason = value?.trim() ?? '',
                ),
                const Text(
                  'This applies to future assignments. Existing work remains attached.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('logistics-rider-specialization-save'),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                Navigator.pop(dialogContext, {
                  'specialization': specialization,
                  'reason': reason,
                });
              },
              child: const Text('Save specialization'),
            ),
          ],
        ),
      ),
    );
    if (values == null || !mounted) return;

    await _saveLocalAction(
      () => widget.repository.updateRiderSpecialization(
        userId: rider.userId,
        specialization: values['specialization']!,
        reason: values['reason']!,
      ),
      successMessage: (_) => 'Local Rider specialization updated.',
    );
  }

  Future<void> _refreshHomeAreaMatch(LogisticsRider rider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refresh home-area match?'),
        content: const Text(
          'Bearly will match the Rider’s registered Home address to an active zone and sorting center owned by this provider. A zone cannot be selected manually here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-rider-zone-refresh-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Refresh match'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _saveLocalAction(
      () => widget.repository.refreshRiderAssignment(userId: rider.userId),
      successMessage: (updated) => updated.currentZone == null
          ? 'No active provider zone covers the registered home address.'
          : 'Home-area match refreshed from the server.',
    );
  }

  Future<void> _saveLocalAction(
    Future<LogisticsRider> Function() action, {
    required String Function(LogisticsRider updated) successMessage,
  }) async {
    if (_savingAction) return;
    setState(() => _savingAction = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _rider = Future.value(updated);
      });
      try {
        final refreshed = await widget.repository.rider(widget.riderUserId);
        if (mounted) {
          setState(() {
            _rider = Future.value(refreshed);
          });
        }
      } catch (_) {
        // Keep the authoritative updated response visible if the refresh fails.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage(updated))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_managementError(error))));
    } finally {
      if (mounted) setState(() => _savingAction = false);
    }
  }

  String _managementError(Object error) {
    if (error is ApiHttpException) {
      final validation = error.validationErrors.values
          .expand((messages) => messages)
          .firstOrNull;
      if (validation != null && validation.isNotEmpty) return validation;
      return switch (error.statusCode) {
        401 || 403 => 'This Logistics account cannot manage this Rider.',
        404 => 'This Rider is no longer linked to your provider.',
        409 => 'Rider eligibility or workload changed. Refresh and try again.',
        _ => 'The Rider update could not be saved. Try again.',
      };
    }
    if (error is ApiException) return error.message;
    return 'The Rider update could not be saved. Try again.';
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
                _detail('Current zone', rider.currentZone ?? 'Not assigned'),
                _detail(
                  'Home sorting center',
                  rider.homeSortingCenter ?? 'Not assigned',
                ),
              ]),
              if (rider.canManageLocalActions) ...[
                const SizedBox(height: 4),
                _section('Local Rider Management', [
                  const Text(
                    'These controls follow the same eligibility and assignment rules as the Web workspace.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('logistics-rider-edit-capacity'),
                    onPressed: _savingAction
                        ? null
                        : () => _editCapacity(rider),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Edit parcel capacity'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('logistics-rider-edit-specialization'),
                    onPressed: _savingAction
                        ? null
                        : () => _editSpecialization(rider),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Edit pickup and delivery work'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('logistics-rider-refresh-zone'),
                    onPressed: _savingAction
                        ? null
                        : () => _refreshHomeAreaMatch(rider),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Refresh home-area zone match'),
                  ),
                  if (_savingAction) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ]),
              ],
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
