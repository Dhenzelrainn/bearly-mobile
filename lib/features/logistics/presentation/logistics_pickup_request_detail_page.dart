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
  bool _actionBusy = false;
  String? _actionError;
  String? _actionMessage;
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  final TextEditingController _assignmentNotesController =
      TextEditingController();
  final TextEditingController _replacementReasonController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _pickup = widget.repository.pickupRequest(widget.pickupRequestId);
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    _assignmentNotesController.dispose();
    _replacementReasonController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = widget.repository.pickupRequest(widget.pickupRequestId);
    setState(() {
      _pickup = next;
      _actionError = null;
      _actionMessage = null;
    });
    try {
      await next;
    } catch (_) {
      // The FutureBuilder keeps the failure visible with its retry action.
    }
  }

  Future<void> _verifyRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify pickup request?'),
        content: const Text(
          'This confirms the request for review. Rider assignment remains a separate step.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep pending'),
          ),
          FilledButton(
            key: const ValueKey('logistics-pickup-verify-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        () => widget.repository.verifyPickupRequest(widget.pickupRequestId),
        'Pickup request verified.',
      );
    }
  }

  Future<void> _rejectRequest() async {
    final formKey = GlobalKey<FormState>();
    _rejectionReasonController.clear();
    final submittedReason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject pickup request'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const ValueKey('logistics-pickup-rejection-reason'),
            controller: _rejectionReasonController,
            autofocus: true,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Explain why this request is rejected',
            ),
            validator: (value) => value?.trim().isNotEmpty == true
                ? null
                : 'Enter a rejection reason.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-pickup-reject-confirm'),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, _rejectionReasonController.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (submittedReason != null) {
      await _runAction(
        () => widget.repository.rejectPickupRequest(
          widget.pickupRequestId,
          reason: submittedReason,
        ),
        'Pickup request rejected.',
      );
    }
  }

  Future<void> _chooseRider(
    LogisticsPickupRequest pickup, {
    required bool replacing,
  }) async {
    if (pickup.eligibleRiderCandidates.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    _assignmentNotesController.clear();
    _replacementReasonController.clear();
    var selectedRiderId = pickup.eligibleRiderCandidates
        .firstWhere(
          (candidate) => candidate.recommended,
          orElse: () => pickup.eligibleRiderCandidates.first,
        )
        .profileId;

    final selection = await showDialog<_PickupRiderSelection>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(replacing ? 'Replace assigned Rider' : 'Assign a Rider'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    key: const ValueKey('logistics-pickup-rider-selection'),
                    initialValue: selectedRiderId,
                    decoration: const InputDecoration(labelText: 'Local Rider'),
                    items: pickup.eligibleRiderCandidates
                        .map(
                          (candidate) => DropdownMenuItem<int>(
                            value: candidate.profileId,
                            child: Text(
                              '${candidate.name}${candidate.recommended ? ' · Recommended' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRiderId = value);
                      }
                    },
                  ),
                  if (replacing) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey(
                        'logistics-pickup-replacement-reason',
                      ),
                      controller: _replacementReasonController,
                      maxLength: 1000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason for replacement',
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        return trimmed.length >= 5
                            ? null
                            : 'Enter at least 5 characters.';
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('logistics-pickup-assignment-notes'),
                      controller: _assignmentNotesController,
                      maxLength: 1000,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Assignment notes (optional)',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey(
                replacing
                    ? 'logistics-pickup-replacement-confirm'
                    : 'logistics-pickup-assignment-confirm',
              ),
              onPressed: () {
                if (formKey.currentState?.validate() == false) return;
                Navigator.pop(
                  context,
                  _PickupRiderSelection(
                    riderProfileId: selectedRiderId,
                    notes: _assignmentNotesController.text.trim(),
                    reason: _replacementReasonController.text.trim(),
                  ),
                );
              },
              child: Text(replacing ? 'Replace Rider' : 'Confirm assignment'),
            ),
          ],
        ),
      ),
    );
    if (selection == null) return;

    await _runAction(
      () => replacing
          ? widget.repository.replacePickupRequestRider(
              widget.pickupRequestId,
              riderProfileId: selection.riderProfileId,
              reason: selection.reason,
            )
          : widget.repository.assignPickupRequest(
              widget.pickupRequestId,
              riderProfileId: selection.riderProfileId,
              notes: selection.notes,
            ),
      replacing ? 'Rider assignment updated.' : 'Rider assigned to pickup.',
    );
  }

  Future<void> _runAction(
    Future<LogisticsPickupRequest> Function() action,
    String successMessage,
  ) async {
    if (_actionBusy) return;
    setState(() {
      _actionBusy = true;
      _actionError = null;
      _actionMessage = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _pickup = Future.value(updated);
        _actionMessage = successMessage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = _actionErrorMessage(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
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
              if (_hasAuthorizedActions(pickup)) ...[
                const SizedBox(height: 12),
                _operationalActions(pickup),
              ],
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

  bool _hasAuthorizedActions(LogisticsPickupRequest pickup) =>
      pickup.status == 'requested' ||
      pickup.status == 'verified' ||
      (pickup.status == 'scheduled' &&
          const {
            'assigned',
            'accepted',
            'arrived',
          }.contains(pickup.assignedRider?.assignmentStatus));

  Widget _operationalActions(LogisticsPickupRequest pickup) => _section(
    context,
    title: 'Pickup actions',
    subtitle: 'Actions follow the existing Logistics Web workflow.',
    children: [
      if (_actionBusy) const LinearProgressIndicator(),
      if (_actionMessage != null) ...[
        Text(
          _actionMessage!,
          key: const ValueKey('logistics-pickup-action-success'),
          style: const TextStyle(color: BearlyColors.success),
        ),
        const SizedBox(height: 8),
      ],
      if (_actionError != null) ...[
        Text(
          _actionError!,
          key: const ValueKey('logistics-pickup-action-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('logistics-pickup-action-refresh'),
          onPressed: _actionBusy ? null : _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh request'),
        ),
      ],
      if (pickup.status == 'requested') ...[
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('logistics-pickup-verify'),
            onPressed: _actionBusy ? null : _verifyRequest,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Verify request'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-pickup-reject'),
            onPressed: _actionBusy ? null : _rejectRequest,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Reject request'),
          ),
        ),
      ] else if (pickup.status == 'verified') ...[
        if (pickup.eligibleRiderCandidates.isEmpty)
          const Text('No eligible Local Rider is currently available.')
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('logistics-pickup-assign'),
              onPressed: _actionBusy
                  ? null
                  : () => _chooseRider(pickup, replacing: false),
              icon: const Icon(Icons.delivery_dining_outlined),
              label: const Text('Assign Rider & schedule pickup'),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('logistics-pickup-reject'),
            onPressed: _actionBusy ? null : _rejectRequest,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Reject request'),
          ),
        ),
      ] else if (pickup.status == 'scheduled' &&
          const {
            'assigned',
            'accepted',
            'arrived',
          }.contains(pickup.assignedRider?.assignmentStatus)) ...[
        if (pickup.eligibleRiderCandidates.isEmpty)
          const Text(
            'No eligible replacement Local Rider is currently available.',
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('logistics-pickup-replace-rider'),
              onPressed: _actionBusy
                  ? null
                  : () => _chooseRider(pickup, replacing: true),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Replace Rider'),
            ),
          ),
      ],
    ],
  );
}

class _PickupRiderSelection {
  const _PickupRiderSelection({
    required this.riderProfileId,
    required this.notes,
    required this.reason,
  });

  final int riderProfileId;
  final String notes;
  final String reason;
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

String _actionErrorMessage(Object error) {
  if (error is ApiHttpException) {
    final response = error.responseData;
    if (response is Map) {
      final errors = response['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty && value.first is String) {
            return value.first as String;
          }
        }
      }
      final message = response['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    if (error.statusCode == 409) {
      return 'This request or Rider availability changed. Refresh and try again.';
    }
    if (error.statusCode == 404) {
      return 'This pickup request or Rider is no longer available to your provider.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'Your Logistics session is no longer authorized.';
    }
    if (error.statusCode == 429) {
      return 'Too many actions were sent. Wait a moment and retry.';
    }
  }
  if (error is ApiException) return error.message;
  return 'The pickup action could not be completed. Refresh and retry.';
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
