class LogisticsCashCustodyPageMeta {
  const LogisticsCashCustodyPageMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory LogisticsCashCustodyPageMeta.fromJson(Object? value) {
    final json = _map(value, 'cash custody pagination');
    return LogisticsCashCustodyPageMeta(
      currentPage: _integer(json['current_page'], 'current_page'),
      lastPage: _integer(json['last_page'], 'last_page'),
      perPage: _integer(json['per_page'], 'per_page'),
      total: _integer(json['total'], 'total'),
    );
  }
}

class LogisticsCashCustodyHistoryEvent {
  const LogisticsCashCustodyHistoryEvent({
    required this.type,
    this.from,
    this.to,
    this.amountMinor,
    this.reference,
    this.occurredAt,
  });

  final String type;
  final String? from;
  final String? to;
  final int? amountMinor;
  final String? reference;
  final String? occurredAt;

  factory LogisticsCashCustodyHistoryEvent.fromJson(
    Object? value, {
    required bool refund,
  }) {
    final json = _map(value, 'cash custody history event');
    return LogisticsCashCustodyHistoryEvent(
      type: _string(json['event_type'], 'event_type'),
      from: _optionalString(refund ? json['from_status'] : json['from_role']),
      to: _optionalString(refund ? json['to_status'] : json['to_role']),
      amountMinor: _optionalInteger(json['amount_minor'], 'amount_minor'),
      reference: _optionalString(json['reference']),
      occurredAt: _optionalString(json['occurred_at']),
    );
  }
}

class LogisticsCodCashAllocation {
  const LogisticsCodCashAllocation({
    this.orderNo,
    this.sellerOrderNo,
    this.paymentNo,
    required this.amountDueMinor,
    required this.amountCollectedMinor,
    this.amountReconciledMinor,
  });

  final String? orderNo;
  final String? sellerOrderNo;
  final String? paymentNo;
  final int amountDueMinor;
  final int amountCollectedMinor;
  final int? amountReconciledMinor;

  factory LogisticsCodCashAllocation.fromJson(Object? value) {
    final json = _map(value, 'COD allocation');
    return LogisticsCodCashAllocation(
      orderNo: _optionalString(json['order_no']),
      sellerOrderNo: _optionalString(json['seller_order_no']),
      paymentNo: _optionalString(json['payment_no']),
      amountDueMinor: _integer(json['amount_due_minor'], 'amount_due_minor'),
      amountCollectedMinor: _integer(
        json['amount_collected_minor'],
        'amount_collected_minor',
      ),
      amountReconciledMinor: _optionalInteger(
        json['amount_reconciled_minor'],
        'amount_reconciled_minor',
      ),
    );
  }
}

class LogisticsCodCashCollection {
  const LogisticsCodCashCollection({
    required this.id,
    required this.collectionNo,
    required this.status,
    required this.amountDueMinor,
    required this.amountCollectedMinor,
    required this.discrepancyMinor,
    this.amountReceivedByLogisticsMinor,
    this.amountRemittedToFinanceMinor,
    this.amountReconciledMinor,
    this.riderName,
    this.paymentNo,
    this.paymentStatus,
    this.paymentPaidAt,
    required this.allocations,
    required this.references,
    required this.timestamps,
    required this.history,
  });

  final int id;
  final String collectionNo;
  final String status;
  final int amountDueMinor;
  final int amountCollectedMinor;
  final int discrepancyMinor;
  final int? amountReceivedByLogisticsMinor;
  final int? amountRemittedToFinanceMinor;
  final int? amountReconciledMinor;
  final String? riderName;
  final String? paymentNo;
  final String? paymentStatus;
  final String? paymentPaidAt;
  final List<LogisticsCodCashAllocation> allocations;
  final Map<String, String?> references;
  final Map<String, String?> timestamps;
  final List<LogisticsCashCustodyHistoryEvent> history;

  factory LogisticsCodCashCollection.fromJson(Object? value) {
    final json = _map(value, 'COD collection');
    final payment = json['payment'] == null
        ? <String, Object?>{}
        : _map(json['payment'], 'COD payment');
    return LogisticsCodCashCollection(
      id: _integer(json['id'], 'id'),
      collectionNo: _string(json['collection_no'], 'collection_no'),
      status: _string(json['status'], 'status'),
      amountDueMinor: _integer(json['amount_due_minor'], 'amount_due_minor'),
      amountCollectedMinor: _integer(
        json['amount_collected_minor'],
        'amount_collected_minor',
      ),
      discrepancyMinor: _integer(
        json['discrepancy_minor'],
        'discrepancy_minor',
      ),
      amountReceivedByLogisticsMinor: _optionalInteger(
        json['amount_received_by_logistics_minor'],
        'amount_received_by_logistics_minor',
      ),
      amountRemittedToFinanceMinor: _optionalInteger(
        json['amount_remitted_to_finance_minor'],
        'amount_remitted_to_finance_minor',
      ),
      amountReconciledMinor: _optionalInteger(
        json['amount_reconciled_minor'],
        'amount_reconciled_minor',
      ),
      riderName: _optionalString(json['rider_name']),
      paymentNo: _optionalString(payment['payment_no']),
      paymentStatus: _optionalString(payment['status']),
      paymentPaidAt: _optionalString(payment['paid_at']),
      allocations: _list(
        json['allocations'],
        'allocations',
      ).map(LogisticsCodCashAllocation.fromJson).toList(growable: false),
      references: _stringMap(json['references'], 'references'),
      timestamps: _stringMap(json['timestamps'], 'timestamps'),
      history: _list(json['history'], 'history')
          .map(
            (item) =>
                LogisticsCashCustodyHistoryEvent.fromJson(item, refund: false),
          )
          .toList(growable: false),
    );
  }
}

