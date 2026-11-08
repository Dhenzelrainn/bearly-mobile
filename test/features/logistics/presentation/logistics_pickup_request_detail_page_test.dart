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

  testWidgets('verifies a requested pickup and renders its refreshed state', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(_pickup(status: 'requested'));
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-verify')),
    );

    await tester.tap(find.byKey(const ValueKey('logistics-pickup-verify')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-verify-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.actions, ['verify']);
    await _scrollTo(tester, find.text('Verified'));
    expect(find.text('Verified'), findsWidgets);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-action-success')),
    );
    expect(find.text('Pickup request verified.'), findsOneWidget);
  });

  testWidgets('rejects only with a reason and shows the cancelled state', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(_pickup(status: 'requested'));
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-reject')),
    );

    await tester.tap(find.byKey(const ValueKey('logistics-pickup-reject')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-reject-confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter a rejection reason.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('logistics-pickup-rejection-reason')),
      'Parcel labels do not match.',
    );
    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-reject-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.actions, ['reject:Parcel labels do not match.']);
    await _scrollTo(tester, find.text('Rejection reason'));
    expect(find.text('Rejection reason'), findsOneWidget);
    expect(find.text('Parcel labels do not match.'), findsOneWidget);
  });

  testWidgets('assigns an eligible Local Rider and displays the server state', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(
      _pickup(status: 'verified', assignedRider: null),
    );
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-assign')),
    );

    await tester.tap(find.byKey(const ValueKey('logistics-pickup-assign')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-assignment-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.actions, ['assign:11']);
    await _scrollTo(tester, find.text('Recommended Rider'));
    expect(find.text('Recommended Rider'), findsOneWidget);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-action-success')),
    );
    expect(find.text('Rider assigned to pickup.'), findsOneWidget);
  });

  testWidgets('replaces only an unpicked scheduled assignment with a reason', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(
      _pickup(
        status: 'scheduled',
        assignedRider: const LogisticsPickupAssignedRider(
          profileId: 10,
          name: 'Current Rider',
          assignmentStatus: 'accepted',
          assignedAt: null,
        ),
      ),
    );
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-replace-rider')),
    );

    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-replace-rider')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('logistics-pickup-replacement-reason')),
      'Coverage changed for today.',
    );
    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-replacement-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.actions, ['replace:11:Coverage changed for today.']);
    await _scrollTo(tester, find.text('Recommended Rider'));
    expect(find.text('Recommended Rider'), findsOneWidget);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-action-success')),
    );
    expect(find.text('Rider assignment updated.'), findsOneWidget);
  });

  testWidgets('shows server conflict details and keeps the request unchanged', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(
      _pickup(status: 'verified', assignedRider: null),
      failAction: true,
    );
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-assign')),
    );
    await tester.tap(find.byKey(const ValueKey('logistics-pickup-assign')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-assignment-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.actions, ['assign:11']);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('logistics-pickup-action-error')),
    );
    expect(
      find.text('Rider availability changed. Refresh and try again.'),
      findsOneWidget,
    );
    expect(repository.current.status, 'verified');
    expect(repository.current.assignedRider, isNull);
  });
}

