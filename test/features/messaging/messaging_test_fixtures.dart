import 'dart:async';

import 'package:bearly_mobile/features/messaging/data/mobile_messaging_data_source.dart';
import 'package:bearly_mobile/features/messaging/models/mobile_messaging_models.dart';

MobileConversation testConversation({int id = 17, int unread = 2}) =>
    MobileConversation(
      id: id,
      subject: 'Delivery question',
      status: 'open',
      type: 'direct',
      counterparts: const [
        MobileMessageParticipant(
          name: 'Bearly Support',
          role: 'Bearly Support',
        ),
      ],
      preview: 'Use the north gate.',
      lastMessageAt: DateTime.parse('2026-11-06T09:00:00+08:00'),
      latestMessageId: 51,
      latestMessageFromMe: false,
      hasAttachments: false,
      unread: unread,
    );

MobileMessagesInbox testInbox({
  List<MobileConversation>? conversations,
  int unreadCount = 2,
  int page = 1,
  int? nextPage,
}) => MobileMessagesInbox(
  conversations: conversations ?? [testConversation()],
  unreadCount: unreadCount,
  currentPage: page,
  lastPage: nextPage ?? page,
  total: conversations?.length ?? 1,
  nextPage: nextPage,
);

MobileChatMessage testMessage({
  int id = 51,
  String text = 'Use the north gate.',
  bool isMine = false,
}) => MobileChatMessage(
  id: id,
  isMine: isMine,
  text: text,
  sentAt: DateTime.parse('2026-11-06T09:00:00+08:00'),
  timeLabel: '9:00 AM',
  dayLabel: 'Today',
  sender: MobileMessageParticipant(
    name: isMine ? 'You' : 'Bearly Support',
    role: isMine ? 'Rider' : 'Bearly Support',
  ),
  receiptLabel: isMine ? 'Seen' : null,
  attachments: const [],
);

MobileMessagePage testMessagePage({List<MobileChatMessage>? messages}) =>
    MobileMessagePage(
      conversation: testConversation(),
      messages: messages ?? [testMessage()],
      hasMore: false,
      nextBeforeId: null,
    );

class FakeMobileMessagingDataSource implements MobileMessagingDataSource {
  FakeMobileMessagingDataSource({
    List<MobileConversation>? conversations,
    List<MobileChatMessage>? messages,
    this.failInboxOnce = false,
    this.failThreadOnce = false,
  }) : conversations = conversations ?? [testConversation()],
       messages = messages ?? [testMessage()];

  List<MobileConversation> conversations;
  List<MobileChatMessage> messages;
  bool failInboxOnce;
  bool failThreadOnce;
  int unreadCount = 2;
  int inboxRequests = 0;
  int threadRequests = 0;
  int readRequests = 0;
  int sendRequests = 0;
  int? pendingPage;
  Completer<MobileMessagesInbox>? inboxCompleter;

  @override
  Future<MobileMessagesInbox> getConversations({
    int page = 1,
    int perPage = 20,
  }) async {
    inboxRequests++;
    final pending = inboxCompleter;
    if (pending != null) return pending.future;
    if (failInboxOnce) {
      failInboxOnce = false;
      throw StateError('network unavailable');
    }
    if (page == 2) {
      return testInbox(
        conversations: [testConversation(id: 18, unread: 0)],
        unreadCount: unreadCount,
        page: 2,
      );
    }
    return testInbox(
      conversations: conversations,
      unreadCount: unreadCount,
      nextPage: pendingPage,
    );
  }

  @override
  Future<int> getUnreadCount() async => unreadCount;

  @override
  Future<MobileMessagePage> getMessages(
    int conversationId, {
    int? beforeId,
    int perPage = 20,
  }) async {
    threadRequests++;
    if (failThreadOnce) {
      failThreadOnce = false;
      throw StateError('thread unavailable');
    }
    return MobileMessagePage(
      conversation: testConversation(),
      messages: beforeId == null ? messages : const [],
      hasMore: beforeId == null && pendingPage != null,
      nextBeforeId: beforeId == null && pendingPage != null ? 40 : null,
    );
  }

  @override
  Future<MobileChatMessage> sendMessage(
    int conversationId, {
    required String message,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    sendRequests++;
    final sent = testMessage(
      id: 60 + sendRequests,
      text: message,
      isMine: true,
    );
    messages = [...messages, sent];
    return sent;
  }

  @override
  Future<int> markRead(int conversationId) async {
    readRequests++;
    unreadCount = 0;
    return unreadCount;
  }

  @override
  Future<MobileAttachmentContent> downloadAttachment(int attachmentId) async =>
      const MobileAttachmentContent(
        bytes: [1, 2, 3],
        mimeType: 'application/pdf',
      );
}

class FakeMobileMessagingInitiationDataSource
    implements MobileMessagingInitiationDataSource {
  FakeMobileMessagingInitiationDataSource({this.failRecipients = false});

  bool failRecipients;
  int startRequests = 0;
  int? lastRecipientId;
  String? lastMessage;
  String? lastSubject;

  @override
  Future<List<MobileMessageRecipient>> getRecipients() async {
    if (failRecipients) throw StateError('contacts unavailable');
    return const [
      MobileMessageRecipient(
        id: 83,
        name: 'Dispatch Admin',
        role: 'admin',
        label: 'Administrator',
      ),
    ];
  }

  @override
  Future<MobileConversation> startConversation({
    required int recipientId,
    required String message,
    String subject = '',
  }) async {
    startRequests++;
    lastRecipientId = recipientId;
    lastMessage = message;
    lastSubject = subject;
    return testConversation();
  }
}
