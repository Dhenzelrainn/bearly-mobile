import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'repository uses the shared Buyer chat endpoints and cursor contract',
    () async {
      final requests = <http.Request>[];
      final auth = _auth((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/chat/conversations') && request.method == 'GET') {
          return _json({
            'data': {
              'conversations': [_conversation()],
            },
          });
        }
        if (path.endsWith('/chat/product')) {
          return _json({
            'data': {'conversation_id': 17},
          }, 201);
        }
        if (path.endsWith('/messages') && request.method == 'GET') {
          return _json({'data': _thread()});
        }
        if (path.endsWith('/messages')) {
          return _json({
            'data': {'message': _message(2, 'Question to seller', 'me')},
          });
        }
        if (path.endsWith('/read')) {
          return _json({
            'data': {'unread': 0},
          });
        }
        return _json({'message': 'Unexpected request.'}, 404);
      });
      final repository = BuyerChatRepository(authService: auth);

      final conversations = await repository.getConversations();
      expect(conversations.single.title, 'Sundays Market');
      expect(conversations.single.unread, 2);
      expect(await repository.startProductConversation(41), 17);
      final thread = await repository.getMessages(17, afterId: 5);
      expect(thread.messages.single.text, 'Reply from Seller');
      final sent = await repository.sendMessage(17, '  Question to seller  ');
      expect(sent.text, 'Question to seller');
      await repository.markRead(17);

      expect(requests.map((request) => request.method), [
        'GET',
        'POST',
        'GET',
        'POST',
        'POST',
      ]);
      expect(requests[0].url.path, '/api/mobile/buyer/chat/conversations');
      expect(requests[1].url.path, '/api/mobile/buyer/chat/product');
      expect(jsonDecode(requests[1].body), {'product_id': 41});
      expect(requests[2].url.queryParameters['after'], '5');
      expect(jsonDecode(requests[3].body), {'message': 'Question to seller'});
      expect(
        requests.last.url.path,
        '/api/mobile/buyer/chat/conversations/17/read',
      );
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer chat-test-token');
        expect(request.headers['accept'], 'application/json');
      }
    },
  );

  test(
    'repository rejects invalid local send input before a request',
    () async {
      var requestCount = 0;
      final repository = BuyerChatRepository(
        authService: _auth((request) async {
          requestCount++;
          return _json({'data': {}});
        }),
      );

      await expectLater(repository.sendMessage(4, '  '), throwsArgumentError);
      await expectLater(
        repository.sendMessage(4, List.filled(5001, 'x').join()),
        throwsArgumentError,
      );
      await expectLater(repository.getMessages(0), throwsRangeError);
      expect(requestCount, 0);
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
    );

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

Map<String, Object?> _conversation() => {
  'id': 17,
  'title': 'Sundays Market',
  'preview': 'Latest note',
  'time_label': '9:30 AM',
  'context': 'Classic Linen Shirt',
  'unread': 2,
  'status': 'open',
};

Map<String, Object?> _thread() => {
  'conversation': {
    'id': 17,
    'title': 'Sundays Market',
    'context': 'Classic Linen Shirt',
    'status': 'open',
  },
  'messages': [_message(6, 'Reply from Seller', 'them')],
  'receipt_updates': [],
};

Map<String, Object?> _message(int id, String text, String from) => {
  'id': id,
  'from': from,
  'text': text,
  'sent_at': '2026-11-01T09:00:00+08:00',
  'time_label': '9:00 AM',
  'day_label': 'Today',
  'attachments': [],
};

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'chat-test-token';

  @override
  Future<void> write(String token) async {}
}
