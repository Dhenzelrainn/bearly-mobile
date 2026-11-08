import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_pickup_request.dart';

class LogisticsPickupRequestDetailPage extends StatefulWidget {
  const LogisticsPickupRequestDetailPage({
    super.key,
    required this.repository,
    required this.pickupRequestId,
  });

  final LogisticsRepository repository;
  final int pickupRequestId;

  @override
  State<LogisticsPickupRequestDetailPage> createState() =>
      _LogisticsPickupRequestDetailPageState();
}

class _LogisticsPickupRequestDetailPageState
    extends State<LogisticsPickupRequestDetailPage> {
  late Future<LogisticsPickupRequest> _pickup;

  @override
  void initState() {
    super.initState();
    _pickup = widget.repository.pickupRequest(widget.pickupRequestId);
  }

  Future<void> _refresh() async {
    final next = widget.repository.pickupRequest(widget.pickupRequestId);
    setState(() {
      _pickup = next;
    });
    try {
      await next;
    } catch (_) {
      // The FutureBuilder keeps the failure visible with its retry action.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pickup Request')),
    body: FutureBuilder<LogisticsPickupRequest>(
      future: _pickup,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 360,
                  child: _ProblemState(
                    message: _errorMessage(snapshot.error),
                    onRetry: _refresh,
                  ),
                ),
              ],
            ),
          );
        }

        final pickup = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const ValueKey('logistics-pickup-request-detail'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _section(
                context,
                title: 'Request overview',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pickup.reference,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Chip(
                        label: Text(pickup.statusLabel),
                        side: BorderSide.none,
                        backgroundColor: BearlyColors.cream200,
                      ),
                    ],
                  ),
                  _InfoRow(
                    label: 'Pickup type',
                    value: pickup.isReturnPickup
                        ? 'Buyer return pickup'
                        : 'Seller pickup',
                  ),
                  _InfoRow(label: 'Store', value: pickup.storeName),
                  _InfoRow(
                    label: 'Requested date',
                    value: _formatDate(pickup.requestedDate),
                  ),
                  _InfoRow(
                    label: 'Pickup window',
                    value: _formatWindow(pickup.windowStart, pickup.windowEnd),
                  ),
                  _InfoRow(
                    label: 'Pickup location',
                    value: pickup.pickupLocation,
                  ),
                  _InfoRow(
                    label: 'Parcels and weight',
                    value:
                        '${pickup.parcelCount} · ${pickup.totalWeightKg.toStringAsFixed(3)} kg',
                  ),
                  if (pickup.sellerOrderReferences.isNotEmpty)
                    _InfoRow(
                      label: 'Seller Order references',
                      value: pickup.sellerOrderReferences.join(', '),
                    ),
                  if (pickup.sellerInstructions?.trim().isNotEmpty == true)
                    _InfoRow(
                      label: 'Pickup instructions',
                      value: pickup.sellerInstructions!,
                    ),
                  if (pickup.rejectionReason?.trim().isNotEmpty == true)
                    _InfoRow(
                      label: 'Rejection reason',
                      value: pickup.rejectionReason!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Parcels and waybills',
                children: pickup.parcels.isEmpty
                    ? const [Text('No parcel details are available.')]
                    : pickup.parcels.map(_parcelTile).toList(),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Assigned Rider',
                children: [
                  if (pickup.assignedRider == null)
                    const Text('No Rider is currently assigned.')
                  else ...[
                    _InfoRow(label: 'Name', value: pickup.assignedRider!.name),
                    _InfoRow(
                      label: 'Assignment status',
                      value: _headline(pickup.assignedRider!.assignmentStatus),
                    ),
                    _InfoRow(
                      label: 'Assigned at',
                      value: _formatDateTime(pickup.assignedRider!.assignedAt),
                    ),
                  ],
                ],
              ),
              if (pickup.eligibleRiderCandidates.isNotEmpty) ...[
                const SizedBox(height: 12),
                _section(
                  context,
                  title: 'Eligible Local Rider candidates',
                  subtitle:
                      'Read-only recommendations from the current Web assignment rules.',
                  children: pickup.eligibleRiderCandidates
                      .map(_candidateTile)
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Pickup history',
                children: pickup.history.isEmpty
                    ? const [Text('No additional pickup history is recorded.')]
                    : pickup.history.map(_historyTile).toList(),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _parcelTile(LogisticsPickupParcel parcel) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
    title: Text(parcel.reference),
    subtitle: Text(
      [
        'Piece ${parcel.pieceNumber}',
        parcel.status.replaceAll('_', ' '),
        if (parcel.waybill != null) 'Waybill ${parcel.waybill}',
        if (parcel.shipmentReference != null)
          'Shipment ${parcel.shipmentReference}',
        if (parcel.weightKg != null)
          '${parcel.weightKg!.toStringAsFixed(3)} kg',
        if (parcel.sellerOrderReferences.isNotEmpty)
          parcel.sellerOrderReferences.join(', '),
      ].join(' · '),
    ),
  );

  Widget _candidateTile(LogisticsPickupCandidate candidate) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      candidate.recommended
          ? Icons.star_rounded
          : Icons.delivery_dining_rounded,
      color: candidate.recommended ? BearlyColors.gold : BearlyColors.muted,
    ),
    title: Text(candidate.name),
    subtitle: Text(
      [
        if (candidate.vehicle?.isNotEmpty == true) candidate.vehicle!,
        if (candidate.serviceArea?.isNotEmpty == true) candidate.serviceArea!,
        '${candidate.activeJobs} active ${candidate.activeJobs == 1 ? 'job' : 'jobs'}',
        if (candidate.distanceLabel?.isNotEmpty == true)
          candidate.distanceLabel!,
        if (candidate.recommendationReason?.isNotEmpty == true)
          candidate.recommendationReason!,
      ].join(' · '),
    ),
  );

  Widget _historyTile(LogisticsPickupActivity event) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.history_rounded, color: BearlyColors.muted),
    title: Text(event.label),
    subtitle: Text(
      [
        _formatDateTime(event.occurredAt),
        if (event.detail?.isNotEmpty == true) event.detail!,
      ].where((part) => part.isNotEmpty).join(' · '),
    ),
  );
}

Widget _section(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<Widget> children,
}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
          ),
        ],
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  ),
);

String _errorMessage(Object? error) {
  if (error is ApiHttpException && error.statusCode == 404) {
    return 'This pickup request is not available to your Logistics account.';
  }
  if (error is ApiHttpException &&
      (error.statusCode == 401 || error.statusCode == 403)) {
    return 'Your Logistics session is no longer authorized.';
  }
  return 'Could not load this pickup request. Check your connection and retry.';
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not recorded';
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Not recorded';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} · $hour:$minute $period';
}

String _formatWindow(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 'Not scheduled';
  return '${_formatDateTime(start)} – ${_formatDateTime(end)}';
}

String _headline(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ProblemState extends StatelessWidget {
  const _ProblemState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
