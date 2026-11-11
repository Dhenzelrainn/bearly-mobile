class LogisticsReports {
  const LogisticsReports({
    required this.period,
    required this.summary,
    required this.dailyThroughput,
    required this.deliveryStatusBreakdown,
    required this.riderPerformance,
  });

  final LogisticsReportPeriod period;
  final LogisticsReportSummary summary;
  final List<LogisticsDailyThroughput> dailyThroughput;
  final List<LogisticsDeliveryStatus> deliveryStatusBreakdown;
  final List<LogisticsRiderPerformance> riderPerformance;

  factory LogisticsReports.fromResponse(Object? value) {
    final root = _map(value, 'response');
    final data = _map(root['data'], 'data');
    return LogisticsReports(
      period: LogisticsReportPeriod.fromJson(data['period']),
      summary: LogisticsReportSummary.fromJson(data['summary']),
      dailyThroughput: _list(
        data['daily_throughput'],
        'daily_throughput',
      ).map(LogisticsDailyThroughput.fromJson).toList(growable: false),
      deliveryStatusBreakdown: _list(
        data['delivery_status_breakdown'],
        'delivery_status_breakdown',
      ).map(LogisticsDeliveryStatus.fromJson).toList(growable: false),
      riderPerformance: _list(
        data['rider_performance'],
        'rider_performance',
      ).map(LogisticsRiderPerformance.fromJson).toList(growable: false),
    );
  }
}

class LogisticsReportPeriod {
  const LogisticsReportPeriod({
    required this.from,
    required this.to,
    required this.timezone,
  });

  final String from;
  final String to;
  final String timezone;

  factory LogisticsReportPeriod.fromJson(Object? value) {
    final map = _map(value, 'period');
    return LogisticsReportPeriod(
      from: _string(map['from']),
      to: _string(map['to']),
      timezone: _string(map['timezone']),
    );
  }
}

class LogisticsReportSummary {
  const LogisticsReportSummary({
    required this.parcelThroughput,
    required this.deliveredParcels,
    required this.successRatePercent,
    required this.resolvedDeliveryOutcomes,
    required this.averageSortTime,
  });

  final int parcelThroughput;
  final int deliveredParcels;
  final double successRatePercent;
  final int resolvedDeliveryOutcomes;
  final String averageSortTime;

  factory LogisticsReportSummary.fromJson(Object? value) {
    final map = _map(value, 'summary');
    return LogisticsReportSummary(
      parcelThroughput: _integer(map['parcel_throughput']),
      deliveredParcels: _integer(map['delivered_parcels']),
      successRatePercent: _number(map['success_rate_percent']),
      resolvedDeliveryOutcomes: _integer(map['resolved_delivery_outcomes']),
      averageSortTime: _string(map['average_sort_time']),
    );
  }
}

class LogisticsDailyThroughput {
  const LogisticsDailyThroughput({
    required this.label,
    required this.parcelCount,
  });

  final String label;
  final int parcelCount;

  factory LogisticsDailyThroughput.fromJson(Object? value) {
    final map = _map(value, 'daily_throughput item');
    return LogisticsDailyThroughput(
      label: _string(map['label']),
      parcelCount: _integer(map['parcel_count']),
    );
  }
}

class LogisticsDeliveryStatus {
  const LogisticsDeliveryStatus({
    required this.label,
    required this.value,
    required this.sharePercent,
  });

  final String label;
  final int value;
  final double sharePercent;

  factory LogisticsDeliveryStatus.fromJson(Object? value) {
    final map = _map(value, 'delivery_status_breakdown item');
    return LogisticsDeliveryStatus(
      label: _string(map['label']),
      value: _integer(map['value']),
      sharePercent: _number(map['share']),
    );
  }
}

class LogisticsRiderPerformance {
  const LogisticsRiderPerformance({
    required this.name,
    required this.assignedParcels,
    required this.deliveredAttempts,
    required this.failedAttempts,
    required this.successRate,
  });

  final String name;
  final int assignedParcels;
  final int deliveredAttempts;
  final int failedAttempts;
  final String successRate;

  factory LogisticsRiderPerformance.fromJson(Object? value) {
    final map = _map(value, 'rider_performance item');
    return LogisticsRiderPerformance(
      name: _string(map['name']),
      assignedParcels: _integer(map['assigned']),
      deliveredAttempts: _integer(map['delivered']),
      failedAttempts: _integer(map['failed']),
      successRate: _string(map['rate']),
    );
  }
}

Map _map(Object? value, String path) {
  if (value is Map) return value;
  throw FormatException('Bearly returned an invalid Logistics $path value.');
}

List _list(Object? value, String path) {
  if (value is List) return value;
  throw FormatException('Bearly returned an invalid Logistics $path list.');
}

String _string(Object? value) => value is String ? value.trim() : '';

int _integer(Object? value) {
  if (value is int && value >= 0) return value;
  final parsed = int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : 0;
}

double _number(Object? value) {
  if (value is num && value >= 0) return value.toDouble();
  final parsed = double.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : 0;
}
