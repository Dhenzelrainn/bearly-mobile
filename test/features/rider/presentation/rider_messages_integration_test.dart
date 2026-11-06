import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/rider/data/rider_messages_repository.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'dashboard opens authenticated messages and refreshes unread badge',
    (tester) async {
      var unreadCount = 3;
      final paths = <String>[];
      final authService =
          AuthService(
              apiClient: ApiClient(
                httpClient: MockClient((request) async {
                  paths.add(request.url.path);
                  switch (request.url.path) {
                    case '/api/mobile/rider/dashboard':
                      return _json({
                        'rider': {
                          'name': 'Test Courier',
                          'work_type': 'courier',
                          'capabilities': {
                            'local_pickup': false,
                            'local_delivery': false,
                          },
                          'vehicle_type': 'Van',
                          'availability_status': 'available',
                          'logistics_provider': 'Test Logistics',
                        },
                        'metrics': {
                          'assigned_pickups': 0,
                          'pickup_in_progress': 0,
                          'assigned_deliveries': 0,
                          'out_for_delivery': 0,
                        },
                      });
                    case '/api/mobile/rider/messages/unread-count':
                      return _json({
                        'data': {'unread_count': unreadCount},
                      });
                    case '/api/mobile/rider/messages':
                      return _json(_inbox(unreadCount));
                    case '/api/mobile/rider/messages/17/messages':
                      if (request.method == 'GET') {
                        return _json(_thread(unreadCount));
                      }
                      return _json({'message': 'Unexpected request'}, 404);
                    case '/api/mobile/rider/messages/17/read':
                      unreadCount = 0;
                      return _json({
                        'data': {'unread': 0, 'unread_count': 0},
                      });
                    default:
                      return _json({'message': 'Not found'}, 404);
                  }
                }),
                baseUri: Uri.parse('https://api.example.test'),
              ),
              tokenStore: _MemoryTokenStore(),
            )
            ..currentSession = const AuthSession(
              id: 18,
              name: 'Test Courier',
              email: 'courier@example.test',
              role: AccountRole.rider,
            );
      final cart = BuyerCartController(authService: authService);
      final wishlist = BuyerWishlistController(authService: authService);

      await tester.pumpWidget(
        MaterialApp(
          home: RiderHomePage(
            repository: RiderRepository(authService: authService),
            messagesRepository: RiderMessagesRepository(
              authService: authService,
            ),
          ),
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
            settings,
            authService: authService,
            cartController: cart,
            wishlistController: wishlist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(paths, contains('/api/mobile/rider/messages'));
      expect(find.text('Bearly Support'), findsWidgets);

      await tester.tap(find.text('Bearly Support').first);
      await tester.pumpAndSettle();
      expect(find.text('Use the north gate.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();

      expect(paths, contains('/api/mobile/rider/messages/17/read'));
      expect(
        paths
            .where((path) => path == '/api/mobile/rider/messages/unread-count')
            .length,
        2,
      );
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('3'), findsNothing);
      expect(find.byTooltip('Notifications'), findsNothing);
      expect(AppRouteNames.riderMessages, '/rider/messages');
    },
  );
}

Map<String, Object?> _inbox(int unreadCount) => {
  'data': {
    'conversations': [_conversation(unreadCount)],
    'unread_count': unreadCount,
    'meta': {'current_page': 1, 'last_page': 1, 'total': 1, 'next_page': null},
  },
};

Map<String, Object?> _thread(int unreadCount) => {
  'data': {
    'conversation': _conversation(unreadCount),
    'messages': [
      {
        'id': 51,
        'from': 'them',
        'text': 'Use the north gate.',
        'sent_at': '2026-11-06T09:00:00+08:00',
        'time_label': '9:00 AM',
        'day_label': 'Today',
        'sender': {'name': 'Bearly Support', 'role': 'Bearly Support'},
        'receipt': null,
        'attachments': [],
      },
    ],
    'pagination': {'per_page': 20, 'has_more': false, 'next_before_id': null},
  },
};

Map<String, Object?> _conversation(int unreadCount) => {
  'id': 17,
  'subject': 'Delivery question',
  'status': 'open',
  'type': 'direct',
  'counterparts': [
    {'name': 'Bearly Support', 'role': 'Bearly Support'},
  ],
  'latest_message': {
    'id': 51,
    'preview': 'Use the north gate.',
    'sent_at': '2026-11-06T09:00:00+08:00',
    'from_me': false,
    'has_attachments': false,
  },
  'unread': unreadCount,
};

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'rider-messages-test-token';

  @override
  Future<void> write(String value) async {}
}
