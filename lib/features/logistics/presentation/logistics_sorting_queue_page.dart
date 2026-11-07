import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../auth/data/auth_service.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_sorting.dart';

class LogisticsSortingQueuePage extends StatefulWidget {
  const LogisticsSortingQueuePage({super.key, required this.repository});

  final LogisticsRepository repository;

  @override
  State<LogisticsSortingQueuePage> createState() =>
      _LogisticsSortingQueuePageState();
}

class _LogisticsSortingQueuePageState extends State<LogisticsSortingQueuePage> {
  late Future<LogisticsSortingQueue> _queue;
  final Map<int, int?> _selectedZones = {};
  int? _submittingParcelId;
  bool _needsReconciliation = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _queue = widget.repository.sortingQueue();
  }

  Future<void> _refresh() async {
    final next = widget.repository.sortingQueue();
    setState(() {
      _queue = next;
      _error = null;
    });
    try {
      await next;
      if (!mounted) return;
      setState(() => _needsReconciliation = false);
    } catch (_) {
      // The FutureBuilder displays the read failure. Keep retry blocked until
      // a fresh server read succeeds after an uncertain mutation.
    }
  }

  Future<void> _sort(LogisticsSortingParcel parcel) async {
    final zoneId = _selectedZones[parcel.id];
    final zone = parcel.matchingZones
        .where((candidate) => candidate.id == zoneId)
        .firstOrNull;
    if (zone == null ||
        !parcel.canSort ||
        _submittingParcelId != null ||
        _needsReconciliation) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('logistics-sorting-confirm-dialog'),
        title: const Text('Confirm parcel sorting'),
        content: Text(
          'Mark ${parcel.waybill} sorted into ${zone.code} for ${parcel.destination}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-confirm-sort'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm sorting'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submittingParcelId = parcel.id;
      _error = null;
      _message = null;
    });

    try {
      final result = await widget.repository.sortParcel(
        parcelId: parcel.id,
        sortingZoneId: zone.id,
      );
      if (!mounted) return;
      setState(() {
        _message =
            'Server confirmed ${result.parcelReference} is sorted into ${result.zoneCode}.';
        _selectedZones.remove(parcel.id);
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      final uncertain = _isUncertain(error);
      setState(() {
        _needsReconciliation = uncertain;
        _error = uncertain
            ? 'The sorting result is uncertain. Refresh the sorting queue from the server before trying again.'
            : _requestMessage(error);
      });
    } finally {
      if (mounted) setState(() => _submittingParcelId = null);
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
        return 'This Logistics account is no longer authorized. Sign in again.';
      }
      if (error.statusCode == 404) {
        return 'This parcel or sorting zone is no longer available. Refresh the queue.';
      }
      if (error.statusCode == 409) {
        return 'The parcel is no longer eligible for sorting. Refresh the queue.';
      }
      final validation = error.validationErrors.values
          .expand((messages) => messages)
          .firstOrNull;
      if (validation != null && validation.isNotEmpty) return validation;
    }
    if (error is AuthException) return error.message;
    return 'Could not sort this parcel. Check the queue and try again.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sorting Queue'),
      actions: [
        IconButton(
          onPressed: _submittingParcelId == null ? _refresh : null,
          tooltip: 'Refresh sorting queue',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsSortingQueue>(
      future: _queue,
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
                  Icon(
                    unauthorized
                        ? Icons.lock_outline
                        : Icons.cloud_off_outlined,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    unauthorized
                        ? 'Your Logistics account is not authorized to access this sorting queue.'
                        : 'Could not load the sorting queue. Check your connection and retry.',
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

        final queue = snapshot.data;
        if (queue == null) {
          return const Center(child: Text('The sorting queue is unavailable.'));
        }
        return _queueBody(queue);
      },
    ),
  );

  Widget _queueBody(LogisticsSortingQueue queue) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          queue.sortingCenter.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${queue.sortingCenter.code} · Received parcels awaiting sorting',
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
                key: const ValueKey('logistics-refresh-after-uncertain-sort'),
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh from server'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (queue.parcels.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No received parcels are waiting at this center.'),
            ),
          )
        else
          ...queue.parcels.map(_parcelCard),
      ],
    ),
  );

  Widget _parcelCard(LogisticsSortingParcel parcel) {
    final selectedZone = _selectedZones[parcel.id];
    final submitting = _submittingParcelId == parcel.id;
    return Card(
      key: ValueKey('logistics-sorting-parcel-${parcel.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parcel.waybill,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Parcel ${parcel.reference} · ${parcel.status}'),
            Text('Shipment ${parcel.shipmentReference}'),
            const SizedBox(height: 4),
            Text(
              parcel.destination.isEmpty
                  ? 'Destination unavailable'
                  : parcel.destination,
            ),
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
                    ].join(' / '),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (parcel.matchingZones.isEmpty)
              const Text('No active zone covers this parcel destination.')
            else ...[
              DropdownButtonFormField<int>(
                key: ValueKey('logistics-sorting-zone-${parcel.id}'),
                initialValue: selectedZone,
                decoration: const InputDecoration(
                  labelText: 'Matching destination zone',
                  border: OutlineInputBorder(),
                ),
                items: parcel.matchingZones
                    .map(
                      (zone) => DropdownMenuItem<int>(
                        value: zone.id,
                        child: Text('${zone.code} · ${zone.name}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _submittingParcelId == null && !_needsReconciliation
                    ? (value) =>
                          setState(() => _selectedZones[parcel.id] = value)
                    : null,
              ),
              if (selectedZone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    parcel.matchingZones
                            .where((zone) => zone.id == selectedZone)
                            .map((zone) => zone.coverage)
                            .firstOrNull ??
                        '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('logistics-sort-parcel-${parcel.id}'),
                  onPressed:
                      parcel.canSort &&
                          selectedZone != null &&
                          _submittingParcelId == null &&
                          !_needsReconciliation
                      ? () => _sort(parcel)
                      : null,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  label: Text(submitting ? 'Sorting…' : 'Mark parcel sorted'),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
