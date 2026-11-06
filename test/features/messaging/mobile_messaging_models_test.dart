import 'package:bearly_mobile/features/messaging/models/mobile_messaging_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses participant-scoped inbox and cursor page payloads', () {
    final inbox = MobileMessagesInbox.fromJson({
      'data': {
        'conversations': [
          {
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
          },
        ],
        'unread_count': 2,
        'meta': {
          'current_page': 1,
          'last_page': 3,
          'total': 43,
          'next_page': 2,
        },
      },
    });
    expect(inbox.conversations.single.title, 'Bearly Support');
    expect(inbox.unreadCount, 2);
    expect(inbox.nextPage, 2);
    expect(inbox.total, 43);

    final thread = MobileMessagePage.fromJson({
      'data': {
        'conversation': {
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
        },
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
        'pagination': {'has_more': true, 'next_before_id': 51},
      },
    });
    expect(thread.messages.single.text, 'Use the north gate.');
    expect(thread.messages.single.sender.role, 'Bearly Support');
    expect(thread.hasMore, isTrue);
    expect(thread.nextBeforeId, 51);
  });

  test('rejects malformed and invalid paging response fields', () {
    expect(
      () => MobileMessagesInbox.fromJson({
        'data': {'conversations': 'bad'},
      }),
      throwsA(isA<MobileMessagingFormatException>()),
    );
  });
}
