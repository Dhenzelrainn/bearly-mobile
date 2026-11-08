import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/models/logistics_pickup_request.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_pickup_request_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders parcel, waybill, assigned Rider and pickup history', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(_pickup());
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsPickupRequestDetailPage(
          repository: repository,
          pickupRequestId: 42,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PU-42'), findsOneWidget);
    expect(find.text('SO-42'), findsWidgets);
    expect(find.textContaining('Waybill WB-42'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Local Rider'),
      280,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('logistics-pickup-request-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Local Rider'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recommended Rider'),
      280,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('logistics-pickup-request-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Eligible Local Rider candidates'), findsOneWidget);
    expect(find.text('Recommended Rider'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Request submitted'),
      280,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('logistics-pickup-request-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Request submitted'), findsOneWidget);
    expect(find.text('Private phone'), findsNothing);
  });

  testWidgets('shows a scoped error and retries a detail request', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(_pickup(), failFirst: true);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsPickupRequestDetailPage(
          repository: repository,
          pickupRequestId: 42,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('not available to your Logistics account'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('PU-42'), findsOneWidget);
    expect(repository.loads, 2);
  });
}

class _FakeLogisticsRepository extends LogisticsRepository {
  _FakeLogisticsRepository(this.pickup, {this.failFirst = false})
    : super(
        authService: AuthService(
          apiClient: ApiClient(),
          tokenStore: _TokenStore(),
        ),
      );

  final LogisticsPickupRequest pickup;
  final bool failFirst;
  int loads = 0;

  @override
  Future<LogisticsPickupRequest> pickupRequest(int pickupRequestId) async {
    loads++;
    if (failFirst && loads == 1) {
      throw ApiHttpException(
        statusCode: 404,
        responseData: {'message': 'not found'},
        responseWasJson: true,
      );
    }
    return pickup;
  }
}

class _TokenStore implements SessionTokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

LogisticsPickupRequest _pickup() => const LogisticsPickupRequest(
  id: 42,
  reference: 'PU-42',
  status: 'verified',
  statusLabel: 'Verified',
  pickupType: 'outbound',
  storeName: 'North Store',
  sellerOrderReferences: ['SO-42'],
  parcelCount: 1,
  totalWeightKg: 1.25,
  pickupLocation: '12 North Street, Sample City',
  requestedDate: null,
  windowStart: null,
  windowEnd: null,
  createdAt: null,
  verifiedAt: null,
  cancelledAt: null,
  completedAt: null,
  assignedRider: LogisticsPickupAssignedRider(
    profileId: 10,
    name: 'Local Rider',
    assignmentStatus: 'assigned',
    assignedAt: null,
  ),
  sellerInstructions: null,
  rejectionReason: null,
  parcels: [
    LogisticsPickupParcel(
      reference: 'PARCEL-42',
      pieceNumber: 1,
      status: 'ready_for_pickup',
      weightKg: 1.25,
      waybill: 'WB-42',
      shipmentReference: 'SHIP-42',
      sellerOrderReferences: ['SO-42'],
    ),
  ],
  eligibleRiderCandidates: [
    LogisticsPickupCandidate(
      profileId: 11,
      name: 'Recommended Rider',
      vehicle: 'Motorcycle',
      serviceArea: 'North Zone',
      activeJobs: 0,
      recommended: true,
      recommendationReason: 'Same service area',
      distanceLabel: null,
    ),
  ],
  history: [
    LogisticsPickupActivity(
      event: 'submitted',
      label: 'Request submitted',
      occurredAt: null,
      detail: null,
    ),
  ],
);
