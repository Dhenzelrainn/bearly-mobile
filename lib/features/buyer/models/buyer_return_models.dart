import 'buyer_checkout_models.dart';

class BuyerReturnAttachment {
  const BuyerReturnAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

class BuyerReturnFileContent {
  const BuyerReturnFileContent({required this.bytes, required this.mimeType});

  final List<int> bytes;
  final String mimeType;
}

class BuyerReturnWorkspace {
  BuyerReturnWorkspace({
    required this.sellerOrderId,
    required this.sellerOrderReference,
    required this.orderReference,
    required this.storeName,
    required this.status,
    required this.completedAt,
    required this.canRequest,
    required this.ineligibilityReason,
    required this.deadline,
    required Map<String, String> reasonCodes,
    required List<BuyerReturnDeliveryMethod> deliveryMethods,
    required this.dropoffCenter,
    required List<BuyerReturnItem> items,
    required List<BuyerReturnCaseSummary> cases,
  }) : reasonCodes = Map.unmodifiable(reasonCodes),
       deliveryMethods = List.unmodifiable(deliveryMethods),
       items = List.unmodifiable(items),
       cases = List.unmodifiable(cases);

  final int sellerOrderId;
  final String sellerOrderReference;
  final String orderReference;
  final String storeName;
  final String status;
  final DateTime? completedAt;
  final bool canRequest;
  final String? ineligibilityReason;
  final DateTime? deadline;
  final Map<String, String> reasonCodes;
  final List<BuyerReturnDeliveryMethod> deliveryMethods;
  final Map<String, Object?>? dropoffCenter;
  final List<BuyerReturnItem> items;
  final List<BuyerReturnCaseSummary> cases;

  factory BuyerReturnWorkspace.fromResponse(Object? value) {
    final root = buyerCheckoutMap(value, 'root');
    final json = buyerCheckoutMap(root['data'], 'data');
    final order = buyerCheckoutMap(json['seller_order'], 'seller_order');
    final reasons = buyerCheckoutMap(json['reason_codes'], 'reason_codes');
    final center = json['dropoff_center'] == null
        ? null
        : buyerCheckoutMap(json['dropoff_center'], 'dropoff_center');
    return BuyerReturnWorkspace(
      sellerOrderId: buyerCheckoutInt(order, 'id', 'seller_order'),
      sellerOrderReference: buyerCheckoutString(
        order,
        'reference',
        'seller_order',
      ),
      orderReference: buyerCheckoutString(
        order,
        'order_reference',
        'seller_order',
        allowEmpty: true,
      ),
      storeName: buyerCheckoutString(
        order,
        'store_name',
        'seller_order',
        allowEmpty: true,
      ),
      status: buyerCheckoutString(order, 'status', 'seller_order'),
      completedAt: buyerCheckoutOptionalDate(
        order,
        'completed_at',
        'seller_order',
      ),
      canRequest: buyerCheckoutBool(json, 'can_request', 'data'),
      ineligibilityReason: buyerCheckoutOptionalString(
        json,
        'ineligibility_reason',
        'data',
      ),
      deadline: buyerCheckoutOptionalDate(json, 'deadline', 'data'),
      reasonCodes: {
        for (final entry in reasons.entries)
          if (entry.value is String) entry.key: entry.value! as String,
      },
      deliveryMethods: buyerCheckoutList(
        json['delivery_methods'],
        'delivery_methods',
      ).map(BuyerReturnDeliveryMethod.fromJson).toList(growable: false),
      dropoffCenter: center,
      items: buyerCheckoutList(
        json['items'],
        'items',
      ).map(BuyerReturnItem.fromWorkspaceJson).toList(growable: false),
      cases: buyerCheckoutList(
        json['cases'],
        'cases',
      ).map(BuyerReturnCaseSummary.fromJson).toList(growable: false),
    );
  }
}

class BuyerReturnDeliveryMethod {
  const BuyerReturnDeliveryMethod({
    required this.value,
    required this.label,
    required this.available,
  });

  final String value;
  final String label;
  final bool available;

  factory BuyerReturnDeliveryMethod.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'delivery_methods[]');
    return BuyerReturnDeliveryMethod(
      value: buyerCheckoutString(json, 'value', 'delivery_method'),
      label: buyerCheckoutString(json, 'label', 'delivery_method'),
      available: buyerCheckoutBool(json, 'available', 'delivery_method'),
    );
  }
}

