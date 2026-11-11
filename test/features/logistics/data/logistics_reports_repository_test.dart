import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'requests provider-scoped reports with a validated date range',
    () async {
      http.Request? received;
      final repository = LogisticsRepository(
        authService: _auth((request) async {
          received = request;
          return http.Response(jsonEncode(_reports()), 200);
        }),
      );

      final reports = await repository.reports(
        from: '2026-11-01',
        to: '2026-11-07',
      );

      expect(received!.url.path, '/api/mobile/logistics/reports');
      expect(received!.url.queryParameters, {
        'from': '2026-11-01',
        'to': '2026-11-07',
      });
      expect(received!.headers['authorization'], 'Bearer logistics-test-token');
      expect(reports.period.timezone, 'Asia/Manila');
      expect(reports.summary.parcelThroughput, 17);
      expect(reports.summary.deliveredParcels, 9);
      expect(reports.summary.successRatePercent, 81.5);
      expect(reports.summary.averageSortTime, '42m');
      expect(reports.dailyThroughput.single.parcelCount, 17);
      expect(reports.deliveryStatusBreakdown.first.sharePercent, 75.0);
      expect(reports.riderPerformance.single.assignedParcels, 11);
    },
  );

  test('uses the server default period when no dates are selected', () async {
    http.Request? received;
    final repository = LogisticsRepository(
      authService: _auth((request) async {
        received = request;
        return http.Response(jsonEncode(_reports()), 200);
      }),
    );

    await repository.reports();

    expect(received!.url.path, '/api/mobile/logistics/reports');
    expect(received!.url.queryParameters, isEmpty);
  });

  test(
    'rejects malformed and reversed dates before making a request',
    () async {
      var requests = 0;
      final repository = LogisticsRepository(
        authService: _auth((_) async {
          requests++;
          return http.Response(jsonEncode(_reports()), 200);
        }),
      );

      await expectLater(
        repository.reports(from: '2026-2-1'),
        throwsArgumentError,
      );
      await expectLater(
        repository.reports(from: '2026-11-08', to: '2026-11-07'),
        throwsArgumentError,
      );
      expect(requests, 0);
    },
  );
}

Map<String, Object?> _reports() => {
  'data': {
    'period': {
      'from': '2026-11-01',
      'to': '2026-11-07',
      'timezone': 'Asia/Manila',
    },
    'summary': {
      'parcel_throughput': 17,
      'delivered_parcels': 9,
      'success_rate_percent': 81.5,
      'resolved_delivery_outcomes': 11,
      'average_sort_time': '42m',
    },
    'daily_throughput': [
      {'label': 'Nov 1', 'parcel_count': 17},
    ],
    'delivery_status_breakdown': [
      {'label': 'Delivered', 'value': 3, 'share': 75.0},
    ],
    'rider_performance': [
      {
        'name': 'Report Rider One',
        'assigned': 11,
        'delivered': 9,
        'failed': 2,
        'rate': '81.8%',
      },
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
