import 'package:bearly_mobile/features/rider/data/rider_cash_custody_repository.dart';
import 'package:bearly_mobile/features/rider/models/rider_cash_custody.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_cash_custody_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders COD summary, remittance and refund-cash history', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderCashCustodyPage(repository: _FakeCashCustody(_sample)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cash Custody'), findsOneWidget);
    expect(find.text('COD collection history'), findsOneWidget);
    expect(find.text('COD-101'), findsOneWidget);
    expect(find.text('Reconciled'), findsWidgets);
    expect(find.text('L2F-101'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Refund cash assignments'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Refund cash assignments'), findsOneWidget);
    expect(find.text('RCP-101'), findsOneWidget);
    expect(find.text('Cash With Rider'), findsOneWidget);
  });

  testWidgets('shows empty state and supports pull to refresh', (tester) async {
    var requests = 0;
    final source = _FakeCashCustody(_empty, onLoad: () => requests++);
    await tester.pumpWidget(
      MaterialApp(home: RiderCashCustodyPage(repository: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No cash custody records yet'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(requests, 2);
  });

  testWidgets('shows a retry action after API errors', (tester) async {
    final source = _FakeCashCustody(_empty, shouldFail: true);
    await tester.pumpWidget(
      MaterialApp(home: RiderCashCustodyPage(repository: source)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cash custody could not be loaded'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _FakeCashCustody implements RiderCashCustodyDataSource {
  _FakeCashCustody(this.value, {this.onLoad, this.shouldFail = false});

  final RiderCashCustody value;
  final void Function()? onLoad;
  final bool shouldFail;

  @override
  Future<RiderCashCustody> load() async {
    onLoad?.call();
    if (shouldFail) throw StateError('offline');
    return value;
  }
}

const _empty = RiderCashCustody(
  summary: RiderCashCustodySummary(
    codCollectedMinor: 0,
    codHandoffPendingMinor: 0,
    refundCashWithRiderMinor: 0,
  ),
  codCollections: [],
  refundCash: [],
);

final _sample = RiderCashCustody(
  summary: const RiderCashCustodySummary(
    codCollectedMinor: 12000,
    codHandoffPendingMinor: 0,
    refundCashWithRiderMinor: 3500,
  ),
  codCollections: [
    RiderCodCashRecord(
      collectionNo: 'COD-101',
      amountDueMinor: 12000,
      amountCollectedMinor: 12000,
      discrepancyMinor: 0,
      amountReceivedByLogisticsMinor: 12000,
      amountRemittedToFinanceMinor: 12000,
      amountReconciledMinor: 12000,
      status: 'reconciled',
      collectedAt: DateTime.parse('2026-11-07T10:00:00+08:00'),
      logisticsReference: 'CODH-101',
      logisticsReceivedAt: DateTime.parse('2026-11-07T11:00:00+08:00'),
      financeRemittanceReference: 'L2F-101',
      remittedToFinanceAt: DateTime.parse('2026-11-07T12:00:00+08:00'),
      financeReference: 'FIN-101',
      reconciledAt: DateTime.parse('2026-11-07T13:00:00+08:00'),
      events: [
        RiderCashCustodyEvent(
          type: 'cash_reconciled_by_finance',
          at: DateTime.parse('2026-11-07T13:00:00+08:00'),
          status: 'admin',
          amountMinor: 12000,
          reference: 'FIN-101',
        ),
      ],
    ),
  ],
  refundCash: [
    RiderRefundCashRecord(
      payoutNo: 'RCP-101',
      amountMinor: 3500,
      status: 'cash_with_rider',
      acknowledgmentReference: 'ACK-101',
      receivedByRiderAt: DateTime.parse('2026-11-07T09:30:00+08:00'),
      events: const [],
    ),
  ],
);
