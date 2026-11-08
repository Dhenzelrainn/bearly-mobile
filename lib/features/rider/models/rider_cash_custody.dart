class RiderCashCustodyEvent {
  const RiderCashCustodyEvent({
    required this.type,
    required this.at,
    this.status,
    this.amountMinor,
    this.reference,
    this.note,
  });

  final String type;
  final DateTime? at;
  final String? status;
  final int? amountMinor;
  final String? reference;
  final String? note;

  factory RiderCashCustodyEvent.fromJson(Object? value) {
    final json = _cashMap(value, 'event');
    return RiderCashCustodyEvent(
      type: _cashString(json['event_type'], 'event.event_type'),
      at: _cashDate(json['occurred_at']),
      status: _cashOptionalString(json['to_status']),
      amountMinor: _cashOptionalInt(json['amount_minor']),
      reference: _cashOptionalString(json['reference']),
      note: _cashOptionalString(json['note']),
    );
  }
}

class RiderCodCashRecord {
  const RiderCodCashRecord({
    required this.collectionNo,
    required this.amountDueMinor,
    required this.amountCollectedMinor,
    required this.discrepancyMinor,
    required this.status,
    required this.collectedAt,
    required this.events,
    this.amountReceivedByLogisticsMinor,
    this.amountRemittedToFinanceMinor,
    this.amountReconciledMinor,
    this.logisticsReference,
    this.logisticsReceivedAt,
    this.financeRemittanceReference,
    this.remittedToFinanceAt,
    this.financeReference,
    this.reconciledAt,
  });

  final String collectionNo;
  final int amountDueMinor;
  final int amountCollectedMinor;
  final int discrepancyMinor;
  final int? amountReceivedByLogisticsMinor;
  final int? amountRemittedToFinanceMinor;
  final int? amountReconciledMinor;
  final String status;
  final DateTime? collectedAt;
  final String? logisticsReference;
  final DateTime? logisticsReceivedAt;
  final String? financeRemittanceReference;
  final DateTime? remittedToFinanceAt;
  final String? financeReference;
  final DateTime? reconciledAt;
  final List<RiderCashCustodyEvent> events;

  factory RiderCodCashRecord.fromJson(Object? value) {
    final json = _cashMap(value, 'cod_collection');
    return RiderCodCashRecord(
      collectionNo: _cashString(json['collection_no'], 'collection_no'),
      amountDueMinor: _cashInt(json['amount_due_minor'], 'amount_due_minor'),
      amountCollectedMinor: _cashInt(
        json['amount_collected_minor'],
        'amount_collected_minor',
      ),
      discrepancyMinor: _cashInt(
        json['discrepancy_minor'],
        'discrepancy_minor',
      ),
      amountReceivedByLogisticsMinor: _cashOptionalInt(
        json['amount_received_by_logistics_minor'],
      ),
      amountRemittedToFinanceMinor: _cashOptionalInt(
        json['amount_remitted_to_finance_minor'],
      ),
      amountReconciledMinor: _cashOptionalInt(json['amount_reconciled_minor']),
      status: _cashString(json['status'], 'status'),
      collectedAt: _cashDate(json['collected_at']),
      logisticsReference: _cashOptionalString(json['logistics_reference']),
      logisticsReceivedAt: _cashDate(json['logistics_received_at']),
      financeRemittanceReference: _cashOptionalString(
        json['finance_remittance_reference'],
      ),
      remittedToFinanceAt: _cashDate(json['remitted_to_finance_at']),
      financeReference: _cashOptionalString(json['finance_reference']),
      reconciledAt: _cashDate(json['reconciled_at']),
      events: _cashList(
        json['events'],
        'events',
      ).map(RiderCashCustodyEvent.fromJson).toList(growable: false),
    );
  }
}

class RiderRefundCashRecord {
  const RiderRefundCashRecord({
    required this.payoutNo,
    required this.amountMinor,
    required this.status,
    required this.events,
    this.acknowledgmentReference,
    this.assignedAt,
    this.receivedByRiderAt,
    this.startedAt,
    this.lastAttemptAt,
    this.cashReturnedToLogisticsAt,
    this.deliveredAt,
    this.logisticsVerifiedAt,
    this.completedAt,
  });

