import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/core/routes/app_route_names.dart';
import 'package:bearly_mobile/core/routes/app_routes.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_cart_controller.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_wishlist_controller.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'Logistics dashboard opens Messages and refreshes unread badge after reading',
    (tester) async {
      var unread = 2;
      var countRequests = 0;
      final paths = <String>[];
      final auth = _auth((request) async {
        paths.add(request.url.path);
        switch (request.url.path) {
          case '/api/mobile/logistics/dashboard':
            return _json(_dashboard());
          case '/api/mobile/logistics/messages/unread-count':
            countRequests++;
            return _json({
              'data': {'unread_count': unread},
            });
          case '/api/mobile/logistics/messages':
            return _json(_inbox(unread));
          case '/api/mobile/logistics/messages/17/messages':
            return _json(_thread(unread));
          case '/api/mobile/logistics/messages/17/read':
            unread = 0;
            return _json({
              'data': {'unread': 0, 'unread_count': 0},
            });
          default:
            return _json({'message': 'Not found'}, 404);
        }
      });
      final cart = BuyerCartController(authService: auth);
      final wishlist = BuyerWishlistController(authService: auth);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRouteNames.logisticsDashboard,
                ),
                child: const Text('Open Logistics dashboard'),
              ),
            ),
          ),
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
            settings,
            authService: auth,
            cartController: cart,
            wishlistController: wishlist,
          ),
        ),
      );
      await tester.tap(find.text('Open Logistics dashboard'));
      await tester.pumpAndSettle();

      final messagesButton = find.byTooltip('Messages');
      expect(
        find.descendant(of: messagesButton, matching: find.text('2')),
        findsOneWidget,
      );
      await tester.tap(messagesButton);
      await tester.pumpAndSettle();
      expect(find.byType(LogisticsMessagesPage), findsOneWidget);
      expect(find.text('Dispatch Center'), findsOneWidget);

      await tester.tap(find.text('Dispatch Center'));
      await tester.pumpAndSettle();
      expect(find.text('Use the north gate.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(paths, contains('/api/mobile/logistics/messages/17/read'));
      expect(countRequests, 2);
      expect(
        find.descendant(of: messagesButton, matching: find.text('2')),
        findsNothing,
      );
      expect(AppRouteNames.logisticsMessages, '/logistics/messages');
      cart.dispose();
      wishlist.dispose();
    },
  );
}

AuthService _auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        apiClient: ApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('https://api.example.test'),
        ),
        tokenStore: _MemoryTokenStore(),
      )
      ..currentSession = const AuthSession(
        id: 19,
        name: 'Logistics Operator',
        email: 'operator@example.test',
        role: AccountRole.logistics,
      );

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

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

Map<String, Object?> _inbox(int unread) => {
  'data': {
    'conversations': [_conversation(unread)],
    'unread_count': unread,
    'meta': {'current_page': 1, 'last_page': 1, 'total': 1, 'next_page': null},
  },
};

Map<String, Object?> _thread(int unread) => {
  'data': {
    'conversation': _conversation(unread),
    'messages': [
      {
        'id': 51,
        'from': 'them',
        'text': 'Use the north gate.',
        'sent_at': '2026-11-06T09:00:00+08:00',
        'time_label': '9:00 AM',
        'day_label': 'Today',
        'sender': {'name': 'Dispatch Center', 'role': 'Bearly Support'},
        'receipt': null,
        'attachments': [],
      },
    ],
    'pagination': {'per_page': 20, 'has_more': false, 'next_before_id': null},
  },
};

Map<String, Object?> _conversation(int unread) => {
  'id': 17,
  'subject': 'Handoff update',
  'status': 'open',
  'type': 'direct',
  'counterparts': [
    {'name': 'Dispatch Center', 'role': 'Bearly Support'},
  ],
  'latest_message': {
    'id': 51,
    'preview': 'Use the north gate.',
    'sent_at': '2026-11-06T09:00:00+08:00',
    'from_me': false,
    'has_attachments': false,
  },
  'unread': unread,
};

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'logistics-messages-test-token';

  @override
  Future<void> write(String value) async {}
}