class BuyerReturnItem {
  const BuyerReturnItem({
    required this.id,
    required this.name,
    required this.variant,
    required this.sku,
    required this.quantity,
    required this.returnableQuantity,
    required this.unitPriceMinor,
    required this.imageUrl,
  });

  final int id;
  final String name;
  final String variant;
  final String sku;
  final int quantity;
  final int returnableQuantity;
  final int unitPriceMinor;
  final String? imageUrl;

  factory BuyerReturnItem.fromWorkspaceJson(Object? value) {
    final json = buyerCheckoutMap(value, 'items[]');
    return BuyerReturnItem(
      id: buyerCheckoutInt(json, 'id', 'item'),
      name: buyerCheckoutString(json, 'name', 'item', allowEmpty: true),
      variant: buyerCheckoutString(json, 'variant', 'item', allowEmpty: true),
      sku: buyerCheckoutString(json, 'sku', 'item', allowEmpty: true),
      quantity: buyerCheckoutInt(json, 'quantity', 'item'),
      returnableQuantity: buyerCheckoutInt(json, 'returnable_quantity', 'item'),
      unitPriceMinor: buyerCheckoutInt(json, 'unit_price_minor', 'item'),
      imageUrl: buyerCheckoutOptionalString(json, 'image_url', 'item'),
    );
  }
}

class BuyerReturnCaseSummary {
  const BuyerReturnCaseSummary({
    required this.id,
    required this.reference,
    required this.requestType,
    required this.status,
    required this.requestedAmountMinor,
    required this.submittedAt,
    required this.resolvedAt,
    required this.refunds,
  });

  final int id;
  final String reference;
  final String requestType;
  final String status;
  final int requestedAmountMinor;
  final DateTime? submittedAt;
  final DateTime? resolvedAt;
  final List<BuyerReturnRefund> refunds;

  factory BuyerReturnCaseSummary.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'cases[]');
    return BuyerReturnCaseSummary(
      id: buyerCheckoutInt(json, 'id', 'return'),
      reference: buyerCheckoutString(json, 'return_reference', 'return'),
      requestType: buyerCheckoutString(json, 'request_type', 'return'),
      status: buyerCheckoutString(json, 'status', 'return'),
      requestedAmountMinor: buyerCheckoutInt(
        json,
        'requested_amount_minor',
        'return',
      ),
      submittedAt: buyerCheckoutOptionalDate(json, 'submitted_at', 'return'),
      resolvedAt: buyerCheckoutOptionalDate(json, 'resolved_at', 'return'),
      refunds: buyerCheckoutList(
        json['refunds'],
        'return.refunds',
      ).map(BuyerReturnRefund.fromJson).toList(growable: false),
    );
  }
}

class BuyerReturnCase extends BuyerReturnCaseSummary {
  const BuyerReturnCase({
    required super.id,
    required super.reference,
    required super.requestType,
    required super.status,
    required super.requestedAmountMinor,
    required super.submittedAt,
    required super.resolvedAt,
    required super.refunds,
    required this.orderReference,
    required this.sellerOrderId,
    required this.storeName,
    required this.reasonLabel,
    required this.buyerNote,
    required this.resolution,
    required this.responseDueAt,
    required this.dropoffDueAt,
    required this.deliveryMethod,
    required this.canAddEvidence,
    required this.canSwitchToPickup,
    required this.evidence,
    required this.events,
    required this.shipment,
    required this.items,
  });

  final String orderReference;
  final int sellerOrderId;
  final String storeName;
  final String reasonLabel;
  final String? buyerNote;
  final String? resolution;
  final DateTime? responseDueAt;
  final DateTime? dropoffDueAt;
  final String? deliveryMethod;
  final bool canAddEvidence;
  final bool canSwitchToPickup;
  final List<BuyerReturnEvidence> evidence;
  final List<BuyerReturnEvent> events;
  final BuyerReturnShipment? shipment;
  final List<BuyerReturnCaseItem> items;

