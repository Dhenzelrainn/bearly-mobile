import 'buyer_checkout_models.dart';

class BuyerOrderTracking {
  BuyerOrderTracking({
    required this.orderId,
    required this.orderReference,
    required this.orderStatus,
    required this.paymentStatus,
    required this.placedAt,
    required this.trackingState,
    required this.shipmentCount,
    required this.buyerReceiptConfirmed,
    required this.buyerReceiptConfirmedAt,
    required List<BuyerTrackedSellerOrder> sellerOrders,
  }) : sellerOrders = List.unmodifiable(sellerOrders);

  final int orderId;
  final String orderReference;
  final String orderStatus;
  final String paymentStatus;
  final DateTime? placedAt;
  final String trackingState;
  final int shipmentCount;
  final bool buyerReceiptConfirmed;
  final DateTime? buyerReceiptConfirmedAt;
  final List<BuyerTrackedSellerOrder> sellerOrders;

  factory BuyerOrderTracking.fromResponse(Object? value) {
    final root = buyerCheckoutMap(value, 'root');
    final data = buyerCheckoutMap(root['data'], 'data');
    final result = BuyerOrderTracking(
      orderId: buyerCheckoutInt(data, 'order_id', 'data'),
      orderReference: buyerCheckoutString(data, 'order_reference', 'data'),
      orderStatus: buyerCheckoutString(data, 'order_status', 'data'),
      paymentStatus: buyerCheckoutString(data, 'payment_status', 'data'),
      placedAt: buyerCheckoutOptionalDate(data, 'placed_at', 'data'),
      trackingState: buyerCheckoutString(data, 'tracking_state', 'data'),
      shipmentCount: buyerCheckoutInt(data, 'shipment_count', 'data'),
      buyerReceiptConfirmed: buyerCheckoutBool(
        data,
        'buyer_receipt_confirmed',
        'data',
      ),
      buyerReceiptConfirmedAt: buyerCheckoutOptionalDate(
        data,
        'buyer_receipt_confirmed_at',
        'data',
      ),
      sellerOrders: buyerCheckoutList(
        data['seller_orders'],
        'seller_orders',
      ).map(BuyerTrackedSellerOrder.fromJson).toList(growable: false),
    );
    if (result.orderId < 1 ||
        result.shipmentCount < 0 ||
        !const {'pending', 'available'}.contains(result.trackingState)) {
      throw const BuyerCheckoutFormatException('data');
    }
    return result;
  }
}

class BuyerTrackedSellerOrder {
  BuyerTrackedSellerOrder({
    required this.id,
    required this.reference,
    required this.status,
    required List<BuyerTrackedStatusChange> statusHistory,
    required List<BuyerTrackedShipment> shipments,
  }) : statusHistory = List.unmodifiable(statusHistory),
       shipments = List.unmodifiable(shipments);

  final int id;
  final String reference;
  final String status;
  final List<BuyerTrackedStatusChange> statusHistory;
  final List<BuyerTrackedShipment> shipments;

  factory BuyerTrackedSellerOrder.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'seller_order');
    final history = buyerCheckoutList(
      json['status_history'],
      'status_history',
    ).map(BuyerTrackedStatusChange.fromJson).toList(growable: false);
    final shipments = buyerCheckoutList(
      json['shipments'],
      'shipments',
    ).map(BuyerTrackedShipment.fromJson).toList(growable: false);
    if (history.length > 100) {
      throw const BuyerCheckoutFormatException('status_history');
    }
    return BuyerTrackedSellerOrder(
      id: buyerCheckoutInt(json, 'id', 'seller_order'),
      reference: buyerCheckoutString(json, 'order_reference', 'seller_order'),
      status: buyerCheckoutString(json, 'status', 'seller_order'),
      statusHistory: history,
      shipments: shipments,
    );
  }
}

class BuyerTrackedStatusChange {
  const BuyerTrackedStatusChange({
    required this.fromStatus,
    required this.toStatus,
    required this.occurredAt,
  });

  final String? fromStatus;
  final String toStatus;
  final DateTime occurredAt;

  factory BuyerTrackedStatusChange.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'status_history[]');
    return BuyerTrackedStatusChange(
      fromStatus: buyerCheckoutOptionalString(
        json,
        'from_status',
        'status_history',
      ),
      toStatus: buyerCheckoutString(json, 'to_status', 'status_history'),
      occurredAt: buyerCheckoutDate(json, 'occurred_at', 'status_history'),
    );
  }
}

class BuyerTrackedShipment {
  BuyerTrackedShipment({
    required this.id,
    required this.reference,
    required this.purpose,
    required this.status,
    required this.waybillReference,
    required this.estimatedDeliveryAt,
    required this.deliveredAt,
    required List<BuyerTrackedShipmentEvent> events,
    required List<BuyerTrackedPickupAssignment> pickupAssignments,
    required List<BuyerTrackedDeliveryAttempt> deliveryAttempts,
  }) : events = List.unmodifiable(events),
       pickupAssignments = List.unmodifiable(pickupAssignments),
       deliveryAttempts = List.unmodifiable(deliveryAttempts);

  final int id;
  final String reference;
  final String purpose;
  final String status;
  final String? waybillReference;
  final DateTime? estimatedDeliveryAt;
  final DateTime? deliveredAt;
  final List<BuyerTrackedShipmentEvent> events;
  final List<BuyerTrackedPickupAssignment> pickupAssignments;
  final List<BuyerTrackedDeliveryAttempt> deliveryAttempts;

