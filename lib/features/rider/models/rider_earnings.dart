class RiderEarningsData {
  const RiderEarningsData({
    required this.workType,
    required this.currency,
    required this.summary,
    required this.courierDaily,
    required this.entries,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final String workType;
  final String currency;
  final RiderEarningsSummary summary;
  final RiderCourierEarningsSummary? courierDaily;
  final List<RiderEarningRecord> entries;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  RiderEarningsData copyWith({
    List<RiderEarningRecord>? entries,
    int? currentPage,
    int? lastPage,
    int? total,
  }) => RiderEarningsData(
    workType: workType,
    currency: currency,
    summary: summary,
    courierDaily: courierDaily,
    entries: entries ?? this.entries,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    perPage: perPage,
    total: total ?? this.total,
  );

  factory RiderEarningsData.fromJson(Object? value) {
    final root = _map(value, 'earnings response');
    final data = _map(root['data'], 'earnings data');
    final meta = _map(data['meta'], 'earnings metadata');
    final courier = data['courier_daily'];

    return RiderEarningsData(
      workType: _string(data['work_type']),
      currency: _string(data['currency']),
      summary: RiderEarningsSummary.fromJson(data['summary']),
      courierDaily: courier == null
          ? null
          : RiderCourierEarningsSummary.fromJson(courier),
      entries: _list(
        data['items'],
      ).map(RiderEarningRecord.fromJson).toList(growable: false),
      currentPage: _integer(meta['current_page']),
      lastPage: _integer(meta['last_page']),
      perPage: _integer(meta['per_page']),
      total: _integer(meta['total']),
    );
  }
}

class RiderEarningsSummary {
  const RiderEarningsSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.activeTotalMinor,
    required this.activeTotal,
    required this.activeEntries,
    required this.pickupTotalMinor,
    required this.pickupTotal,
    required this.pickupHeldMinor,
    required this.pickupHeld,
    required this.deliveryTotalMinor,
    required this.deliveryTotal,
    required this.deliveryPendingMinor,
    required this.deliveryPending,
    required this.courierDailyMinor,
    required this.courierDaily,
    required this.combinedTotalMinor,
    required this.combinedTotal,
    required this.payoutEligibleMinor,
    required this.payoutEligible,
    required this.payoutPaidMinor,
    required this.payoutPaid,
    required this.payoutStatus,
  });

  final RiderEarningsPeriod today;
  final RiderEarningsPeriod week;
  final RiderEarningsPeriod month;
  final int activeTotalMinor;
  final String activeTotal;
  final int activeEntries;
  final int pickupTotalMinor;
  final String pickupTotal;
  final int pickupHeldMinor;
  final String pickupHeld;
  final int deliveryTotalMinor;
  final String deliveryTotal;
  final int deliveryPendingMinor;
  final String deliveryPending;
  final int courierDailyMinor;
  final String courierDaily;
  final int combinedTotalMinor;
  final String combinedTotal;
  final int payoutEligibleMinor;
  final String payoutEligible;
  final int payoutPaidMinor;
  final String payoutPaid;
  final String payoutStatus;

  factory RiderEarningsSummary.fromJson(Object? value) {
    final map = _map(value, 'earnings summary');
    return RiderEarningsSummary(
      today: RiderEarningsPeriod.fromJson(map['today']),
      week: RiderEarningsPeriod.fromJson(map['week']),
      month: RiderEarningsPeriod.fromJson(map['month']),
      activeTotalMinor: _integer(map['active_total_minor']),
      activeTotal: _string(map['active_total']),
      activeEntries: _integer(map['active_entries']),
      pickupTotalMinor: _integer(map['pickup_total_minor']),
      pickupTotal: _string(map['pickup_total']),
      pickupHeldMinor: _integer(map['pickup_held_minor']),
      pickupHeld: _string(map['pickup_held']),
      deliveryTotalMinor: _integer(map['delivery_total_minor']),
      deliveryTotal: _string(map['delivery_total']),
      deliveryPendingMinor: _integer(map['delivery_pending_minor']),
      deliveryPending: _string(map['delivery_pending']),
      courierDailyMinor: _integer(map['courier_daily_minor']),
      courierDaily: _string(map['courier_daily']),
      combinedTotalMinor: _integer(map['combined_total_minor']),
      combinedTotal: _string(map['combined_total']),
      payoutEligibleMinor: _integer(map['payout_eligible_minor']),
      payoutEligible: _string(map['payout_eligible']),
      payoutPaidMinor: _integer(map['payout_paid_minor']),
      payoutPaid: _string(map['payout_paid']),
      payoutStatus: _string(map['payout_status']),
    );
  }
}

