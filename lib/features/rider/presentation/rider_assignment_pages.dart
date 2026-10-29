import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderAssignmentListPage extends StatefulWidget {
  const RiderAssignmentListPage({
    super.key,
    required this.repository,
    required this.kind,
  });

  final RiderRepository repository;
  final RiderAssignmentKind kind;

  @override
  State<RiderAssignmentListPage> createState() =>
      _RiderAssignmentListPageState();
}

class _RiderAssignmentListPageState extends State<RiderAssignmentListPage> {
  late Future<List<RiderAssignment>> _jobs;

  bool get _isPickup => widget.kind == RiderAssignmentKind.pickup;

  @override
  void initState() {
    super.initState();
    _jobs = _load();
  }

  Future<List<RiderAssignment>> _load() => _isPickup
      ? widget.repository.pickupJobs()
      : widget.repository.deliveryJobs();

  void _retry() => setState(() => _jobs = _load());

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: _isPickup ? 'Assigned Pickups' : 'Assigned Deliveries',
    subtitle: _isPickup
        ? 'Pickup assignments selected by your Logistics provider.'
        : 'Delivery assignments dispatched to your Rider account.',
    child: FutureBuilder<List<RiderAssignment>>(
      future: _jobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _LoadMessage(
            message:
                'Could not load assigned jobs. Check your connection and retry.',
            onRetry: _retry,
          );
        }

        final jobs = snapshot.data ?? const <RiderAssignment>[];
        if (jobs.isEmpty) {
          return _LoadMessage(
            icon: Icons.inbox_outlined,
            message: _isPickup
                ? 'There are no pickup assignments for you right now.'
                : 'There are no delivery assignments for you right now.',
          );
        }

        return Column(
          children: [
            riderSummary(
              context,
              _isPickup
                  ? Icons.storefront_outlined
                  : Icons.local_shipping_outlined,
              '${jobs.length}',
              _isPickup ? 'Assigned pickups' : 'Assigned deliveries',
            ),
            const SizedBox(height: 12),
            ...jobs.map((job) => _jobCard(context, job)),
          ],
        );
      },
    ),
  );

  Widget _jobCard(BuildContext context, RiderAssignment job) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: CircleAvatar(
        backgroundColor: BearlyColors.cream200,
        foregroundColor: BearlyColors.brown700,
        child: Icon(
          _isPickup ? Icons.storefront_outlined : Icons.local_shipping_outlined,
        ),
      ),
      title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.id, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(job.address, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${job.parcelCount} parcel(s) · ${job.status}'),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.pushNamed(
        context,
        _isPickup
            ? AppRouteNames.riderPickupDetail
            : AppRouteNames.riderDeliveryDetail,
        arguments: job.id,
      ),
    ),
  );
}

class RiderJobDetailPage extends StatefulWidget {
  const RiderJobDetailPage({
    super.key,
    required this.repository,
    required this.kind,
    required this.jobId,
  });

  final RiderRepository repository;
  final RiderAssignmentKind kind;
  final String jobId;

  @override
  State<RiderJobDetailPage> createState() => _RiderJobDetailPageState();
}

class _RiderJobDetailPageState extends State<RiderJobDetailPage> {
  late Future<RiderAssignment> _job;

  bool get _isPickup => widget.kind == RiderAssignmentKind.pickup;

  @override
  void initState() {
    super.initState();
    _job = _load();
  }

  Future<RiderAssignment> _load() => _isPickup
      ? widget.repository.pickupDetail(widget.jobId)
      : widget.repository.deliveryDetail(widget.jobId);

  void _retry() => setState(() => _job = _load());

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: _isPickup ? 'Pickup Details' : 'Delivery Details',
    subtitle: 'Assignment ${widget.jobId}',
    child: FutureBuilder<RiderAssignment>(
      future: _job,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _LoadMessage(
            message:
                'Could not load this assigned job. Check your connection and retry.',
            onRetry: _retry,
          );
        }

        final job = snapshot.data;
        if (job == null) {
          return const _LoadMessage(message: 'This job is unavailable.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('${job.id} · ${job.status}'),
                    const SizedBox(height: 14),
                    riderRouteRow(
                      context,
                      _isPickup
                          ? Icons.storefront_outlined
                          : Icons.location_on_outlined,
                      _isPickup ? 'Pickup location' : 'Delivery address',
                      job.address,
                    ),
                    if (job.contactName.isNotEmpty ||
                        job.contactPhone.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        [
                          job.contactName,
                          job.contactPhone,
                        ].where((value) => value.isNotEmpty).join(' · '),
                      ),
                    ],
                    if (job.window.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Pickup window: ${job.window}'),
                    ],
                    if (job.waybill.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Waybill: ${job.waybill}'),
                    ],
                    if (job.batchNumber.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Dispatch batch: ${job.batchNumber}'),
                    ],
                    if (job.zone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Zone: ${job.zone}'),
                    ],
                    if (job.instructions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Instructions',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(job.instructions),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Parcels (${job.parcelCount})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (job.parcels.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Parcel details are not available.'),
                ),
              )
            else
              ...job.parcels.map(
                (parcel) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(parcel.parcelNumber),
                    subtitle: Text(
                      [
                        parcel.waybill,
                        parcel.size,
                        parcel.status,
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                  ),
                ),
              ),
            if (job.products.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Order contents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...job.products.map(
                (product) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.inventory_outlined),
                    title: Text(product),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _LoadMessage extends StatelessWidget {
  const _LoadMessage({
    required this.message,
    this.icon = Icons.cloud_off_outlined,
    this.onRetry,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 36, color: BearlyColors.muted),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ],
    ),
  );
}
