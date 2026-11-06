import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/rider/data/rider_notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses Rider-scoped paginated, unread, and read endpoints', () async {
    final requests = <http.Request>[];
    final repository = RiderNotificationsRepository(
      authService: _auth((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/notifications/unread-count')) {
          return _json({
            'data': {'unread_count': 2},
          });
        }
        if (request.url.path.endsWith('/notifications/read-all')) {
          return _json({
            'data': {'unread_count': 0},
          });
        }
        if (request.url.path.endsWith('/read')) {
          return _json({
            'data': {'unread_count': 1},
          });
        }
        return _json({
          'data': {
            'items': [_notification()],
            'unread_count': 2,
            'next_page': 2,
            'current_page': 1,
            'last_page': 2,
            'total': 16,
          },
          'message': 'Notifications loaded.',
        });
      }),
    );

    final page = await repository.getNotifications(page: 1, perPage: 8);
    expect(page.items.single.title, 'Pickup assignment');
    expect(page.unreadCount, 2);
    expect(page.nextPage, 2);
    expect(await repository.getUnreadCount(), 2);
    expect(await repository.markRead('notification-id'), 1);
    expect(await repository.markAllRead(), 0);

    expect(requests.map((request) => request.method), [
      'GET',
      'GET',
      'POST',
      'POST',
    ]);
    expect(requests.first.url.path, '/api/mobile/rider/notifications');
    expect(requests.first.url.queryParameters, {'page': '1', 'per_page': '8'});
    expect(
      requests[1].url.path,
      '/api/mobile/rider/notifications/unread-count',
    );
    expect(
      requests[2].url.path,
      '/api/mobile/rider/notifications/notification-id/read',
    );
    expect(requests[3].url.path, '/api/mobile/rider/notifications/read-all');
    for (final request in requests) {
      expect(
        request.headers['authorization'],
        'Bearer notification-test-token',
      );
    }
  });

  test('validates pagination and notification IDs locally', () async {
    var requestCount = 0;
    final repository = RiderNotificationsRepository(
      authService: _auth((_) async {
        requestCount++;
        return _json({
          'data': {'unread_count': 0},
        });
      }),
    );

    await expectLater(repository.getNotifications(page: 0), throwsRangeError);
    await expectLater(
      repository.getNotifications(perPage: 51),
      throwsRangeError,
    );
    await expectLater(repository.markRead('  '), throwsArgumentError);
    expect(requestCount, 0);
  });
}

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
      apiClient: ApiClient(
        httpClient: MockClient(handler),
        baseUri: Uri.parse('https://api.example.test'),
      ),
      tokenStore: _MemoryTokenStore(),
    );

http.Response _json(Object value) => http.Response(jsonEncode(value), 200);

Map<String, Object?> _notification() => {
  'id': 'notification-id',
  'event': 'rider_pickup_assigned',
  'category': 'deliveries',
  'title': 'Pickup assignment',
  'body': 'A pickup has been assigned to you.',
  'type': 'info',
  'read': false,
  'created_at': '2026-11-06T10:30:00+08:00',
  'created_at_human': 'a minute ago',
};

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'notification-test-token';

  @override
  Future<void> write(String token) async {}
}
