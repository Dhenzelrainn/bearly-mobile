import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads the provider roster and Courier-specific capacity', () async {
    final requests = <String>[];
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        requests.add(request.url.path);
        return http.Response(jsonEncode(_roster), 200);
      }),
    );

    final riders = await repository.riders();

    expect(requests, ['/api/mobile/logistics/riders']);
    expect(riders, hasLength(2));
    expect(riders.first.name, 'Local Rider');
    expect(riders.first.capacity, 8);
    expect(riders.first.isCourier, isFalse);
    expect(riders.last.name, 'Courier Driver');
    expect(riders.last.capacity, 24);
    expect(riders.last.capacityLabel, 'Line-haul parcels');
    expect(riders.last.isCourier, isTrue);
  });

  test('loads a provider-owned Rider details record by user id', () async {
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        expect(request.url.path, '/api/mobile/logistics/riders/31');
        return http.Response(
          jsonEncode({
            'data': {
              'provider': {'id': 3, 'name': 'North Logistics'},
              'rider': _rider(31, 'Local Rider'),
            },
          }),
          200,
        );
      }),
    );

    final rider = await repository.rider(31);

    expect(rider.userId, 31);
    expect(rider.workType, 'local');
    expect(rider.verificationStatus, 'approved');
    expect(rider.activeJobs, 2);
  });
}

Map<String, Object?> _rider(int id, String name, {String workType = 'local'}) =>
    {
      'id': id,
      'user_id': id,
      'profile_id': id + 100,
      'name': name,
      'work_type': workType,
      'work_type_label': workType == 'courier' ? 'Courier' : 'Local Rider',
      'account_status': 'active',
      'verification_status': 'approved',
      'availability_status': 'available',
      'operational_status': 'available',
      'vehicle_type': workType == 'courier' ? 'Van' : 'Motorcycle',
      'vehicle_model': 'Cargo',
      'plate_number': 'ABC-1234',
      'capacity': workType == 'courier' ? 24 : 8,
      'capacity_label': workType == 'courier'
          ? 'Line-haul parcels'
          : 'Local parcels',
      'active_jobs': 2,
      'completed_today': 1,
    };

final _roster = {
  'data': {
    'provider': {'id': 3, 'name': 'North Logistics'},
    'riders': [
      _rider(31, 'Local Rider'),
      _rider(32, 'Courier Driver', workType: 'courier'),
    ],
  },
};

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('http://127.0.0.1:8000'),
        ),
        tokenStore: _MemoryTokenStore()..token = 'logistics-test-token',
      )
      ..currentSession = const AuthSession(
        id: 19,
        name: 'Logistics Operator',
        email: 'operator@example.test',
        role: AccountRole.logistics,
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