  factory BuyerReturnCase.fromResponse(Object? value) {
    final root = buyerCheckoutMap(value, 'root');
    final json = buyerCheckoutMap(root['data'], 'data');
    final shipmentValue = json['return_shipment'];
    return BuyerReturnCase(
      id: buyerCheckoutInt(json, 'id', 'return'),
      reference: buyerCheckoutString(json, 'return_reference', 'return'),
      requestType: buyerCheckoutString(json, 'request_type', 'return'),
      status: buyerCheckoutString(json, 'status', 'return'),
      requestedAmountMinor: buyerCheckoutInt(
        json,
        'requested_amount_minor',
        'return',
      ),
      submittedAt: buyerCheckoutOptionalDate(json, 'submitted_at', 'return'),
      resolvedAt: buyerCheckoutOptionalDate(json, 'resolved_at', 'return'),
      refunds: buyerCheckoutList(
        json['refunds'],
        'return.refunds',
      ).map(BuyerReturnRefund.fromJson).toList(growable: false),
      orderReference: buyerCheckoutString(
        json,
        'order_reference',
        'return',
        allowEmpty: true,
      ),
      sellerOrderId: buyerCheckoutInt(json, 'seller_order_id', 'return'),
      storeName: buyerCheckoutString(json, 'store_name', 'return'),
      reasonLabel: buyerCheckoutString(json, 'reason_label', 'return'),
      buyerNote: buyerCheckoutOptionalString(json, 'buyer_note', 'return'),
      resolution: buyerCheckoutOptionalString(json, 'resolution', 'return'),
      responseDueAt: buyerCheckoutOptionalDate(
        json,
        'response_due_at',
        'return',
      ),
      dropoffDueAt: buyerCheckoutOptionalDate(json, 'dropoff_due_at', 'return'),
      deliveryMethod: buyerCheckoutOptionalString(
        json,
        'delivery_method',
        'return',
      ),
      canAddEvidence: buyerCheckoutBool(json, 'can_add_evidence', 'return'),
      canSwitchToPickup: buyerCheckoutBool(
        json,
        'can_switch_to_pickup',
        'return',
      ),
      evidence: buyerCheckoutList(
        json['evidence'],
        'return.evidence',
      ).map(BuyerReturnEvidence.fromJson).toList(growable: false),
      events: buyerCheckoutList(
        json['events'],
        'return.events',
      ).map(BuyerReturnEvent.fromJson).toList(growable: false),
      shipment: shipmentValue == null
          ? null
          : BuyerReturnShipment.fromJson(shipmentValue),
      items: buyerCheckoutList(
        json['items'],
        'return.items',
      ).map(BuyerReturnCaseItem.fromJson).toList(growable: false),
    );
  }
}

class BuyerReturnEvidence {
  const BuyerReturnEvidence({
    required this.id,
    required this.name,
    required this.type,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final int id;
  final String name;
  final String type;
  final String mimeType;
  final int sizeBytes;
  final DateTime? uploadedAt;

  factory BuyerReturnEvidence.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'evidence[]');
    return BuyerReturnEvidence(
      id: buyerCheckoutInt(json, 'id', 'evidence'),
      name: buyerCheckoutString(json, 'name', 'evidence'),
      type: buyerCheckoutString(json, 'type', 'evidence'),
      mimeType: buyerCheckoutString(json, 'mime_type', 'evidence'),
      sizeBytes: buyerCheckoutInt(json, 'size_bytes', 'evidence'),
      uploadedAt: buyerCheckoutOptionalDate(json, 'uploaded_at', 'evidence'),
    );
  }
}

class BuyerReturnEvent {
  const BuyerReturnEvent({
    required this.id,
    required this.type,
    required this.fromStatus,
    required this.toStatus,
    required this.note,
    required this.actorName,
    required this.occurredAt,
  });

  final int id;
  final String type;
  final String? fromStatus;
  final String? toStatus;
  final String? note;
  final String actorName;
  final DateTime? occurredAt;

  factory BuyerReturnEvent.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'events[]');
    return BuyerReturnEvent(
      id: buyerCheckoutInt(json, 'id', 'event'),
      type: buyerCheckoutString(json, 'event_type', 'event'),
      fromStatus: buyerCheckoutOptionalString(json, 'from_status', 'event'),
      toStatus: buyerCheckoutOptionalString(json, 'to_status', 'event'),
      note: buyerCheckoutOptionalString(json, 'note', 'event'),
      actorName: buyerCheckoutString(json, 'actor_name', 'event'),
      occurredAt: buyerCheckoutOptionalDate(json, 'occurred_at', 'event'),
    );
  }
}

class BuyerReturnShipment {
  const BuyerReturnShipment({
    required this.reference,
    required this.status,
    required this.waybillReference,
    required this.shippingFeeMinor,
    required this.dropoffCenter,
    required this.events,
  });

  final String reference;
  final String status;
  final String? waybillReference;
  final int shippingFeeMinor;
  final Map<String, Object?>? dropoffCenter;
  final List<BuyerReturnShipmentEvent> events;

