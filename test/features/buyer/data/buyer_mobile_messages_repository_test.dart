import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_mobile_messages_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'uses Buyer inbox, unread, cursor, read, and protected download APIs',
    () async {
      final requests = <http.Request>[];
      final repository = BuyerMobileMessagesRepository(
        authService: _auth((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/unread-count')) {
            return _json({
              'data': {'unread_count': 3},
            });
          }
          if (request.url.path.endsWith('/read')) {
            return _json({
              'data': {'unread': 0, 'unread_count': 0},
            });
          }
          if (request.url.path.endsWith('/attachments/77')) {
            return http.Response.bytes(
              [1, 2, 3],
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          if (request.method == 'GET' &&
              request.url.path == '/api/mobile/buyer/chat/conversations') {
            return _json(_inbox());
          }
          if (request.method == 'GET' &&
              request.url.path.endsWith('/messages')) {
            return _json(_thread());
          }
          return _json({'message': 'Not found.'}, 404);
        }),
      );

      final inbox = await repository.getConversations(perPage: 10);
      expect(inbox.conversations.single.title, 'Bearly Studio');
      expect(inbox.unreadCount, 3);
      expect(await repository.getUnreadCount(), 3);
      final page = await repository.getMessages(17, beforeId: 51, perPage: 10);
      expect(page.messages.single.text, 'Photo attached');
      expect(await repository.markRead(17), 0);
      final attachment = await repository.downloadAttachment(77);
      expect(attachment.bytes, [1, 2, 3]);
      expect(attachment.mimeType, 'image/png');

      expect(requests.map((request) => request.url.path), [
        '/api/mobile/buyer/chat/conversations',
        '/api/mobile/buyer/chat/unread-count',
        '/api/mobile/buyer/chat/conversations/17/messages',
        '/api/mobile/buyer/chat/conversations/17/read',
        '/api/mobile/buyer/chat/attachments/77',
      ]);
      expect(requests[0].url.queryParameters, {'per_page': '10', 'page': '1'});
      expect(requests[2].url.queryParameters, {
        'before_id': '51',
        'per_page': '10',
      });
      expect(
        requests.last.headers['authorization'],
        'Bearer buyer-message-test-token',
      );
      expect(requests.last.headers['accept'], '*/*');
    },
  );

  test(
    'starts product and owned-order conversations using server summaries',
    () async {
      final requests = <http.Request>[];
      final repository = BuyerMobileMessagesRepository(
        authService: _auth((request) async {
          requests.add(request);
          return _json({
            'data': {'conversation': _conversation()},
          }, 201);
        }),
      );

      expect((await repository.startProductConversation(41)).id, 17);
      expect((await repository.startSellerOrderConversation(23)).id, 17);
      expect(requests[0].url.path, '/api/mobile/buyer/chat/product');
      expect(jsonDecode(requests[0].body), {'product_id': 41});
      expect(requests[1].url.path, '/api/mobile/buyer/chat/seller-orders/23');
      expect(jsonDecode(requests[1].body), {});
    },
  );

  test('sends supported files using authenticated multipart upload', () async {
    late http.Request sentRequest;
    final repository = BuyerMobileMessagesRepository(
      authService: _auth((request) async {
        sentRequest = request;
        return _json({
          'data': {'message': _message()},
        });
      }),
    );

    final message = await repository.sendMessage(
      17,
      message: 'Photo attached',
      attachmentBytes: [1, 2, 3, 4],
      attachmentName: 'item.png',
    );
    expect(message.id, 51);
    expect(
      sentRequest.url.path,
      '/api/mobile/buyer/chat/conversations/17/messages',
    );
    expect(
      sentRequest.headers['authorization'],
      'Bearer buyer-message-test-token',
    );
    expect(
      sentRequest.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final body = utf8.decode(sentRequest.bodyBytes, allowMalformed: true);
    expect(body, contains('name="message"'));
    expect(body, contains('filename="item.png"'));
  });

  test('rejects invalid input before making requests', () async {
    var requests = 0;
    final repository = BuyerMobileMessagesRepository(
      authService: _auth((_) async {
        requests++;
        return _json({'data': {}});
      }),
    );
    await expectLater(
      repository.getConversations(perPage: 51),
      throwsRangeError,
    );
    await expectLater(repository.getMessages(0), throwsRangeError);
    await expectLater(repository.startProductConversation(0), throwsRangeError);
    await expectLater(
      repository.startSellerOrderConversation(0),
      throwsRangeError,
    );
    await expectLater(
      repository.sendMessage(17, message: ' '),
      throwsArgumentError,
    );
    await expectLater(
      repository.sendMessage(
        17,
        message: '',
        attachmentBytes: [1],
        attachmentName: 'evil.exe',
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
  });
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
        id: 18,
        name: 'Test Buyer',
        email: 'buyer@example.test',
        role: AccountRole.buyer,
      );

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

Map<String, Object?> _conversation() => {
  'id': 17,
  'subject': 'Product question',
  'status': 'open',
  'type': 'direct',
  'counterparts': [
    {'name': 'Bearly Studio', 'role': 'Seller'},
  ],
  'latest_message': {
    'id': 51,
    'preview': 'Seller replied.',
    'sent_at': '2026-11-08T12:00:00+08:00',
    'from_me': false,
    'has_attachments': false,
  },
  'unread': 1,
};

Map<String, Object?> _inbox() => {
  'data': {
    'conversations': [_conversation()],
    'unread_count': 3,
    'meta': {'current_page': 1, 'last_page': 1, 'total': 1, 'next_page': null},
  },
};

Map<String, Object?> _thread() => {
  'data': {
    'conversation': _conversation(),
    'messages': [_message()],
    'pagination': {'per_page': 10, 'has_more': false, 'next_before_id': null},
  },
};

Map<String, Object?> _message() => {
  'id': 51,
  'from': 'me',
  'text': 'Photo attached',
  'sent_at': '2026-11-08T12:00:00+08:00',
  'time_label': '12:00 PM',
  'day_label': 'Today',
  'sender': {'name': 'You', 'role': 'Buyer'},
  'receipt': {'label': 'Sent'},
  'attachments': [],
};

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'buyer-message-test-token';

  @override
  Future<void> write(String value) async {}
}
