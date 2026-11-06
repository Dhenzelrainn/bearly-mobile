import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_messages_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'uses the Logistics inbox, contacts, cursor, create, read, and download APIs',
    () async {
      final requests = <http.Request>[];
      final repository = LogisticsMessagesRepository(
        authService: _auth((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/recipients')) {
            return _json({
              'data': {
                'recipients': [
                  {
                    'id': 83,
                    'name': 'Dispatch Admin',
                    'role': 'admin',
                    'label': 'Administrator',
                  },
                ],
              },
            });
          }
          if (request.url.path.endsWith('/conversations') &&
              request.method == 'POST') {
            return _json({
              'data': {'conversation': _conversation()},
            }, 201);
          }
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
            return request.url.path == '/api/mobile/logistics/messages'
                ? _json(_inbox())
                : _json(_thread());
          }
          if (request.url.path.endsWith('/messages') &&
              request.method == 'POST') {
            return _json({
              'data': {'message': _message(text: 'On my way.', from: 'me')},
            });
          }
          return _json({'message': 'Unexpected request.'}, 404);
        }),
      );

      final recipients = await repository.getRecipients();
      expect(recipients.single.name, 'Dispatch Admin');
      final created = await repository.startConversation(
        recipientId: 83,
        subject: ' Pickup coordination ',
        message: ' Please confirm the window. ',
      );
      expect(created.id, 17);
      final inbox = await repository.getConversations(perPage: 10);
      expect(inbox.unreadCount, 2);
      expect(await repository.getUnreadCount(), 2);
      final page = await repository.getMessages(17, beforeId: 51, perPage: 10);
      expect(page.messages.single.text, 'Use the north gate.');
      expect(
        (await repository.sendMessage(17, message: 'On my way.')).text,
        'On my way.',
      );
      expect(await repository.markRead(17), 0);
      expect(
        (await repository.downloadAttachment(77)).mimeType,
        'application/pdf',
      );

      expect(requests.map((request) => request.url.path), [
        '/api/mobile/logistics/messages/recipients',
        '/api/mobile/logistics/messages/conversations',
        '/api/mobile/logistics/messages',
        '/api/mobile/logistics/messages/unread-count',
        '/api/mobile/logistics/messages/17/messages',
        '/api/mobile/logistics/messages/17/messages',
        '/api/mobile/logistics/messages/17/read',
        '/api/mobile/logistics/messages/attachments/77',
      ]);
      expect(jsonDecode(requests[1].body), {
        'recipient_id': 83,
        'subject': 'Pickup coordination',
        'message': 'Please confirm the window.',
      });
      expect(requests[4].url.queryParameters, {
        'before_id': '51',
        'per_page': '10',
      });
      expect(requests.last.headers['accept'], '*/*');
      for (final request in requests) {
        expect(
          request.headers['authorization'],
          'Bearer logistics-message-test-token',
        );
      }
    },
  );

  test(
    'rejects invalid IDs, content, pages, and unsupported attachment types locally',
    () async {
      var requestCount = 0;
      final repository = LogisticsMessagesRepository(
        authService: _auth((_) async {
          requestCount++;
          return _json({'data': {}});
        }),
      );
      await expectLater(repository.getConversations(page: 0), throwsRangeError);
      await expectLater(repository.getMessages(0), throwsRangeError);
      await expectLater(
        repository.startConversation(recipientId: 0, message: 'Hi'),
        throwsRangeError,
      );
      await expectLater(
        repository.startConversation(recipientId: 4, message: ' '),
        throwsArgumentError,
      );
      await expectLater(
        repository.sendMessage(4, message: ' '),
        throwsArgumentError,
      );
      await expectLater(
        repository.sendMessage(
          4,
          message: '',
          attachmentBytes: [1],
          attachmentName: 'payload.exe',
        ),
        throwsArgumentError,
      );
      expect(requestCount, 0);
    },
  );

  test(
    'uploads a supported attachment through authenticated multipart API',
    () async {
      http.Request? captured;
      final repository = LogisticsMessagesRepository(
        authService: _auth((request) async {
          captured = request;
          return _json({
            'data': {'message': _message()},
          });
        }),
      );
      await repository.sendMessage(
        17,
        message: 'Dispatch proof',
        attachmentBytes: [1, 2, 3, 4],
        attachmentName: 'dispatch-proof.pdf',
      );
      expect(captured!.url.path, '/api/mobile/logistics/messages/17/messages');
      expect(
        captured!.headers['authorization'],
        'Bearer logistics-message-test-token',
      );
      expect(
        captured!.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = utf8.decode(captured!.bodyBytes, allowMalformed: true);
      expect(body, contains('filename="dispatch-proof.pdf"'));
      expect(body, contains('Dispatch proof'));
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

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

Map<String, Object?> _inbox() => {
  'data': {
    'conversations': [_conversation()],
    'unread_count': 2,
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

Map<String, Object?> _conversation() => {
  'id': 17,
  'subject': 'Delivery coordination',
  'status': 'open',
  'type': 'direct',
  'counterparts': [
    {'name': 'Dispatch Admin', 'role': 'Bearly Support'},
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
  String text = 'Use the north gate.',
  String from = 'them',
}) => {
  'id': 51,
  'from': from,
  'text': text,
  'sent_at': '2026-11-06T09:00:00+08:00',
  'time_label': '9:00 AM',
  'day_label': 'Today',
  'sender': {
    'name': from == 'me' ? 'You' : 'Dispatch Admin',
    'role': from == 'me' ? 'Logistics' : 'Bearly Support',
  },
  'receipt': null,
  'attachments': [],
};

class _MemoryTokenStore implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'logistics-message-test-token';

  @override
  Future<void> write(String value) async {}
}
