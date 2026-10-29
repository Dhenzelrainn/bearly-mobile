import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/models/rider_assignment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RiderRepository', () {
    test('loads dashboard and assigned pickup and delivery jobs', () async {
      final requests = <http.Request>[];
      final service = _authService((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/dashboard')) {
          return http.Response(
            jsonEncode({
              'rider': {
                'name': 'Ria Rider',
                'vehicle_type': 'Motorcycle',
                'plate_number': 'TEST-1',
                'availability_status': 'available',
                'logistics_provider': 'North Logistics',
              },
              'metrics': {
                'assigned_pickups': 1,
                'pickup_in_progress': 0,
                'assigned_deliveries': 1,
                'out_for_delivery': 1,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/pickups')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'kind': 'pickup',
                  'id': 'PU-100',
                  'title': 'Store A',
                  'status': 'Assigned',
                  'status_raw': 'assigned',
                  'address': 'Cubao, Quezon City',
                  'contact_name': 'Seller A',
                  'contact_phone': '09170000000',
                  'parcel_count': 2,
                  'window': 'Today',
                  'assigned_at': 'Now',
                  'instructions': 'Side entrance',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': [
              {
                'kind': 'delivery',
                'id': 'SH-200',
                'title': 'Buyer B',
                'status': 'Out for Delivery',
                'address': 'BGC, Taguig',
                'contact_phone': '09171112222',
                'waybill': 'WB-200',
                'purpose': 'outbound',
                'purpose_label': 'Buyer delivery',
                'parcel_count': 1,
                'zone': 'BGC',
                'zone_name': 'Bonifacio Global City',
                'batch_no': 'DB-1',
                'parcels': [
                  {
                    'parcel_no': 'P-200',
                    'status': 'out_for_delivery',
                    'size_class': 'small',
                    'weight_kg': 1.2,
                  },
                ],
              },
            ],
          }),
          200,
        );
      });
      final repository = RiderRepository(authService: service);

      final dashboard = await repository.dashboard();
      final pickups = await repository.pickupJobs();
      final deliveries = await repository.deliveryJobs();

      expect(dashboard.name, 'Ria Rider');
      expect(dashboard.assignedPickups, 1);
      expect(dashboard.outForDelivery, 1);
      expect(pickups.single.kind, RiderAssignmentKind.pickup);
      expect(pickups.single.id, 'PU-100');
      expect(pickups.single.parcelCount, 2);
      expect(deliveries.single.kind, RiderAssignmentKind.delivery);
      expect(deliveries.single.parcels.single.parcelNumber, 'P-200');
      expect(requests.map((request) => request.url.path), [
        '/api/mobile/rider/dashboard',
        '/api/mobile/rider/pickups',
        '/api/mobile/rider/deliveries',
      ]);
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer rider-token',
        ),
        isTrue,
      );
    });

    test('loads read-only pickup and delivery details', () async {
      final requestedPaths = <String>[];
      final service = _authService((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.contains('/pickups/')) {
          return http.Response(
            jsonEncode({
              'data': {
                'kind': 'pickup',
                'id': 'PU 100',
                'title': 'Store A',
                'status': 'Assigned',
                'status_raw': 'assigned',
                'address': 'Cubao',
                'contact_name': 'Seller A',
                'contact_phone': '0917',
                'parcel_count': 1,
                'window': 'Today',
                'assigned_at': 'Now',
                'instructions': 'Call first',
                'manifest': [
                  {
                    'waybill': 'WB-1',
                    'products': [
                      {'name': 'Phone', 'variant': 'Blue', 'quantity': 2},
                    ],
                    'parcels': [
                      {
                        'parcel_no': 'P-1',
                        'waybill': 'WB-1',
                        'size': 'Small',
                        'status': 'Created',
                      },
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'kind': 'delivery',
              'id': 'SH-200',
              'title': 'Buyer B',
              'status': 'Assigned',
              'address': 'BGC',
              'contact_phone': '0917',
              'waybill': 'WB-200',
              'purpose': 'outbound',
              'purpose_label': 'Buyer delivery',
              'parcel_count': 1,
              'zone': 'BGC',
              'zone_name': 'BGC Zone',
              'batch_no': 'DB-1',
              'parcels': [
                {
                  'parcel_no': 'P-200',
                  'status': 'dispatched',
                  'size_class': 'small',
                  'weight_kg': 1.2,
                },
              ],
            },
          }),
          200,
        );
      });
      final repository = RiderRepository(authService: service);

      final pickup = await repository.pickupDetail('PU 100');
      final delivery = await repository.deliveryDetail('SH-200');

      expect(pickup.products, ['Phone · Blue × 2']);
      expect(pickup.parcels.single.waybill, 'WB-1');
      expect(delivery.waybill, 'WB-200');
      expect(delivery.parcels.single.parcelNumber, 'P-200');
      expect(requestedPaths, [
        '/api/mobile/rider/pickups/PU%20100',
        '/api/mobile/rider/deliveries/SH-200',
      ]);
    });
  });
}

AuthService _authService(Future<http.Response> Function(http.Request) handler) {
  final service = AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('http://127.0.0.1:8000'),
    ),
    tokenStore: _MemoryTokenStore()..token = 'rider-token',
  );
  service.currentSession = const AuthSession(
    id: 1,
    name: 'Ria Rider',
    email: 'ria@example.test',
    role: AccountRole.rider,
  );
  return service;
}

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