class LogisticsRefundCashPayout {
  const LogisticsRefundCashPayout({
    required this.id,
    required this.payoutNo,
    this.refundNo,
    this.returnNo,
    required this.status,
    required this.amountMinor,
    this.riderName,
    this.acknowledgmentReference,
    required this.timestamps,
    required this.history,
  });

  final int id;
  final String payoutNo;
  final String? refundNo;
  final String? returnNo;
  final String status;
  final int amountMinor;
  final String? riderName;
  final String? acknowledgmentReference;
  final Map<String, String?> timestamps;
  final List<LogisticsCashCustodyHistoryEvent> history;

  factory LogisticsRefundCashPayout.fromJson(Object? value) {
    final json = _map(value, 'refund cash payout');
    return LogisticsRefundCashPayout(
      id: _integer(json['id'], 'id'),
      payoutNo: _string(json['payout_no'], 'payout_no'),
      refundNo: _optionalString(json['refund_no']),
      returnNo: _optionalString(json['return_no']),
      status: _string(json['status'], 'status'),
      amountMinor: _integer(json['amount_minor'], 'amount_minor'),
      riderName: _optionalString(json['rider_name']),
      acknowledgmentReference: _optionalString(
        json['acknowledgment_reference'],
      ),
      timestamps: _stringMap(json['timestamps'], 'timestamps'),
      history: _list(json['history'], 'history')
          .map(
            (item) =>
                LogisticsCashCustodyHistoryEvent.fromJson(item, refund: true),
          )
          .toList(growable: false),
    );
  }
}

class LogisticsCashCustodyPage<T> {
  const LogisticsCashCustodyPage({required this.items, required this.meta});

  final List<T> items;
  final LogisticsCashCustodyPageMeta meta;

  factory LogisticsCashCustodyPage.fromJson(
    Object? value,
    T Function(Object?) parse,
  ) {
    final json = _map(value, 'cash custody list');
    return LogisticsCashCustodyPage<T>(
      items: _list(json['data'], 'data').map(parse).toList(growable: false),
      meta: LogisticsCashCustodyPageMeta.fromJson(json['meta']),
    );
  }
}

class LogisticsCashCustody {
  const LogisticsCashCustody({
    required this.currency,
    required this.providerName,
    required this.codCollectionCount,
    required this.activeRefundCashCount,
    required this.codCollections,
    required this.refundCash,
  });

  final String currency;
  final String providerName;
  final int codCollectionCount;
  final int activeRefundCashCount;
  final LogisticsCashCustodyPage<LogisticsCodCashCollection> codCollections;
  final LogisticsCashCustodyPage<LogisticsRefundCashPayout> refundCash;

  factory LogisticsCashCustody.fromResponse(Object? value) {
    final response = _map(value, 'cash custody response');
    final data = _map(response['data'], 'cash custody data');
    final provider = _map(data['provider'], 'provider');
    final summary = _map(data['summary'], 'summary');
    return LogisticsCashCustody(
      currency: _string(data['currency'], 'currency'),
      providerName: _string(provider['name'], 'provider name'),
      codCollectionCount: _integer(
        summary['cod_collection_count'],
        'cod_collection_count',
      ),
      activeRefundCashCount: _integer(
        summary['active_refund_cash_count'],
        'active_refund_cash_count',
      ),
      codCollections:
          LogisticsCashCustodyPage<LogisticsCodCashCollection>.fromJson(
            data['cod_collections'],
            LogisticsCodCashCollection.fromJson,
          ),
      refundCash: LogisticsCashCustodyPage<LogisticsRefundCashPayout>.fromJson(
        data['refund_cash'],
        LogisticsRefundCashPayout.fromJson,
      ),
    );
  }
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('Missing $field object.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) throw FormatException('Missing $field list.');
  return value.cast<Object?>();
}

String _string(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $field text.');
  }
  return value;
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int _integer(Object? value, String field) {
  if (value is int) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid $field integer.');
}

int? _optionalInteger(Object? value, String field) =>
    value == null ? null : _integer(value, field);

Map<String, String?> _stringMap(Object? value, String field) {
  final json = _map(value, field);
  return json.map((key, value) => MapEntry(key, _optionalString(value)));
}