Widget _page(_FakeLogisticsRepository repository) => MaterialApp(
  home: LogisticsPickupRequestDetailPage(
    repository: repository,
    pickupRequestId: 42,
  ),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('logistics-pickup-request-detail')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

class _FakeLogisticsRepository extends LogisticsRepository {
  _FakeLogisticsRepository(
    this.current, {
    this.failFirst = false,
    this.failAction = false,
  }) : super(
         authService: AuthService(
           apiClient: ApiClient(),
           tokenStore: _TokenStore(),
         ),
       );

  LogisticsPickupRequest current;
  final bool failFirst;
  final bool failAction;
  int loads = 0;
  final List<String> actions = [];

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
    return current;
  }

  @override
  Future<LogisticsPickupRequest> verifyPickupRequest(
    int pickupRequestId,
  ) async {
    actions.add('verify');
    return current = _withStatus(current, 'verified');
  }

  @override
  Future<LogisticsPickupRequest> rejectPickupRequest(
    int pickupRequestId, {
    required String reason,
  }) async {
    actions.add('reject:$reason');
    return current = _withStatus(current, 'cancelled', rejectionReason: reason);
  }

  @override
  Future<LogisticsPickupRequest> assignPickupRequest(
    int pickupRequestId, {
    required int riderProfileId,
    String? notes,
  }) async {
    actions.add('assign:$riderProfileId');
    if (failAction) {
      throw ApiHttpException(
        statusCode: 409,
        responseData: {
          'message': 'Rider availability changed. Refresh and try again.',
        },
        responseWasJson: true,
      );
    }
    return current = _withStatus(
      current,
      'scheduled',
      assignedRider: const LogisticsPickupAssignedRider(
        profileId: 11,
        name: 'Recommended Rider',
        assignmentStatus: 'assigned',
        assignedAt: null,
      ),
      eligibleRiderCandidates: const [],
    );
  }

  @override
  Future<LogisticsPickupRequest> replacePickupRequestRider(
    int pickupRequestId, {
    required int riderProfileId,
    required String reason,
  }) async {
    actions.add('replace:$riderProfileId:$reason');
    return current = _withStatus(
      current,
      'scheduled',
      assignedRider: const LogisticsPickupAssignedRider(
        profileId: 11,
        name: 'Recommended Rider',
        assignmentStatus: 'assigned',
        assignedAt: null,
      ),
      eligibleRiderCandidates: const [],
    );
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

LogisticsPickupRequest _pickup({
  String status = 'scheduled',
  LogisticsPickupAssignedRider? assignedRider,
}) => LogisticsPickupRequest(
  id: 42,
  reference: 'PU-42',
  status: status,
  statusLabel: switch (status) {
    'requested' => 'Pending',
    'verified' => 'Verified',
    'cancelled' => 'Rejected',
    _ => 'Scheduled',
  },
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
  assignedRider:
      assignedRider ??
      (status == 'scheduled'
          ? const LogisticsPickupAssignedRider(
              profileId: 10,
              name: 'Local Rider',
              assignmentStatus: 'assigned',
              assignedAt: null,
            )
          : null),
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

LogisticsPickupRequest _withStatus(
  LogisticsPickupRequest pickup,
  String status, {
  LogisticsPickupAssignedRider? assignedRider,
  String? rejectionReason,
  List<LogisticsPickupCandidate>? eligibleRiderCandidates,
}) => LogisticsPickupRequest(
  id: pickup.id,
  reference: pickup.reference,
  status: status,
  statusLabel: switch (status) {
    'requested' => 'Pending',
    'verified' => 'Verified',
    'cancelled' => 'Rejected',
    _ => 'Scheduled',
  },
  pickupType: pickup.pickupType,
  storeName: pickup.storeName,
  sellerOrderReferences: pickup.sellerOrderReferences,
  parcelCount: pickup.parcelCount,
  totalWeightKg: pickup.totalWeightKg,
  pickupLocation: pickup.pickupLocation,
  requestedDate: pickup.requestedDate,
  windowStart: pickup.windowStart,
  windowEnd: pickup.windowEnd,
  createdAt: pickup.createdAt,
  verifiedAt: pickup.verifiedAt,
  cancelledAt: pickup.cancelledAt,
  completedAt: pickup.completedAt,
  assignedRider: assignedRider,
  sellerInstructions: pickup.sellerInstructions,
  rejectionReason: rejectionReason ?? pickup.rejectionReason,
  parcels: pickup.parcels,
  eligibleRiderCandidates:
      eligibleRiderCandidates ?? pickup.eligibleRiderCandidates,
  history: pickup.history,
);
