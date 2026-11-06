import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/notifications/data/mobile_notifications_data_source.dart';
import 'package:bearly_mobile/features/notifications/models/mobile_notification.dart';
import 'package:bearly_mobile/features/notifications/presentation/mobile_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'Logistics dashboard opens shared notifications and refreshes badge',
    (tester) async {
      var dashboardRequests = 0;
      var notificationUnreadCount = 2;
      var unreadCountRequests = 0;
      final auth = _authService((request) async {
        if (request.url.path == '/api/mobile/logistics/dashboard') {
          dashboardRequests++;
          return _json(_dashboard());
        }
        if (request.url.path ==
            '/api/mobile/logistics/notifications/unread-count') {
          unreadCountRequests++;
          return _json({
            'data': {'unread_count': notificationUnreadCount},
          });
        }
        if (request.url.path ==
            '/api/mobile/logistics/notifications/read-all') {
          notificationUnreadCount = 0;
          return _json({
            'data': {'unread_count': notificationUnreadCount},
          });
        }
        if (request.url.path.endsWith('/read')) {
          notificationUnreadCount = 1;
          return _json({
            'data': {'unread_count': notificationUnreadCount},
          });
        }
        if (request.url.path == '/api/mobile/logistics/notifications') {
          return _json({
            'data': {
              'items': [
                _notification('logistics-1'),
                _notification('logistics-2'),
              ],
              'unread_count': notificationUnreadCount,
              'next_page': null,
              'current_page': 1,
              'last_page': 1,
              'total': 2,
            },
            'message': 'Notifications loaded.',
          });
        }
        return http.Response('Not found', 404);
      });
      final cartController = BuyerCartController(authService: auth);
      final wishlistController = BuyerWishlistController(authService: auth);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRouteNames.logisticsDashboard,
                  ),
                  child: const Text('Open Logistics dashboard'),
                ),
              ),
            ),
          ),
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
            settings,
            authService: auth,
            cartController: cartController,
            wishlistController: wishlistController,
          ),
        ),
      );
      await tester.tap(find.text('Open Logistics dashboard'));
      await tester.pumpAndSettle();

      final notificationsButton = find.byTooltip('Notifications');
      expect(
        find.descendant(of: notificationsButton, matching: find.text('2')),
        findsOneWidget,
      );
      await tester.tap(notificationsButton);
      await tester.pumpAndSettle();
      expect(find.byType(MobileNotificationsPage), findsOneWidget);
      expect(find.text('Pickup request received'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Mark as read').first);
      await tester.pumpAndSettle();
      expect(notificationUnreadCount, 1);
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      expect(notificationUnreadCount, 0);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(dashboardRequests, 2);
      expect(unreadCountRequests, 2);
      expect(
        find.descendant(of: notificationsButton, matching: find.text('2')),
        findsNothing,
      );
      cartController.dispose();
      wishlistController.dispose();
    },
  );

  testWidgets('shared Logistics notifications shows empty and error states', (
    tester,
  ) async {
    final empty = _FakeNotifications(items: const []);
    await tester.pumpWidget(
      MaterialApp(home: MobileNotificationsPage(repository: empty)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final failing = _FakeNotifications(failNextListRequest: true);
    await tester.pumpWidget(
      MaterialApp(home: MobileNotificationsPage(repository: failing)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup request received'), findsOneWidget);
  });

  testWidgets('shared Logistics notifications shows a pending loading state', (
    tester,
  ) async {
    final repository = _PendingNotifications();
    await tester.pumpWidget(
      MaterialApp(home: MobileNotificationsPage(repository: repository)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.completer.complete(
      MobileNotificationPage(
        items: [_mobileNotification('pending')],
        unreadCount: 1,
        currentPage: 1,
        lastPage: 1,
        total: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pickup request received'), findsOneWidget);
  });
}

AuthService _authService(
  Future<http.Response> Function(http.Request) handler,
) =>
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

http.Response _json(Object value) => http.Response(jsonEncode(value), 200);

Map<String, Object?> _dashboard() => {
  'data': {
    'provider': {'id': 3, 'name': 'Victoria Logistics', 'status': 'active'},
    'sorting_center': {
      'id': 3,
      'name': 'Victoria Sorting Center',
      'code': 'SC-VIC-3',
      'status': 'active',
      'address': 'Victoria, Laguna',
    },
    'setup_required': false,
    'metrics': {
      'received_today': 1,
      'awaiting_sorting': 2,
      'sorted_ready': 1,
      'dispatched_shipments': 4,
      'active_routes': 1,
      'sorting_exceptions': 0,
      'pending_pickup_requests': 0,
      'incoming_handoffs': 0,
    },
    'incoming': {'handoffs': [], 'parcels': []},
  },
};

Map<String, Object?> _notification(String id) => {
  'id': id,
  'event': 'logistics_pickup_requested',
  'category': 'pickups',
  'title': 'Pickup request received',
  'body': 'A pickup request needs review.',
  'type': 'info',
  'read': false,
  'created_at': '2026-11-06T10:30:00+08:00',
  'created_at_human': 'a minute ago',
};

MobileNotification _mobileNotification(String id) => MobileNotification(
  id: id,
  title: 'Pickup request received',
  body: 'A pickup request needs review.',
  read: false,
);

class _FakeNotifications implements MobileNotificationsDataSource {
  _FakeNotifications({
    List<MobileNotification>? items,
    this.failNextListRequest = false,
  }) : _items = items ?? [_mobileNotification('retry')];

  final List<MobileNotification> _items;
  bool failNextListRequest;

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
      unreadCount: 1,
      currentPage: page,
      lastPage: 1,
      total: _items.length,
    );
  }

  @override
  Future<int> getUnreadCount() async => 1;

  @override
  Future<int> markRead(String notificationId) async => 0;

  @override
  Future<int> markAllRead() async => 0;
}

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
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}
