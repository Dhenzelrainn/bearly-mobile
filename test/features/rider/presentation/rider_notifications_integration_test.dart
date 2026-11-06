import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/notifications/data/mobile_notifications_data_source.dart';
import 'package:bearly_mobile/features/notifications/models/mobile_notification.dart';
import 'package:bearly_mobile/features/notifications/presentation/mobile_notifications_page.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'Rider dashboard opens shared notifications and refreshes badge',
    (tester) async {
      var dashboardRequests = 0;
      final authService =
          AuthService(
              apiClient: ApiClient(
                httpClient: MockClient((request) async {
                  expect(request.url.path, '/api/mobile/rider/dashboard');
                  dashboardRequests++;
                  return http.Response(
                    jsonEncode({
                      'rider': {
                        'name': 'Test Rider',
                        'work_type': 'courier',
                        'capabilities': {
                          'local_pickup': false,
                          'local_delivery': false,
                        },
                        'vehicle_type': 'Van',
                        'plate_number': 'COURIER-1',
                        'availability_status': 'available',
                        'logistics_provider': 'Test Logistics',
                      },
                      'metrics': {
                        'assigned_pickups': 0,
                        'pickup_in_progress': 0,
                        'assigned_deliveries': 0,
                        'out_for_delivery': 0,
                      },
                    }),
                    200,
                  );
                }),
                baseUri: Uri.parse('http://127.0.0.1:8000'),
              ),
              tokenStore: _MemoryTokenStore(),
            )
            ..currentSession = const AuthSession(
              id: 18,
              name: 'Test Courier',
              email: 'courier@example.test',
              role: AccountRole.rider,
            );
      final notifications = _FakeRiderNotifications();

      await tester.pumpWidget(
        MaterialApp(
          home: RiderHomePage(
            repository: RiderRepository(authService: authService),
            notificationsRepository: notifications,
          ),
          onGenerateRoute: (settings) {
            if (settings.name == AppRouteNames.riderNotifications) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => MobileNotificationsPage(
                  repository: notifications,
                  initialUnreadCount: settings.arguments! as int,
                ),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      final notificationButton = find.byTooltip('Notifications');
      expect(
        find.descendant(of: notificationButton, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.tap(notificationButton);
      await tester.pumpAndSettle();
      expect(find.text('Courier pickup assigned'), findsOneWidget);
      expect(
        find.text('A pickup is ready for your courier workflow.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Mark as read'));
      await tester.pumpAndSettle();
      expect(notifications.unreadCount, 0);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(dashboardRequests, 2);
      expect(notifications.unreadCountRequests, 2);
      expect(
        find.descendant(of: notificationButton, matching: find.text('1')),
        findsNothing,
      );
    },
  );

  testWidgets('shared Rider notifications handles empty and error states', (
    tester,
  ) async {
    final empty = _FakeRiderNotifications(items: const []);
    await tester.pumpWidget(
      MaterialApp(home: MobileNotificationsPage(repository: empty)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final failing = _FakeRiderNotifications(failNextListRequest: true);
    await tester.pumpWidget(
      MaterialApp(home: MobileNotificationsPage(repository: failing)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Courier pickup assigned'), findsOneWidget);
  });

  testWidgets(
    'shared notifications shows loading while Rider data is pending',
    (tester) async {
      final repository = _PendingNotifications();
      await tester.pumpWidget(
        MaterialApp(home: MobileNotificationsPage(repository: repository)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.completer.complete(
        MobileNotificationPage(
          items: [_courierNotification()],
          unreadCount: 1,
          currentPage: 1,
          lastPage: 1,
          total: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Courier pickup assigned'), findsOneWidget);
    },
  );
}

class _FakeRiderNotifications implements MobileNotificationsDataSource {
  _FakeRiderNotifications({
    List<MobileNotification>? items,
    this.failNextListRequest = false,
  }) : _items = items ?? [_courierNotification()];

  List<MobileNotification> _items;
  bool failNextListRequest;
  int unreadCount = 1;
  int unreadCountRequests = 0;

  @override
  Future<MobileNotificationPage> getNotifications({
    int page = 1,
    int perPage = 15,
  }) async {
    if (failNextListRequest) {
      failNextListRequest = false;
      throw StateError('network unavailable');
    }
    return MobileNotificationPage(
      items: _items,
      unreadCount: unreadCount,
      currentPage: page,
      lastPage: 1,
      total: _items.length,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    unreadCountRequests++;
    return unreadCount;
  }

  @override
  Future<int> markRead(String notificationId) async {
    _items = [
      for (final item in _items)
        if (item.id == notificationId) item.copyWith(read: true) else item,
    ];
    unreadCount = 0;
    return unreadCount;
  }

  @override
  Future<int> markAllRead() async {
    _items = _items.map((item) => item.copyWith(read: true)).toList();
    unreadCount = 0;
    return unreadCount;
  }
}

MobileNotification _courierNotification() => const MobileNotification(
  id: 'courier-pickup-1',
  title: 'Courier pickup assigned',
  body: 'A pickup is ready for your courier workflow.',
  read: false,
);

class _PendingNotifications implements MobileNotificationsDataSource {
  final completer = Completer<MobileNotificationPage>();

  @override
  Future<MobileNotificationPage> getNotifications({
    int page = 1,
    int perPage = 15,
  }) => completer.future;

  @override
  Future<int> getUnreadCount() async => 1;

  @override
  Future<int> markRead(String notificationId) async => 0;

  @override
  Future<int> markAllRead() async => 0;
}

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'test-token';

  @override
  Future<void> write(String value) async {}
}