class RiderEarningsPeriod {
  const RiderEarningsPeriod({
    required this.amountMinor,
    required this.amount,
    required this.entries,
  });

  final int amountMinor;
  final String amount;
  final int entries;

  factory RiderEarningsPeriod.fromJson(Object? value) {
    final map = _map(value, 'earnings period');
    return RiderEarningsPeriod(
      amountMinor: _integer(map['amount_minor']),
      amount: _string(map['amount']),
      entries: _integer(map['entries']),
    );
  }
}

class RiderCourierEarningsSummary {
  const RiderCourierEarningsSummary({
    required this.rateMinor,
    required this.rate,
    required this.todayWorkDate,
    required this.qualifyingDays,
    required this.totalMinor,
    required this.total,
    required this.eligibleMinor,
    required this.eligible,
    required this.paidMinor,
    required this.paid,
  });

  final int rateMinor;
  final String rate;
  final String todayWorkDate;
  final int qualifyingDays;
  final int totalMinor;
  final String total;
  final int eligibleMinor;
  final String eligible;
  final int paidMinor;
  final String paid;

  factory RiderCourierEarningsSummary.fromJson(Object? value) {
    final map = _map(value, 'Courier earnings summary');
    return RiderCourierEarningsSummary(
      rateMinor: _integer(map['rate_minor']),
      rate: _string(map['rate']),
      todayWorkDate: _string(map['today_work_date']),
      qualifyingDays: _integer(map['qualifying_days']),
      totalMinor: _integer(map['total_minor']),
      total: _string(map['total']),
      eligibleMinor: _integer(map['eligible_minor']),
      eligible: _string(map['eligible']),
      paidMinor: _integer(map['paid_minor']),
      paid: _string(map['paid']),
    );
  }
}

class RiderEarningRecord {
  const RiderEarningRecord({
    required this.id,
    required this.earnedAt,
    required this.earnedAtIso,
    required this.workDate,
    required this.job,
    required this.source,
    required this.type,
    required this.typeLabel,
    required this.amountMinor,
    required this.amount,
    required this.status,
    required this.statusLabel,
    required this.postedAt,
    required this.paidAt,
    required this.description,
    required this.linehaulRunNumber,
  });

  final int id;
  final String earnedAt;
  final String earnedAtIso;
  final String workDate;
  final String job;
  final String source;
  final String type;
  final String typeLabel;
  final int amountMinor;
  final String amount;
  final String status;
  final String statusLabel;
  final String postedAt;
  final String paidAt;
  final String description;
  final String linehaulRunNumber;

  bool get isCourierDaily => type == 'courier_daily';

  factory RiderEarningRecord.fromJson(Object? value) {
    final map = _map(value, 'earning record');
    return RiderEarningRecord(
      id: _integer(map['id']),
      earnedAt: _string(map['earned_at']),
      earnedAtIso: _string(map['earned_at_iso']),
      workDate: _string(map['work_date_label'] ?? map['work_date']),
      job: _string(map['job']),
      source: _string(map['source']),
      type: _string(map['type']),
      typeLabel: _string(map['type_label']),
      amountMinor: _integer(map['amount_minor']),
      amount: _string(map['amount']),
      status: _string(map['status']),
      statusLabel: _string(map['status_label']),
      postedAt: _string(map['posted_at']),
      paidAt: _string(map['paid_at']),
      description: _string(map['description']),
      linehaulRunNumber: _string(map['linehaul_run_no']),
    );
  }
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Bearly returned invalid $label data.');
  }
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String _string(Object? value) => value is String ? value : '';

int _integer(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
