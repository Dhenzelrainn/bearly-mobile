import 'dart:async';

import 'package:bearly_mobile/features/buyer/data/buyer_returns_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_return_models.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_returns_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading then an ineligible order and empty history', (
    tester,
  ) async {
    final pending = Completer<BuyerReturnWorkspace>();
    final repository = _FakeReturnsDataSource()..workspaces.add(pending.future);

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerReturnsPage(repository: repository, sellerOrderId: 24),
      ),
    );
    expect(find.byKey(const ValueKey('buyer-returns-loading')), findsOneWidget);

    pending.complete(_workspace(canRequest: false));
    await tester.pumpAndSettle();
    expect(
      find.text('The three-day return or refund request window has ended.'),
      findsOneWidget,
    );
    expect(
      find.text('There are no return or refund requests for this order.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('buyer-return-submit')), findsNothing);
  });

  testWidgets('loads request history and opens the server case detail', (
    tester,
  ) async {
    final repository = _FakeReturnsDataSource()
      ..workspaces.add(
        Future.value(_workspace(canRequest: false, cases: [_summary()])),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerReturnsPage(repository: repository, sellerOrderId: 24),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RET-51 · Return Refund'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('buyer-return-case-51')));
    await tester.pumpAndSettle();
    expect(find.byType(BuyerReturnCasePage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('buyer-return-case-status')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Buyer requested a return and refund.'),
      findsOneWidget,
    );
  });

  testWidgets('shows retry state for workspace errors', (tester) async {
    final failure = Completer<BuyerReturnWorkspace>();
    final repository = _FakeReturnsDataSource()
      ..workspaces.add(failure.future)
      ..workspaces.add(Future.value(_workspace(canRequest: false)));

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerReturnsPage(repository: repository, sellerOrderId: 24),
      ),
    );
    failure.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bearly could not complete the request. Check your connection and try again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.workspaceCalls, 2);
    expect(find.text('Request history'), findsOneWidget);
  });

  testWidgets('submits selected quantities and refreshes into case tracking', (
    tester,
  ) async {
    final repository = _FakeReturnsDataSource()
      ..workspaces.add(Future.value(_workspace(canRequest: true)));

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerReturnsPage(repository: repository, sellerOrderId: 24),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('buyer-return-quantity-811')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buyer-return-reason')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other issue').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('buyer-returns-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('buyer-return-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('buyer-return-submit')));
    await tester.pumpAndSettle();

    expect(repository.submittedSellerOrderId, 24);
    expect(repository.submittedQuantities, {811: 1});
    expect(find.byType(BuyerReturnCasePage), findsOneWidget);
    expect(
      find.textContaining('Buyer requested a return and refund.'),
      findsOneWidget,
    );
    expect(repository.workspaceCalls, 2);
  });
}

class _FakeReturnsDataSource implements BuyerReturnsDataSource {
  final List<Future<BuyerReturnWorkspace>> workspaces = [];
  int workspaceCalls = 0;
  int? submittedSellerOrderId;
  Map<int, int>? submittedQuantities;

  @override
  Future<BuyerReturnWorkspace> getWorkspace(int sellerOrderId) {
    workspaceCalls++;
    if (workspaces.isNotEmpty) return workspaces.removeAt(0);
    return Future.value(_workspace(canRequest: false));
  }

  @override
  Future<BuyerReturnCase> submitRequest({
    required int sellerOrderId,
    required String requestType,
    required String reasonCode,
    required Map<int, int> itemQuantities,
    required String buyerNote,
    required String? deliveryMethod,
    required List<BuyerReturnAttachment> evidence,
  }) async {
    submittedSellerOrderId = sellerOrderId;
    submittedQuantities = itemQuantities;
    return _case();
  }

  @override
  Future<BuyerReturnCase> getCase(int returnRequestId) async => _case();

  @override
  Future<BuyerReturnCase> addEvidence({
    required int returnRequestId,
    required String note,
    required List<BuyerReturnAttachment> evidence,
  }) async => _case();

  @override
  Future<BuyerReturnCase> switchToPickup(int returnRequestId) async => _case();

  @override
  Future<BuyerReturnFileContent> downloadEvidence(int evidenceId) async =>
      const BuyerReturnFileContent(bytes: [1], mimeType: 'image/png');

  @override
  Future<BuyerReturnFileContent> downloadRefundReceipt(int refundId) async =>
      const BuyerReturnFileContent(bytes: [1], mimeType: 'application/pdf');
}

BuyerReturnWorkspace _workspace({
  required bool canRequest,
  List<BuyerReturnCaseSummary> cases = const [],
}) => BuyerReturnWorkspace(
  sellerOrderId: 24,
  sellerOrderReference: 'SO-24',
  orderReference: 'ORD-24',
  storeName: 'Market Store',
  status: 'completed',
  completedAt: DateTime(2026, 11, 6),
  canRequest: canRequest,
  ineligibilityReason: canRequest
      ? null
      : 'The three-day return or refund request window has ended.',
  deadline: DateTime(2026, 11, 9),
  reasonCodes: const {'other': 'Other issue'},
  deliveryMethods: const [
    BuyerReturnDeliveryMethod(
      value: 'rider_pickup',
      label: 'Rider pickup',
      available: true,
    ),
  ],
  dropoffCenter: null,
  items: const [
    BuyerReturnItem(
      id: 811,
      name: 'Bearly Bag',
      variant: 'Brown',
      sku: 'BAG-1',
      quantity: 2,
      returnableQuantity: 2,
      unitPriceMinor: 50000,
      imageUrl: null,
    ),
  ],
  cases: cases,
);

BuyerReturnCaseSummary _summary() => BuyerReturnCaseSummary(
  id: 51,
  reference: 'RET-51',
  requestType: 'return_refund',
  status: 'awaiting_seller',
  requestedAmountMinor: 50000,
  submittedAt: DateTime(2026, 11, 7),
  resolvedAt: null,
  refunds: const [],
);

BuyerReturnCase _case() => BuyerReturnCase(
  id: 51,
  reference: 'RET-51',
  requestType: 'return_refund',
  status: 'awaiting_seller',
  requestedAmountMinor: 50000,
  submittedAt: DateTime(2026, 11, 7),
  resolvedAt: null,
  refunds: const [],
  orderReference: 'ORD-24',
  sellerOrderId: 24,
  storeName: 'Market Store',
  reasonLabel: 'Damaged',
  buyerNote: null,
  resolution: null,
  responseDueAt: null,
  dropoffDueAt: null,
  deliveryMethod: 'rider_pickup',
  canAddEvidence: false,
  canSwitchToPickup: false,
  evidence: const [],
  events: const [
    BuyerReturnEvent(
      id: 1,
      type: 'request_submitted',
      fromStatus: null,
      toStatus: 'awaiting_seller',
      note: 'Buyer requested a return and refund.',
      actorName: 'Bea Buyer',
      occurredAt: null,
    ),
  ],
  shipment: null,
  items: const [],
);
