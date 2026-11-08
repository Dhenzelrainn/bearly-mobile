import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('loads availability and opens QR attendance scanner', (
    tester,
  ) async {
    var availability = 'offline';
    var shiftStarted = false;
    var dashboardRequests = 0;

    final authService = _authService((request) async {
      if (request.url.path.endsWith('/dashboard')) {
        dashboardRequests++;
        return http.Response(
          jsonEncode(_dashboard(availability, shiftStarted)),
          200,
        );
      }
      if (request.url.path.endsWith('/availability')) {
        availability =
            (jsonDecode(request.body) as Map)['availability_status'] as String;
        return http.Response(
          jsonEncode({'data': _status(availability, shiftStarted)}),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final repository = RiderRepository(authService: authService);

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRouteNames.riderAttendanceScan: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                shiftStarted = true;
                Navigator.pop(context, true);
              },
              child: const Text('Test scanned QR'),
            ),
          ),
        },
        home: RiderHomePage(repository: repository),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Go Online'), findsOneWidget);
    expect(find.text('Scan attendance QR'), findsOneWidget);
    expect(find.text('Start Shift'), findsNothing);
    expect(find.text('End Shift'), findsNothing);

    await tester.tap(find.text('Go Online'));
    await tester.pumpAndSettle();
    expect(availability, 'available');
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Go Offline'), findsOneWidget);

    await tester.tap(find.text('Scan attendance QR'));
    await tester.pumpAndSettle();
    expect(find.text('Test scanned QR'), findsOneWidget);
    await tester.tap(find.text('Test scanned QR'));
    await tester.pumpAndSettle();
    expect(shiftStarted, isTrue);
    expect(find.textContaining('Shift started'), findsOneWidget);

    // Opening the dashboard again reloads the server-confirmed state.
    await tester.pumpWidget(
      MaterialApp(
        home: RiderHomePage(
          key: const ValueKey('reopened-dashboard'),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dashboardRequests, 3);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Scan attendance QR'), findsOneWidget);
    expect(find.text('Start Shift'), findsNothing);
    expect(find.text('End Shift'), findsNothing);
  });

  testWidgets('shows the server rejection and keeps the prior state', (
    tester,
  ) async {
    final authService = _authService((request) async {
      if (request.url.path.endsWith('/dashboard')) {
        return http.Response(jsonEncode(_dashboard('available', false)), 200);
      }
      if (request.url.path.endsWith('/availability')) {
        return http.Response(
          jsonEncode({
            'message': 'Complete your current assignment before going offline.',
          }),
          409,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RiderHomePage(
          repository: RiderRepository(authService: authService),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go Offline'));
    await tester.pumpAndSettle();

    expect(
      find.text('Complete your current assignment before going offline.'),
      findsOneWidget,
    );
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('shows Courier shifts and active line-haul work', (tester) async {
    final authService = _authService((request) async {
      if (request.url.path.endsWith('/dashboard')) {
        return http.Response(
          jsonEncode(
            _dashboard(
              'available',
              true,
              workType: 'courier',
              activeCourierRuns: 2,
            ),
          ),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RiderHomePage(
          repository: RiderRepository(authService: authService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Work type: Courier'), findsOneWidget);
    expect(find.text('Assigned: 2 active line-haul runs'), findsOneWidget);
    expect(find.textContaining('Courier daily pay'), findsOneWidget);
    expect(find.text('Scan attendance QR'), findsOneWidget);
    expect(find.text('Start Shift'), findsNothing);
    expect(find.text('End Shift'), findsNothing);
  });

}

Map<String, Object?> _dashboard(
  String availability,
  bool shiftStarted, {
  String workType = 'local',
  int activeCourierRuns = 0,
}) => {
  'rider': {
    'name': 'Rider One',
    'work_type': workType,
    'capabilities': {
      'local_pickup': workType == 'local',
      'local_delivery': workType == 'local',
    },
    'vehicle_type': 'Motorcycle',
    'availability_status': availability,
    'logistics_provider': 'North Logistics',
  },
  'metrics': {
    'assigned_pickups': 0,
    'pickup_in_progress': 0,
    'assigned_deliveries': 0,
    'out_for_delivery': 0,
  },
  'operational_status': _status(
    availability,
    shiftStarted,
    workType: workType,
    activeCourierRuns: activeCourierRuns,
  ),
};

Map<String, Object?> _status(
  String availability,
  bool shiftStarted, {
  String workType = 'local',
  int activeCourierRuns = 0,
}) => {
  'availability_status': availability,
  'operational_state': activeCourierRuns > 0 ? 'assigned' : availability,
  'work_type': workType,
  'active_shift': shiftStarted
      ? {'id': 32, 'checked_in_at': '2026-11-08T08:30:00+08:00'}
      : null,
  'active_work': {
    'pickups': 0,
    'pickups_in_progress': 0,
    'deliveries': 0,
    'deliveries_in_progress': 0,
    'courier_runs': activeCourierRuns,
    'courier_runs_in_progress': 0,
  },
  'transitions': {
    'can_go_online': availability == 'offline',
    'can_go_offline': availability == 'available',
    'can_start_shift': !shiftStarted,
    'can_end_shift': shiftStarted,
  },
  'availability_note': 'Availability controls new assignments.',
  'shift_note': workType == 'courier'
      ? 'Shift attendance is separate from availability. Courier daily pay follows the existing accepted line-haul run rules.'
      : 'Attendance is separate from availability.',
  'assignment_rules_note': 'Server assignment rules apply.',
};

AuthService _authService(
  Future<http.Response> Function(http.Request) handler,
) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'test-token',
      )
      ..currentSession = const AuthSession(
        id: 12,
        name: 'Rider One',
        email: 'rider@example.test',
        role: AccountRole.rider,
      );

class _MemoryTokenStore implements SessionTokenStore {
  _MemoryTokenStore();

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