  factory BuyerTrackedShipment.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'shipment');
    final events = buyerCheckoutList(
      json['events'],
      'shipment.events',
    ).map(BuyerTrackedShipmentEvent.fromJson).toList(growable: false);
    final assignments = buyerCheckoutList(
      json['pickup_assignments'],
      'shipment.pickup_assignments',
    ).map(BuyerTrackedPickupAssignment.fromJson).toList(growable: false);
    final attempts = buyerCheckoutList(
      json['delivery_attempts'],
      'shipment.delivery_attempts',
    ).map(BuyerTrackedDeliveryAttempt.fromJson).toList(growable: false);
    if (events.length > 100 ||
        assignments.length > 50 ||
        attempts.length > 50) {
      throw const BuyerCheckoutFormatException('shipment.history');
    }
    return BuyerTrackedShipment(
      id: buyerCheckoutInt(json, 'id', 'shipment'),
      reference: buyerCheckoutString(json, 'shipment_reference', 'shipment'),
      purpose: buyerCheckoutString(json, 'purpose', 'shipment'),
      status: buyerCheckoutString(json, 'status', 'shipment'),
      waybillReference: buyerCheckoutOptionalString(
        json,
        'waybill_reference',
        'shipment',
      ),
      estimatedDeliveryAt: buyerCheckoutOptionalDate(
        json,
        'estimated_delivery_at',
        'shipment',
      ),
      deliveredAt: buyerCheckoutOptionalDate(json, 'delivered_at', 'shipment'),
      events: events,
      pickupAssignments: assignments,
      deliveryAttempts: attempts,
    );
  }
}

class BuyerTrackedShipmentEvent {
  const BuyerTrackedShipmentEvent({
    required this.eventId,
    required this.scope,
    required this.eventType,
    required this.fromStatus,
    required this.toStatus,
    required this.parcelReference,
    required this.occurredAt,
  });

  final int eventId;
  final String scope;
  final String eventType;
  final String? fromStatus;
  final String? toStatus;
  final String? parcelReference;
  final DateTime occurredAt;

  factory BuyerTrackedShipmentEvent.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'shipment.event');
    return BuyerTrackedShipmentEvent(
      eventId: buyerCheckoutInt(json, 'event_id', 'shipment.event'),
      scope: buyerCheckoutString(json, 'scope', 'shipment.event'),
      eventType: buyerCheckoutString(json, 'event_type', 'shipment.event'),
      fromStatus: buyerCheckoutOptionalString(
        json,
        'from_status',
        'shipment.event',
      ),
      toStatus: buyerCheckoutOptionalString(
        json,
        'to_status',
        'shipment.event',
      ),
      parcelReference: buyerCheckoutOptionalString(
        json,
        'parcel_reference',
        'shipment.event',
      ),
      occurredAt: buyerCheckoutDate(json, 'occurred_at', 'shipment.event'),
    );
  }
}

/// Deliberately contains no assignment ID, rider name, phone, or private data.
class BuyerTrackedPickupAssignment {
  const BuyerTrackedPickupAssignment({
    required this.status,
    required this.assignedAt,
    required this.acceptedAt,
    required this.arrivedAt,
    required this.pickedUpAt,
    required this.completedAt,
  });

  final String status;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;

  factory BuyerTrackedPickupAssignment.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'pickup_assignment');
    return BuyerTrackedPickupAssignment(
      status: buyerCheckoutString(json, 'status', 'pickup_assignment'),
      assignedAt: buyerCheckoutOptionalDate(
        json,
        'assigned_at',
        'pickup_assignment',
      ),
      acceptedAt: buyerCheckoutOptionalDate(
        json,
        'accepted_at',
        'pickup_assignment',
      ),
      arrivedAt: buyerCheckoutOptionalDate(
        json,
        'arrived_at',
        'pickup_assignment',
      ),
      pickedUpAt: buyerCheckoutOptionalDate(
        json,
        'picked_up_at',
        'pickup_assignment',
      ),
      completedAt: buyerCheckoutOptionalDate(
        json,
        'completed_at',
        'pickup_assignment',
      ),
    );
  }
}

class BuyerTrackedDeliveryAttempt {
  const BuyerTrackedDeliveryAttempt({
    required this.parcelReference,
    required this.attemptNumber,
    required this.outcome,
    required this.attemptedAt,
    required this.nextAttemptAt,
  });

  final String parcelReference;
  final int attemptNumber;
  final String outcome;
  final DateTime attemptedAt;
  final DateTime? nextAttemptAt;

  factory BuyerTrackedDeliveryAttempt.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'delivery_attempt');
    final result = BuyerTrackedDeliveryAttempt(
      parcelReference: buyerCheckoutString(
        json,
        'parcel_reference',
        'delivery_attempt',
      ),
      attemptNumber: buyerCheckoutInt(json, 'attempt_no', 'delivery_attempt'),
      outcome: buyerCheckoutString(json, 'outcome', 'delivery_attempt'),
      attemptedAt: buyerCheckoutDate(json, 'attempted_at', 'delivery_attempt'),
      nextAttemptAt: buyerCheckoutOptionalDate(
        json,
        'next_attempt_at',
        'delivery_attempt',
      ),
    );
    if (result.attemptNumber < 1) {
      throw const BuyerCheckoutFormatException('delivery_attempt.attempt_no');
    }
    return result;
  }
}
