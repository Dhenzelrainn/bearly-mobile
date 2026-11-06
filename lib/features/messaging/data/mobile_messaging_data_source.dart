import '../models/mobile_messaging_models.dart';

abstract interface class MobileMessagingDataSource {
  Future<MobileMessagesInbox> getConversations({
    int page = 1,
    int perPage = 20,
  });

  Future<int> getUnreadCount();

  Future<MobileMessagePage> getMessages(
    int conversationId, {
    int? beforeId,
    int perPage = 20,
  });

  Future<MobileChatMessage> sendMessage(
    int conversationId, {
    required String message,
    List<int>? attachmentBytes,
    String? attachmentName,
  });

  Future<int> markRead(int conversationId);

  Future<MobileAttachmentContent> downloadAttachment(int attachmentId);
}

/// Optional capability for roles allowed to start conversations.
abstract interface class MobileMessagingInitiationDataSource {
  Future<List<MobileMessageRecipient>> getRecipients();

  Future<MobileConversation> startConversation({
    required int recipientId,
    required String message,
    String subject = '',
  });
}
