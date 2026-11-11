import 'package:flutter/material.dart';

import '../data/logistics_repository.dart';
import '../models/logistics_reports.dart';

class LogisticsReportsPage extends StatefulWidget {
  const LogisticsReportsPage({super.key, required this.repository});

  final LogisticsRepository repository;

  @override
  State<LogisticsReportsPage> createState() => _LogisticsReportsPageState();
}

class _LogisticsReportsPageState extends State<LogisticsReportsPage> {
  late Future<LogisticsReports> _reports;
  String? _from;
  String? _to;

  @override
  void initState() {
    super.initState();
    _reports = widget.repository.reports();
  }

  void _load({String? from, String? to}) {
    setState(() {
      _from = from;
      _to = to;
      _reports = widget.repository.reports(from: from, to: to);
    });
  }

  Future<void> _refresh() async {
    final request = widget.repository.reports(from: _from, to: _to);
    setState(() {
      _reports = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder keeps the error visible and provides a retry action.
    }
  }

  Future<void> _selectPeriod(String? value) async {
    if (value == null) return;
    if (value == 'last_7_days') {
      _load();
      return;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final defaultStart = today.subtract(const Duration(days: 6));
    final initialRange = _from != null && _to != null
        ? DateTimeRange(
            start: DateTime.parse(_from!),
            end: DateTime.parse(_to!),
          )
        : DateTimeRange(start: defaultStart, end: today);
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Select report dates',
      saveText: 'Apply range',
    );
    if (!mounted || selected == null) return;
    _load(from: _dateString(selected.start), to: _dateString(selected.end));
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports')),
    body: FutureBuilder<LogisticsReports>(
      future: _reports,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(key: ValueKey('reports-loading')),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _errorState();
        }
        return _reportContent(snapshot.data!);
      },
    ),
  );

  Widget _errorState() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 100),
      const Icon(Icons.cloud_off_outlined, size: 44),
      const SizedBox(height: 12),
      const Text(
        'Reports unavailable',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Logistics report data could not be loaded. Check your connection and retry.',
        textAlign: TextAlign.center,
      ),
      Align(
        child: TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
    ],
  );

  Widget _reportContent(LogisticsReports reports) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      key: const ValueKey('logistics-reports-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          'Operations summary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Provider-scoped parcel, delivery, sorting, and Rider activity.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _periodSelector(),
        const SizedBox(height: 6),
        Text(
          '${reports.period.from} to ${reports.period.to} · ${reports.period.timezone}',
          key: const ValueKey('logistics-reports-period'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        _sectionTitle(context, 'Summary'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            final summary = reports.summary;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(
                  width,
                  'Parcel throughput',
                  '${summary.parcelThroughput}',
                  'Unique parcels received in period',
                ),
                _metric(
                  width,
                  'Delivered',
                  '${summary.deliveredParcels}',
                  'Unique parcels completed in period',
                ),
                _metric(
                  width,
                  'Success rate',
                  '${_percent(summary.successRatePercent)}%',
                  '${summary.resolvedDeliveryOutcomes} resolved delivery outcomes',
                ),
                _metric(
                  width,
                  'Average sort time',
                  summary.averageSortTime,
                  'Receipt to initial sorting',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Daily parcel throughput'),
        const SizedBox(height: 8),
        _dailyThroughput(reports.dailyThroughput),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Delivery status breakdown'),
        const SizedBox(height: 8),
        _deliveryStatuses(reports.deliveryStatusBreakdown),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Rider performance'),
        const SizedBox(height: 4),
        const Text('Assigned parcels and recorded delivery attempt outcomes.'),
        const SizedBox(height: 8),
        _riderPerformance(reports.riderPerformance),
        if (_isEmpty(reports)) ...[
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No operational activity was recorded for this period.',
                key: ValueKey('logistics-reports-empty'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _periodSelector() => InputDecorator(
    decoration: const InputDecoration(labelText: 'Report period'),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const ValueKey('logistics-reports-period-selector'),
        value: _from == null ? 'last_7_days' : 'custom',
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'last_7_days', child: Text('Latest 7 days')),
          DropdownMenuItem(value: 'custom', child: Text('Custom date range')),
        ],
        onChanged: _selectPeriod,
      ),
    ),
  );

  Widget _metric(double width, String title, String value, String caption) =>
      SizedBox(
        width: width,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(
                  value,
                  softWrap: true,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(caption, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );

  Widget _dailyThroughput(List<LogisticsDailyThroughput> days) {
    if (days.isEmpty) return _emptySection('No daily parcel data.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final day in days)
              ListTile(
                dense: true,
                title: Text(day.label),
                trailing: Text('${day.parcelCount} parcels'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryStatuses(List<LogisticsDeliveryStatus> statuses) {
    if (statuses.isEmpty) return _emptySection('No delivery status data.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final status in statuses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(status.label),
                    Text('· ${status.value} parcels'),
                    Text('· ${_percent(status.sharePercent)}%'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _riderPerformance(List<LogisticsRiderPerformance> riders) {
    if (riders.isEmpty) return _emptySection('No Rider performance recorded.');
    return Column(
      children: [
        for (final rider in riders)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rider.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Assigned parcels: ${rider.assignedParcels}'),
                      Text('Delivered attempts: ${rider.deliveredAttempts}'),
                      Text('Failed attempts: ${rider.failedAttempts}'),
                      Text('Success rate: ${rider.successRate}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptySection(String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: Theme.of(context).textTheme.titleLarge);

  bool _isEmpty(LogisticsReports reports) =>
      reports.summary.parcelThroughput == 0 &&
      reports.summary.deliveredParcels == 0 &&
      reports.summary.resolvedDeliveryOutcomes == 0 &&
      reports.riderPerformance.isEmpty;

  String _percent(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
