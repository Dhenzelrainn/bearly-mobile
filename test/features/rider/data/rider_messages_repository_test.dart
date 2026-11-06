import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_messages_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'uses the Rider inbox, cursor, read, send, and protected download APIs',
    () async {
      final requests = <http.Request>[];
      final repository = RiderMessagesRepository(
        authService: _auth((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/unread-count')) {
            return _json({
              'data': {'unread_count': 2},
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
              headers: {'content-type': 'application/pdf'},
            );
          }
          if (request.url.path.endsWith('/messages') &&
              request.method == 'GET') {
            if (request.url.path == '/api/mobile/rider/messages') {
              return _json(_inboxPayload());
            }
            return _json(_threadPayload());
          }
          if (request.url.path.endsWith('/messages') &&
              request.method == 'POST') {
            return _json({
              'data': {
                'message': _message(id: 60, from: 'me', text: 'On my way.'),
              },
            });
          }
          return _json({'message': 'Unexpected request.'}, 404);
        }),
      );

      final inbox = await repository.getConversations(perPage: 10);
      expect(inbox.conversations.single.title, 'Bearly Support');
      expect(inbox.unreadCount, 2);
      expect(await repository.getUnreadCount(), 2);
      final page = await repository.getMessages(17, beforeId: 51, perPage: 10);
      expect(page.messages.single.text, 'Use the north gate.');
      final sent = await repository.sendMessage(17, message: ' On my way. ');
      expect(sent.text, 'On my way.');
      expect(await repository.markRead(17), 0);
      final attachment = await repository.downloadAttachment(77);
      expect(attachment.bytes, [1, 2, 3]);
      expect(attachment.mimeType, 'application/pdf');

      expect(requests.map((request) => request.url.path), [
        '/api/mobile/rider/messages',
        '/api/mobile/rider/messages/unread-count',
        '/api/mobile/rider/messages/17/messages',
        '/api/mobile/rider/messages/17/messages',
        '/api/mobile/rider/messages/17/read',
        '/api/mobile/rider/messages/attachments/77',
      ]);
      expect(requests[0].url.queryParameters, {'per_page': '10', 'page': '1'});
      expect(requests[2].url.queryParameters, {
        'before_id': '51',
        'per_page': '10',
      });
      expect(jsonDecode(requests[3].body), {'message': 'On my way.'});
      expect(requests.last.headers['accept'], '*/*');
      for (final request in requests) {
        expect(
          request.headers['authorization'],
          'Bearer rider-message-test-token',
        );
      }
    },
  );

  test('rejects out-of-range input before sending a request', () async {
    var requestCount = 0;
    final repository = RiderMessagesRepository(
      authService: _auth((_) async {
        requestCount++;
        return _json({'data': {}});
      }),
    );

    await expectLater(repository.getMessages(0), throwsRangeError);
    await expectLater(
      repository.getConversations(perPage: 51),
      throwsRangeError,
    );
    await expectLater(
      repository.sendMessage(17, message: ' '),
      throwsArgumentError,
    );
    await expectLater(repository.downloadAttachment(0), throwsRangeError);
    expect(requestCount, 0);
  });

  test(
    'sends supported attachments through the authenticated multipart API',
    () async {
      final requests = <http.Request>[];
      final repository = RiderMessagesRepository(
        authService: _auth((request) async {
          requests.add(request);
          return _json({
            'data': {
              'message': _message(id: 61, from: 'me', text: 'Proof attached.'),
            },
          });
        }),
      );

      final sent = await repository.sendMessage(
        17,
        message: 'Proof attached.',
        attachmentBytes: [1, 2, 3, 4],
        attachmentName: 'delivery-proof.pdf',
      );

      expect(sent.text, 'Proof attached.');
      expect(
        requests.single.url.path,
        '/api/mobile/rider/messages/17/messages',
      );
      expect(
        requests.single.headers['authorization'],
        'Bearer rider-message-test-token',
      );
      expect(
        requests.single.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = utf8.decode(requests.single.bodyBytes, allowMalformed: true);
      expect(body, contains('name="message"'));
      expect(body, contains('Proof attached.'));
      expect(body, contains('filename="delivery-proof.pdf"'));
      expect(body, contains('\u0001\u0002\u0003\u0004'));
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
        id: 18,
        name: 'Test Courier',
        email: 'courier@example.test',
        role: AccountRole.rider,
      );

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

Map<String, Object?> _inboxPayload() => {
  'data': {
    'conversations': [_conversation()],
    'unread_count': 2,
    'meta': {'current_page': 1, 'last_page': 1, 'total': 1, 'next_page': null},
  },
};

Map<String, Object?> _threadPayload() => {
  'data': {
    'conversation': _conversation(),
    'messages': [_message(id: 51, from: 'them', text: 'Use the north gate.')],
    'pagination': {'per_page': 10, 'has_more': false, 'next_before_id': null},
  },
};

Map<String, Object?> _conversation() => {
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
  'unread': 2,
};

Map<String, Object?> _message({
  required int id,
  required String from,
  required String text,
}) => {
  'id': id,
  'from': from,
  'text': text,
  'sent_at': '2026-11-06T09:00:00+08:00',
  'time_label': '9:00 AM',
  'day_label': 'Today',
  'sender': {
    'name': from == 'me' ? 'You' : 'Bearly Support',
    'role': from == 'me' ? 'Rider' : 'Bearly Support',
  },
  'receipt': from == 'me' ? {'label': 'Sent'} : null,
  'attachments': [],
};

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'rider-message-test-token';

  @override
  Future<void> write(String value) async {}
}
