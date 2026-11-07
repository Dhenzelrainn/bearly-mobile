import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_monitoring.dart';

class LogisticsDeliveryMonitoringPage extends StatefulWidget {
  const LogisticsDeliveryMonitoringPage({
    super.key,
    required this.repository,
  });

  final LogisticsRepository repository;

  @override
  State<LogisticsDeliveryMonitoringPage> createState() =>
      _LogisticsDeliveryMonitoringPageState();
}

class _LogisticsDeliveryMonitoringPageState
    extends State<LogisticsDeliveryMonitoringPage> {
  late Future<LogisticsDeliveryMonitoring> _monitoring;

  @override
  void initState() {
    super.initState();
    _monitoring = widget.repository.deliveryMonitoring();
  }

  Future<void> _refresh() async {
    final next = widget.repository.deliveryMonitoring();
    setState(() {
      _monitoring = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the read error and leaves refresh available.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Delivery Monitoring'),
      actions: [
        IconButton(
          tooltip: 'Refresh delivery monitoring',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsDeliveryMonitoring>(
      future: _monitoring,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final unauthorized = snapshot.error is ApiHttpException &&
              ((snapshot.error! as ApiHttpException).statusCode == 401 ||
                  (snapshot.error! as ApiHttpException).statusCode == 403);
          return _MonitoringProblem(
            message: unauthorized
                ? 'Your Logistics session is no longer authorized.'
                : 'Could not load delivery monitoring. Check your connection and retry.',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return _MonitoringProblem(
            message: 'Delivery monitoring is unavailable.',
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const ValueKey('logistics-monitoring-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                data.providerName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Read-only progress for your provider’s dispatched batches.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BearlyColors.muted,
                ),
              ),
              const SizedBox(height: 14),
              if (data.deliveries.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No delivery batches are available yet.'),
                  ),
                )
              else
                ...data.deliveries.map(_deliveryCard),
            ],
          ),
        );
      },
    ),
  );

  Widget _deliveryCard(LogisticsDeliverySummary delivery) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      key: ValueKey('monitoring-batch-${delivery.reference}'),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LogisticsDeliveryMonitoringDetailPage(
            repository: widget.repository,
            batchReference: delivery.reference,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_shipping_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    delivery.reference,
                    key: ValueKey('batch-reference-${delivery.reference}'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _labeledValue('Rider', delivery.rider),
            _labeledValue(
              'Delivery zone',
              [delivery.zoneCode, delivery.zoneName]
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
            ),
            _labeledValue('Parcels', '${delivery.parcelCount}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: delivery.progress / 100,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${delivery.progress}%'),
              ],
            ),
            const SizedBox(height: 10),
            _stageChip(delivery.status, delivery.statusLabel),
            const SizedBox(height: 8),
            Text(
              delivery.lastUpdate,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BearlyColors.muted,
              ),
              softWrap: true,
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('View details  ›'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _labeledValue(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value.isEmpty ? '—' : value),
        ],
      ),
      softWrap: true,
    ),
  );
}

class LogisticsDeliveryMonitoringDetailPage extends StatefulWidget {
  const LogisticsDeliveryMonitoringDetailPage({
    super.key,
    required this.repository,
    required this.batchReference,
  });

  final LogisticsRepository repository;
  final String batchReference;

  @override
  State<LogisticsDeliveryMonitoringDetailPage> createState() =>
      _LogisticsDeliveryMonitoringDetailPageState();
}

class _LogisticsDeliveryMonitoringDetailPageState
    extends State<LogisticsDeliveryMonitoringDetailPage> {
  late Future<LogisticsDeliveryDetail> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.repository.deliveryMonitoringDetail(
      widget.batchReference,
    );
  }

  Future<void> _refresh() async {
    final next = widget.repository.deliveryMonitoringDetail(
      widget.batchReference,
    );
    setState(() {
      _detail = next;
    });
    try {
      await next;
    } catch (_) {
      // Keep the latest server read error visible without changing any state.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Delivery Details'),
      actions: [
        IconButton(
          tooltip: 'Refresh delivery details',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsDeliveryDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MonitoringProblem(
            message: 'Could not load this delivery batch. Refresh to try again.',
            onRetry: _refresh,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return _MonitoringProblem(
            message: 'This delivery batch is unavailable.',
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const ValueKey('logistics-monitoring-detail'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                data.delivery.reference,
                style: Theme.of(context).textTheme.titleLarge,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              _stageChip(data.delivery.status, data.delivery.statusLabel),
              const SizedBox(height: 10),
              _detailValue('Provider', data.providerName),
              _detailValue(
                'Sorting center',
                [data.sortingCenterName, data.sortingCenterCode]
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
              ),
              _detailValue('Rider', data.delivery.rider),
              _detailValue(
                'Zone',
                [data.delivery.zoneCode, data.delivery.zoneName]
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: data.delivery.progress / 100,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${data.delivery.progress}% complete'),
                ],
              ),
              const SizedBox(height: 18),
              Text('Parcels', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              if (data.parcels.isEmpty)
                const Text('No parcels are attached to this batch.')
              else
                ...data.parcels.map(_parcelCard),
              const SizedBox(height: 18),
              Text('Delivery timeline', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              if (data.timeline.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No recorded updates.'),
                  ),
                )
              else
                ...data.timeline.map(_timelineCard),
            ],
          ),
        );
      },
    ),
  );

  Widget _parcelCard(LogisticsMonitoredParcel parcel) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parcel ${parcel.reference}', softWrap: true),
          const SizedBox(height: 4),
          _detailValue('Waybill', parcel.waybill),
          _detailValue('Parcel status', _humanStatus(parcel.status)),
          _detailValue('Shipment', parcel.shipmentReference),
          _detailValue('Shipment status', _humanStatus(parcel.shipmentStatus)),
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
        ],
      ),
    ),
  );

  Widget _timelineCard(LogisticsMonitoringEvent event) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const Icon(Icons.history_rounded),
      title: Text(event.label, softWrap: true),
      subtitle: Text(
        [event.time, event.detail].where((value) => value.isNotEmpty).join('\n'),
        softWrap: true,
      ),
      isThreeLine: event.detail.isNotEmpty,
    ),
  );

  Widget _detailValue(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value.isEmpty ? '—' : value),
        ],
      ),
      softWrap: true,
    ),
  );
}

class _MonitoringProblem extends StatelessWidget {
  const _MonitoringProblem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
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
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

Widget _stageChip(String status, String label) => Chip(
  key: ValueKey('monitoring-stage-$status'),
  label: Text(label.isEmpty ? _humanStatus(status) : label),
  visualDensity: VisualDensity.compact,
);

String _humanStatus(String status) => switch (status) {
  'assigned_to_rider' => 'Assigned to Rider',
  'at_sorting_center' => 'At Sorting Center',
  'delivery_failed' => 'Delivery Failed',
  'in_transit' => 'In Transit',
  'out_for_delivery' => 'Out for Delivery',
  'picked_up' => 'Picked Up',
  'return_to_sender' => 'Return to Sender',
  _ => status
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' '),
};