  final String payoutNo;
  final int amountMinor;
  final String status;
  final String? acknowledgmentReference;
  final DateTime? assignedAt;
  final DateTime? receivedByRiderAt;
  final DateTime? startedAt;
  final DateTime? lastAttemptAt;
  final DateTime? cashReturnedToLogisticsAt;
  final DateTime? deliveredAt;
  final DateTime? logisticsVerifiedAt;
  final DateTime? completedAt;
  final List<RiderCashCustodyEvent> events;

  factory RiderRefundCashRecord.fromJson(Object? value) {
    final json = _cashMap(value, 'refund_cash');
    return RiderRefundCashRecord(
      payoutNo: _cashString(json['payout_no'], 'payout_no'),
      amountMinor: _cashInt(json['amount_minor'], 'amount_minor'),
      status: _cashString(json['status'], 'status'),
      acknowledgmentReference: _cashOptionalString(
        json['acknowledgment_reference'],
      ),
      assignedAt: _cashDate(json['assigned_at']),
      receivedByRiderAt: _cashDate(json['received_by_rider_at']),
      startedAt: _cashDate(json['started_at']),
      lastAttemptAt: _cashDate(json['last_attempt_at']),
      cashReturnedToLogisticsAt: _cashDate(
        json['cash_returned_to_logistics_at'],
      ),
      deliveredAt: _cashDate(json['delivered_at']),
      logisticsVerifiedAt: _cashDate(json['logistics_verified_at']),
      completedAt: _cashDate(json['completed_at']),
      events: _cashList(
        json['events'],
        'events',
      ).map(RiderCashCustodyEvent.fromJson).toList(growable: false),
    );
  }
}

class RiderCashCustodySummary {
  const RiderCashCustodySummary({
    required this.codCollectedMinor,
    required this.codHandoffPendingMinor,
    required this.refundCashWithRiderMinor,
  });

  final int codCollectedMinor;
  final int codHandoffPendingMinor;
  final int refundCashWithRiderMinor;

  factory RiderCashCustodySummary.fromJson(Object? value) {
    final json = _cashMap(value, 'summary');
    return RiderCashCustodySummary(
      codCollectedMinor: _cashInt(
        json['cod_collected_minor'],
        'cod_collected_minor',
      ),
      codHandoffPendingMinor: _cashInt(
        json['cod_handoff_pending_minor'],
        'cod_handoff_pending_minor',
      ),
      refundCashWithRiderMinor: _cashInt(
        json['refund_cash_with_rider_minor'],
        'refund_cash_with_rider_minor',
      ),
    );
  }
}

class RiderCashCustody {
  const RiderCashCustody({
    required this.summary,
    required this.codCollections,
    required this.refundCash,
  });

  final RiderCashCustodySummary summary;
  final List<RiderCodCashRecord> codCollections;
  final List<RiderRefundCashRecord> refundCash;

  bool get isEmpty => codCollections.isEmpty && refundCash.isEmpty;

  factory RiderCashCustody.fromJson(Object? value) {
    final json = _cashMap(value, 'data');
    return RiderCashCustody(
      summary: RiderCashCustodySummary.fromJson(json['summary']),
      codCollections: _cashList(
        json['cod_collections'],
        'cod_collections',
      ).map(RiderCodCashRecord.fromJson).toList(growable: false),
      refundCash: _cashList(
        json['refund_cash'],
        'refund_cash',
      ).map(RiderRefundCashRecord.fromJson).toList(growable: false),
    );
  }
}

Map<String, Object?> _cashMap(Object? value, String field) {
  if (value is! Map) throw FormatException('Invalid cash custody $field.');
  return Map<String, Object?>.from(value);
}

List<Object?> _cashList(Object? value, String field) {
  if (value is! List) throw FormatException('Invalid cash custody $field.');
  return List<Object?>.from(value);
}

String _cashString(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid cash custody $field.');
  }
  return value;
}

String? _cashOptionalString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _cashInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('Invalid cash custody $field.');
}

int? _cashOptionalInt(Object? value) =>
    value == null ? null : _cashInt(value, 'amount');

DateTime? _cashDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
