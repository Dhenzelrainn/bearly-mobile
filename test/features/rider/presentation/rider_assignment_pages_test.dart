import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/models/rider_assignment.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_assignment_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('assigned delivery list shows API data without accept controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAssignmentListPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({
                'data': [
                  {
                    'kind': 'delivery',
                    'id': 'SH-20',
                    'title': 'Buyer Rae',
                    'status': 'Assigned',
                    'address': 'Quezon City',
                    'contact_phone': '',
                    'waybill': 'WB-20',
                    'purpose': 'outbound',
                    'purpose_label': 'Buyer delivery',
                    'parcel_count': 1,
                    'zone': 'NCR',
                    'zone_name': 'North',
                    'batch_no': 'DB-20',
                    'parcels': [],
                  },
                ],
              }),
              200,
            ),
          ),
          kind: RiderAssignmentKind.delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buyer Rae'), findsOneWidget);
    expect(find.text('SH-20'), findsOneWidget);
    expect(find.text('1 parcel(s) · Assigned'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('assigned pickup list has an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAssignmentListPage(
          repository: _repository(
            (_) async => http.Response(jsonEncode({'data': []}), 200),
          ),
          kind: RiderAssignmentKind.pickup,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('There are no pickup assignments for you right now.'),
      findsOneWidget,
    );
  });

  testWidgets('read-only job detail displays waybill and parcel information', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({
                'data': {
                  'kind': 'delivery',
                  'id': 'SH-20',
                  'title': 'Buyer Rae',
                  'status': 'Assigned',
                  'address': 'Quezon City',
                  'contact_phone': '09170000000',
                  'waybill': 'WB-20',
                  'purpose': 'outbound',
                  'purpose_label': 'Buyer delivery',
                  'parcel_count': 1,
                  'zone': 'NCR',
                  'zone_name': 'North',
                  'batch_no': 'DB-20',
                  'parcels': [
                    {
                      'parcel_no': 'P-20',
                      'status': 'dispatched',
                      'size_class': 'small',
                      'weight_kg': 1.0,
                    },
                  ],
                },
              }),
              200,
            ),
          ),
          kind: RiderAssignmentKind.delivery,
          jobId: 'SH-20',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waybill: WB-20'), findsOneWidget);
    expect(find.text('P-20'), findsOneWidget);
    expect(find.text('Delivery Details'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('pickup detail accepts and confirms using server responses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var status = 'assigned';
    final requests = <http.Request>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository((request) async {
            requests.add(request);
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({'data': _pickupPayload(status)}),
                200,
              );
            }
            if (request.url.path.endsWith('/accept')) {
              status = 'accepted';
              return http.Response(
                jsonEncode({
                  'message': 'Pickup assignment accepted.',
                  'data': _pickupPayload(status),
                }),
                200,
              );
            }
            status = 'picked_up';
            return http.Response(
              jsonEncode({
                'message': 'Pickup confirmed.',
                'data': _pickupPayload(status),
              }),
              200,
            );
          }),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept pickup'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      find.text('The server confirmed that this pickup is accepted.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField), 'WB-10');
    final confirmButton = find.text('Verify waybill and confirm pickup');
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(
      find.text('The server confirmed collection of this pickup.'),
      findsOneWidget,
    );
    expect(requests.map((request) => request.method), ['GET', 'POST', 'POST']);
    expect(requests[1].url.path, '/api/mobile/rider/pickups/PU-10/accept');
    expect(requests[2].url.path, '/api/mobile/rider/pickups/PU-10/confirm');
    expect(jsonDecode(requests[2].body), {
      'waybill_identifier': 'WB-10',
      'scan_method': 'manual',
    });
  });

  testWidgets('waybill rejection shows server error and allows correction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var rejected = true;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({'data': _pickupPayload('accepted')}),
                200,
              );
            }
            if (rejected) {
              rejected = false;
              return http.Response(
                jsonEncode({
                  'message':
                      'The scanned waybill does not belong to this pickup.',
                }),
                409,
              );
            }
            return http.Response(
              jsonEncode({
                'message': 'Pickup confirmed.',
                'data': _pickupPayload('picked_up'),
              }),
              200,
            );
          }),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'WRONG-WB');
    final confirmButton = find.text('Verify waybill and confirm pickup');
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(
      find.text('The scanned waybill does not belong to this pickup.'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'WB-10');
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(
      find.text('The server confirmed collection of this pickup.'),
      findsOneWidget,
    );
  });

  testWidgets('failed job list request provides retry state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAssignmentListPage(
          repository: _repository(
            (_) async => http.Response('server error', 500),
          ),
          kind: RiderAssignmentKind.delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load assigned jobs'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Map<String, Object?> _pickupPayload(String statusRaw) => {
  'kind': 'pickup',
  'id': 'PU-10',
  'title': 'Store A',
  'status': switch (statusRaw) {
    'accepted' => 'Accepted',
    'picked_up' => 'Picked Up',
    _ => 'Assigned',
  },
  'status_raw': statusRaw,
  'address': 'San Pablo',
  'contact_name': 'Seller A',
  'contact_phone': '09170000000',
  'parcel_count': 1,
  'window': 'Today',
  'assigned_at': 'Now',
  'instructions': '',
  'manifest': [],
};

RiderRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => RiderRepository(
  authService:
      AuthService(
          apiClient: ApiClient(
            httpClient: MockClient(handler),
            baseUri: Uri.parse('http://127.0.0.1:8000'),
          ),
          tokenStore: _MemoryTokenStore()..token = 'rider-token',
        )
        ..currentSession = const AuthSession(
          id: 1,
          name: 'Rider Rae',
          email: 'rae@example.test',
          role: AccountRole.rider,
        ),
);

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
