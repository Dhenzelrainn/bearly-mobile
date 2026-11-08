import 'dart:async';

import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/models/logistics_rider.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_riders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a loading state while the roster request is pending', (
    tester,
  ) async {
    final response = Completer<List<LogisticsRider>>();
    final repository = _FakeLogisticsRepository(
      [],
      rosterLoader: () => response.future,
    );
    await tester.pumpWidget(
      MaterialApp(home: LogisticsRidersPage(repository: repository)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete([_local]);
    await tester.pumpAndSettle();
    expect(find.text('Alex Rider'), findsOneWidget);
  });

  testWidgets('renders roster, filters Rider work types, and opens details', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository([_local, _courier]);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRidersPage(repository: repository),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LogisticsRiderDetailsPage(
            repository: repository,
            riderUserId: settings.arguments! as int,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex Rider'), findsOneWidget);
    expect(find.text('Morgan Courier'), findsOneWidget);
    expect(find.textContaining('Local Riders (1)'), findsOneWidget);
    expect(find.textContaining('Couriers (1)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('logistics-rider-filter-local')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alex Rider'), findsOneWidget);
    expect(find.text('Morgan Courier'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('logistics-rider-filter-courier')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alex Rider'), findsNothing);
    expect(find.text('Morgan Courier'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('logistics-rider-42')));
    await tester.pumpAndSettle();
    expect(find.text('Rider Details'), findsOneWidget);
    expect(find.text('Morgan Courier'), findsOneWidget);
    expect(find.text('Line-haul parcels'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.rosterRequests, 2);
  });

  testWidgets('shows an empty roster and retries errors', (tester) async {
    final emptyRepository = _FakeLogisticsRepository([]);
    await tester.pumpWidget(
      MaterialApp(home: LogisticsRidersPage(repository: emptyRepository)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No Local Riders or Couriers are linked to this provider.'),
      findsOneWidget,
    );

    var refreshRequests = 0;
    final refreshRepository = _FakeLogisticsRepository(
      [],
      rosterLoader: () async {
        refreshRequests++;
        return refreshRequests == 1 ? [] : [_local];
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRidersPage(
          key: const ValueKey('empty-refresh-roster'),
          repository: refreshRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(refreshRequests, 2);
    expect(find.text('Alex Rider'), findsOneWidget);

    var attempts = 0;
    final retryRepository = _FakeLogisticsRepository(
      [_local],
      onRoster: () {
        attempts++;
        if (attempts == 1) throw StateError('offline');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRidersPage(
          key: const ValueKey('retry-roster'),
          repository: retryRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load Riders'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Rider'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('detail page shows a read-only unavailable state and retry', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _FakeLogisticsRepository(
      [_local],
      onRider: () {
        attempts++;
        if (attempts == 1) throw StateError('not available');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderDetailsPage(
          repository: repository,
          riderUserId: 41,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load this provider-owned'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Rider'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
  });
}

class _FakeLogisticsRepository extends LogisticsRepository {
  _FakeLogisticsRepository(
    this.values, {
    this.onRoster,
    this.onRider,
    this.rosterLoader,
  }) : super(authService: _unusedAuthService());

  final List<LogisticsRider> values;
  final void Function()? onRoster;
  final void Function()? onRider;
  final Future<List<LogisticsRider>> Function()? rosterLoader;
  int rosterRequests = 0;

  @override
  Future<List<LogisticsRider>> riders() async {
    rosterRequests++;
    onRoster?.call();
    return rosterLoader == null ? values : await rosterLoader!();
  }

  @override
  Future<LogisticsRider> rider(int userId) async {
    onRider?.call();
    return values.firstWhere((rider) => rider.userId == userId);
  }
}

AuthService _unusedAuthService() =>
    AuthService(apiClient: ApiClient(), tokenStore: _MemoryTokenStore());

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}

const _local = LogisticsRider(
  userId: 41,
  profileId: 141,
  name: 'Alex Rider',
  workType: 'local',
  workTypeLabel: 'Local Rider',
  accountStatus: 'active',
  verificationStatus: 'approved',
  applicationStatus: 'approved',
  availabilityStatus: 'available',
  operationalStatus: 'assigned',
  vehicleType: 'Motorcycle',
  vehicleModel: 'Cargo 150',
  plateNumber: 'ABC-1234',
  currentZone: 'North Zone',
  homeSortingCenter: 'North Center',
  specialization: 'both',
  specializationLabel: 'Pickup and delivery',
  capacity: 8,
  capacityLabel: 'Local parcels',
  activeJobs: 2,
  completedToday: 1,
);

const _courier = LogisticsRider(
  userId: 42,
  profileId: 142,
  name: 'Morgan Courier',
  workType: 'courier',
  workTypeLabel: 'Courier',
  accountStatus: 'active',
  verificationStatus: 'approved',
  applicationStatus: 'approved',
  availabilityStatus: 'offline',
  operationalStatus: 'offline',
  vehicleType: 'Van',
  vehicleModel: 'Cargo Van',
  plateNumber: 'XYZ-4321',
  currentZone: null,
  homeSortingCenter: 'North Center',
  specialization: null,
  specializationLabel: null,
  capacity: 24,
  capacityLabel: 'Line-haul parcels',
  activeJobs: 0,
  completedToday: 0,
);
