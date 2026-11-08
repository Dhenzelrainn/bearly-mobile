import 'dart:async';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/models/logistics_pickup_request.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_pickup_request_detail_page.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_pickup_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a loading state while the first page is pending', (
    tester,
  ) async {
    final pending = Completer<LogisticsPickupRequestPage>();
    final repository = _FakeLogisticsRepository(
      pages: [
        _page([_pickup()]),
      ],
      detail: _pickup(),
      pendingListPage: pending,
    );
    await tester.pumpWidget(
      MaterialApp(home: LogisticsPickupRequestsPage(repository: repository)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(_page([_pickup()]));
    await tester.pumpAndSettle();
    expect(find.text('PU-100'), findsOneWidget);
  });

  testWidgets('shows empty state when the provider has no pickup requests', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(
      pages: [_page(const [])],
      detail: _pickup(),
    );
    await tester.pumpWidget(
      MaterialApp(home: LogisticsPickupRequestsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pickup requests match this status.'), findsOneWidget);
  });

  testWidgets('refresh action reloads the provider-owned list', (tester) async {
    final repository = _FakeLogisticsRepository(
      pages: [
        _page([_pickup()]),
        _page([_pickup(reference: 'PU-101')]),
      ],
      detail: _pickup(),
    );
    await tester.pumpWidget(
      MaterialApp(home: LogisticsPickupRequestsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('PU-100'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-requests-refresh')),
    );
    await tester.pumpAndSettle();
    expect(find.text('PU-101'), findsOneWidget);
    expect(repository.listRequests, 2);
  });

  testWidgets('shows an error state and retries the provider request', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(
      pages: [
        _page([_pickup()]),
      ],
      detail: _pickup(),
      failFirstListRequest: true,
    );
    await tester.pumpWidget(
      MaterialApp(home: LogisticsPickupRequestsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not load pickup requests'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('PU-100'), findsOneWidget);
    expect(repository.listRequests, 2);
  });

  testWidgets('filters requests and opens read-only details', (tester) async {
    final repository = _FakeLogisticsRepository(
      pages: [
        _page([_pickup()]),
        _page([_pickup(status: 'completed', statusLabel: 'Collected')]),
        _page([_pickup(status: 'completed', statusLabel: 'Collected')]),
      ],
      detail: _pickup(status: 'completed', statusLabel: 'Collected'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsPickupRequestsPage(repository: repository),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouteNames.logisticsPickupRequestDetails) {
            return MaterialPageRoute<void>(
              builder: (_) => LogisticsPickupRequestDetailPage(
                repository: repository,
                pickupRequestId: settings.arguments! as int,
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PU-100'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('logistics-pickup-status-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collected').last);
    await tester.pumpAndSettle();

    expect(repository.statusFilters.last, 'completed');
    expect(find.text('Collected'), findsNWidgets(2));
    await tester.tap(find.text('PU-100'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Store'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pickup history'),
      280,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('logistics-pickup-request-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Pickup history'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.listRequests, 3);
  });
}

class _FakeLogisticsRepository extends LogisticsRepository {
  _FakeLogisticsRepository({
    required this.pages,
    required this.detail,
    this.failFirstListRequest = false,
    this.pendingListPage,
  }) : super(
         authService: AuthService(
           apiClient: ApiClient(),
           tokenStore: _TokenStore(),
         ),
       );

  final List<LogisticsPickupRequestPage> pages;
  final LogisticsPickupRequest detail;
  final bool failFirstListRequest;
  final Completer<LogisticsPickupRequestPage>? pendingListPage;
  final List<String?> statusFilters = [];
  int listRequests = 0;

  @override
  Future<LogisticsPickupRequestPage> pickupRequests({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    listRequests++;
    statusFilters.add(status);
    if (failFirstListRequest && listRequests == 1) throw StateError('offline');
    if (pendingListPage != null && listRequests == 1) {
      return pendingListPage!.future;
    }
    final index = listRequests - 1;
    return pages[index.clamp(0, pages.length - 1)];
  }

  @override
  Future<LogisticsPickupRequest> pickupRequest(int pickupRequestId) async =>
      detail;
}

class _TokenStore implements SessionTokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

LogisticsPickupRequestPage _page(List<LogisticsPickupRequest> requests) =>
    LogisticsPickupRequestPage(
      requests: requests,
      currentPage: 1,
      lastPage: 1,
      total: requests.length,
    );

LogisticsPickupRequest _pickup({
  String reference = 'PU-100',
  String status = 'requested',
  String statusLabel = 'Pending',
}) => LogisticsPickupRequest(
  id: 100,
  reference: reference,
  status: status,
  statusLabel: statusLabel,
  pickupType: 'outbound',
  storeName: 'Sample Store',
  sellerOrderReferences: const ['SO-100'],
  parcelCount: 1,
  totalWeightKg: 1.25,
  pickupLocation: 'Sample pickup address',
  requestedDate: DateTime(2026, 11, 8),
  windowStart: DateTime(2026, 11, 8, 9),
  windowEnd: DateTime(2026, 11, 8, 11),
  createdAt: DateTime(2026, 11, 7, 12),
  verifiedAt: DateTime(2026, 11, 7, 13),
  cancelledAt: null,
  completedAt: null,
  assignedRider: const LogisticsPickupAssignedRider(
    profileId: 17,
    name: 'Local Rider',
    assignmentStatus: 'assigned',
    assignedAt: null,
  ),
  sellerInstructions: 'Use loading bay.',
  rejectionReason: null,
  parcels: const [
    LogisticsPickupParcel(
      reference: 'P-100',
      pieceNumber: 1,
      status: 'ready_for_pickup',
      weightKg: 1.25,
      waybill: 'WB-100',
      shipmentReference: 'SHIP-100',
      sellerOrderReferences: ['SO-100'],
    ),
  ],
  eligibleRiderCandidates: const [
    LogisticsPickupCandidate(
      profileId: 18,
      name: 'Recommended Rider',
      vehicle: 'Motorcycle',
      serviceArea: 'North Zone',
      activeJobs: 1,
      recommended: true,
      recommendationReason: 'Recommended',
      distanceLabel: '2 km away',
    ),
  ],
  history: const [
    LogisticsPickupActivity(
      event: 'submitted',
      label: 'Request submitted',
      occurredAt: null,
      detail: null,
    ),
    LogisticsPickupActivity(
      event: 'verified',
      label: 'Request verified',
      occurredAt: null,
      detail: null,
    ),
  ],
);
