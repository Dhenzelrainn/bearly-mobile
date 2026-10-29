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