  factory BuyerReturnShipment.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'return_shipment');
    final centerValue = json['dropoff_center'];
    return BuyerReturnShipment(
      reference: buyerCheckoutString(json, 'reference', 'shipment'),
      status: buyerCheckoutString(json, 'status', 'shipment'),
      waybillReference: buyerCheckoutOptionalString(
        json,
        'waybill_reference',
        'shipment',
      ),
      shippingFeeMinor: buyerCheckoutInt(
        json,
        'shipping_fee_minor',
        'shipment',
      ),
      dropoffCenter: centerValue == null
          ? null
          : buyerCheckoutMap(centerValue, 'shipment.dropoff_center'),
      events: buyerCheckoutList(
        json['events'],
        'shipment.events',
      ).map(BuyerReturnShipmentEvent.fromJson).toList(growable: false),
    );
  }
}

class BuyerReturnShipmentEvent {
  const BuyerReturnShipmentEvent({
    required this.type,
    required this.status,
    required this.note,
    required this.occurredAt,
  });

  final String type;
  final String status;
  final String? note;
  final DateTime? occurredAt;

  factory BuyerReturnShipmentEvent.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'shipment.events[]');
    return BuyerReturnShipmentEvent(
      type: buyerCheckoutString(json, 'event_type', 'shipment.event'),
      status: buyerCheckoutString(json, 'status', 'shipment.event'),
      note: buyerCheckoutOptionalString(json, 'note', 'shipment.event'),
      occurredAt: buyerCheckoutOptionalDate(
        json,
        'occurred_at',
        'shipment.event',
      ),
    );
  }
}

class BuyerReturnRefund {
  const BuyerReturnRefund({
    required this.id,
    required this.reference,
    required this.status,
    required this.approvedAmountMinor,
    required this.paidAmountMinor,
    required this.method,
    required this.providerReference,
    required this.financiallyResponsibleParty,
    required this.paidOn,
    required this.completedAt,
    required this.receiptAvailable,
  });

  final int? id;
  final String? reference;
  final String status;
  final int approvedAmountMinor;
  final int? paidAmountMinor;
  final String? method;
  final String? providerReference;
  final String? financiallyResponsibleParty;
  final DateTime? paidOn;
  final DateTime? completedAt;
  final bool receiptAvailable;

  factory BuyerReturnRefund.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'refunds[]');
    final amount = json['approved_amount_minor'] ?? json['amount_minor'];
    final paid = json['paid_amount_minor'];
    if (amount is! int || (paid != null && paid is! int)) {
      throw const BuyerCheckoutFormatException('refund.amount_minor');
    }
    return BuyerReturnRefund(
      id: buyerCheckoutOptionalInt(json, 'id', 'refund'),
      reference: buyerCheckoutOptionalString(
        json,
        'refund_reference',
        'refund',
      ),
      status: buyerCheckoutString(json, 'status', 'refund'),
      approvedAmountMinor: amount,
      paidAmountMinor: paid as int?,
      method: buyerCheckoutOptionalString(json, 'method', 'refund'),
      providerReference: buyerCheckoutOptionalString(
        json,
        'provider_reference',
        'refund',
      ),
      financiallyResponsibleParty: buyerCheckoutOptionalString(
        json,
        'financially_responsible_party',
        'refund',
      ),
      paidOn: buyerCheckoutOptionalDate(json, 'external_paid_on', 'refund'),
      completedAt: buyerCheckoutOptionalDate(json, 'completed_at', 'refund'),
      receiptAvailable: json['receipt_available'] == true,
    );
  }
}

class BuyerReturnCaseItem {
  const BuyerReturnCaseItem({
    required this.orderItemId,
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.refundAmountMinor,
  });

  final int orderItemId;
  final String productName;
  final String variantName;
  final int quantity;
  final int refundAmountMinor;

  factory BuyerReturnCaseItem.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'return.items[]');
    return BuyerReturnCaseItem(
      orderItemId: buyerCheckoutInt(json, 'order_item_id', 'return.item'),
      productName: buyerCheckoutString(json, 'product_name', 'return.item'),
      variantName: buyerCheckoutString(
        json,
        'variant_name',
        'return.item',
        allowEmpty: true,
      ),
      quantity: buyerCheckoutInt(json, 'quantity', 'return.item'),
      refundAmountMinor: buyerCheckoutInt(
        json,
        'refund_amount_minor',
        'return.item',
      ),
    );
  }
}
