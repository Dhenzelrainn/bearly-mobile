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

  testWidgets(
    'eligible Local Rider sees management actions and Courier stays read-only',
    (tester) async {
      final repository = _FakeLogisticsRepository([_local, _courier]);
      await tester.pumpWidget(
        MaterialApp(
          home: LogisticsRiderDetailsPage(
            repository: repository,
            riderUserId: _local.userId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text('Local Rider Management'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('logistics-rider-edit-capacity')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logistics-rider-edit-specialization')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logistics-rider-refresh-zone')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LogisticsRiderDetailsPage(
            key: const ValueKey('courier-rider-details'),
            repository: repository,
            riderUserId: _courier.userId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local Rider Management'), findsNothing);
      expect(
        find.byKey(const ValueKey('logistics-rider-edit-capacity')),
        findsNothing,
      );
    },
  );

  testWidgets('capacity save updates details and refreshes from the API', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository([_local]);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderDetailsPage(
          repository: repository,
          riderUserId: _local.userId,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('logistics-rider-edit-capacity')),
    );
    await tester.tap(
      find.byKey(const ValueKey('logistics-rider-edit-capacity')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('logistics-rider-capacity-input')),
      '14',
    );
    await tester.tap(
      find.byKey(const ValueKey('logistics-rider-capacity-save')),
    );
    await tester.pumpAndSettle();

    expect(repository.capacityUpdates, 1);
    expect(find.text('14'), findsOneWidget);
    expect(repository.riderRequests, 2);
    expect(find.text('Local Rider capacity updated.'), findsOneWidget);
  });

  testWidgets(
    'capacity form blocks invalid values and displays server validation errors',
    (tester) async {
      final repository = _FakeLogisticsRepository([_local]);
      await tester.pumpWidget(
        MaterialApp(
          home: LogisticsRiderDetailsPage(
            repository: repository,
            riderUserId: _local.userId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('logistics-rider-edit-capacity')),
      );
      await tester.tap(
        find.byKey(const ValueKey('logistics-rider-edit-capacity')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('logistics-rider-capacity-input')),
        '0',
      );
      await tester.tap(
        find.byKey(const ValueKey('logistics-rider-capacity-save')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 1000.'), findsOneWidget);
      expect(repository.capacityUpdates, 0);

      await tester.enterText(
        find.byKey(const ValueKey('logistics-rider-capacity-input')),
        '14',
      );
      repository.managementError = ApiHttpException(
        statusCode: 422,
        responseWasJson: true,
        responseData: {
          'errors': {
            'parcel_capacity': ['Capacity cannot be lower than active load.'],
          },
        },
      );
      await tester.tap(
        find.byKey(const ValueKey('logistics-rider-capacity-save')),
      );
      await tester.pumpAndSettle();
      expect(repository.capacityUpdates, 1);
      expect(
        find.text('Capacity cannot be lower than active load.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'specialization requires a reason and zone refresh confirms before saving',
    (tester) async {
      final repository = _FakeLogisticsRepository([_local]);
      await tester.pumpWidget(
        MaterialApp(
          home: LogisticsRiderDetailsPage(
            repository: repository,
            riderUserId: _local.userId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('logistics-rider-edit-specialization')),
      );
      await tester.tap(
        find.byKey(const ValueKey('logistics-rider-edit-specialization')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('logistics-rider-specialization-save')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a reason of at least 5 characters.'),
        findsOneWidget,
      );
      expect(repository.specializationUpdates, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('logistics-rider-refresh-zone')),
      );
      await tester.tap(
        find.byKey(const ValueKey('logistics-rider-refresh-zone')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A zone cannot be selected manually here.'),
        findsOneWidget,
      );
      expect(repository.assignmentRefreshes, 0);
      await tester.tap(
        find.byKey(const ValueKey('logistics-rider-zone-refresh-confirm')),
      );
      await tester.pumpAndSettle();
      expect(repository.assignmentRefreshes, 1);
    },
  );
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
  int riderRequests = 0;
  int capacityUpdates = 0;
  int specializationUpdates = 0;
  int assignmentRefreshes = 0;
  Object? managementError;

  @override
  Future<List<LogisticsRider>> riders() async {
    rosterRequests++;
    onRoster?.call();
    return rosterLoader == null ? values : await rosterLoader!();
  }

  @override
  Future<LogisticsRider> rider(int userId) async {
    riderRequests++;
    onRider?.call();
    return values.firstWhere((rider) => rider.userId == userId);
  }

  @override
  Future<LogisticsRider> updateRiderCapacity({
    required int userId,
    required int parcelCapacity,
  }) async {
    capacityUpdates++;
    if (managementError != null) throw managementError!;
    return _replaceRider(userId, capacity: parcelCapacity);
  }

  @override
  Future<LogisticsRider> updateRiderSpecialization({
    required int userId,
    required String specialization,
    required String reason,
  }) async {
    specializationUpdates++;
    if (managementError != null) throw managementError!;
    return _replaceRider(userId, specialization: specialization);
  }

  @override
  Future<LogisticsRider> refreshRiderAssignment({required int userId}) async {
    assignmentRefreshes++;
    if (managementError != null) throw managementError!;
    return _replaceRider(userId, currentZone: 'Updated Zone');
  }

  LogisticsRider _replaceRider(
    int userId, {
    int? capacity,
    String? specialization,
    String? currentZone,
  }) {
    final index = values.indexWhere((rider) => rider.userId == userId);
    final old = values[index];
    final updated = LogisticsRider(
      userId: old.userId,
      profileId: old.profileId,
      name: old.name,
      workType: old.workType,
      workTypeLabel: old.workTypeLabel,
      accountStatus: old.accountStatus,
      verificationStatus: old.verificationStatus,
      applicationStatus: old.applicationStatus,
      availabilityStatus: old.availabilityStatus,
      operationalStatus: old.operationalStatus,
      vehicleType: old.vehicleType,
      vehicleModel: old.vehicleModel,
      plateNumber: old.plateNumber,
      currentZone: currentZone ?? old.currentZone,
      homeSortingCenter: old.homeSortingCenter,
      specialization: specialization ?? old.specialization,
      specializationLabel: specialization == null
          ? old.specializationLabel
          : switch (specialization) {
              'pickup_only' => 'Pickup only',
              'delivery_only' => 'Delivery only',
              _ => 'Pickup and delivery',
            },
      capacity: capacity ?? old.capacity,
      capacityLabel: old.capacityLabel,
      activeJobs: old.activeJobs,
      completedToday: old.completedToday,
    );
    values[index] = updated;
    return updated;
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
