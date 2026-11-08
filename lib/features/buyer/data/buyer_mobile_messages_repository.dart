import '../../auth/data/auth_service.dart';
import '../../messaging/data/mobile_messaging_data_source.dart';
import '../../messaging/models/mobile_messaging_models.dart';

/// Buyer-scoped access to the shared Laravel conversation records.
/// The UI and message models are shared with Rider and Logistics; only the
/// Buyer API paths and permitted conversation initiation are role-specific.
class BuyerMobileMessagesRepository implements MobileMessagingDataSource {
  BuyerMobileMessagesRepository({required AuthService authService})
    : _authService = authService;

  static const int messageMaxLength = 5000;
  static const int attachmentMaxBytes = 10 * 1024 * 1024;
  static const Set<String> supportedAttachmentExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'mp4',
    'mov',
    'webm',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
    'csv',
    'zip',
  };

  final AuthService _authService;

  @override
  Future<MobileMessagesInbox> getConversations({
    int page = 1,
    int perPage = 20,
  }) async {
    _checkPage(page, perPage);
    return MobileMessagesInbox.fromJson(
      await _authService.getWithSession(
        '/api/mobile/buyer/chat/conversations',
        queryParameters: {'page': page, 'per_page': perPage},
      ),
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _authService.getWithSession(
      '/api/mobile/buyer/chat/unread-count',
    );
    return _unreadCount(response);
  }

  Future<MobileConversation> startProductConversation(int productId) async {
    if (productId < 1) {
      throw RangeError.value(productId, 'productId', 'Must be a positive ID.');
    }
    final response = await _authService.requestWithSession<MobileConversation>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/chat/product',
      body: {'product_id': productId},
      parse: (value) =>
          MobileConversation.fromJson(_messagingData(value)['conversation']),
    );
    return response;
  }

  Future<MobileConversation> startStoreConversation(String storeSlug) async {
    final slug = storeSlug.trim();
    if (slug.isEmpty || slug.length > 255) {
      throw ArgumentError.value(storeSlug, 'storeSlug');
    }
    return _authService.requestWithSession<MobileConversation>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/chat/store',
      body: {'store': slug},
      parse: (value) =>
          MobileConversation.fromJson(_messagingData(value)['conversation']),
    );
  }

  Future<MobileConversation> startSellerOrderConversation(
    int sellerOrderId,
  ) async {
    _checkConversationId(sellerOrderId, field: 'sellerOrderId');
    return _authService.requestWithSession<MobileConversation>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/chat/seller-orders/$sellerOrderId',
      body: const {},
      parse: (value) =>
          MobileConversation.fromJson(_messagingData(value)['conversation']),
    );
  }

  @override
  Future<MobileMessagePage> getMessages(
    int conversationId, {
    int? beforeId,
    int perPage = 20,
  }) async {
    _checkConversationId(conversationId);
    _checkPage(1, perPage);
    if (beforeId != null && beforeId < 1) {
      throw RangeError.value(beforeId, 'beforeId', 'Must be positive.');
    }
    final queryParameters = <String, Object?>{'per_page': perPage};
    if (beforeId != null) queryParameters['before_id'] = beforeId;
    return MobileMessagePage.fromJson(
      await _authService.getWithSession(
        '/api/mobile/buyer/chat/conversations/$conversationId/messages',
        queryParameters: queryParameters,
      ),
    );
  }

  @override
  Future<MobileChatMessage> sendMessage(
    int conversationId, {
    required String message,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    _checkConversationId(conversationId);
    final body = message.trim();
    if (body.length > messageMaxLength ||
        (body.isEmpty &&
            (attachmentBytes == null || attachmentBytes.isEmpty))) {
      throw ArgumentError.value(message, 'message');
    }

    final path =
        '/api/mobile/buyer/chat/conversations/$conversationId/messages';
    final bytes = attachmentBytes;
    if (bytes == null || bytes.isEmpty) {
      return _authService.requestWithSession<MobileChatMessage>(
        method: AuthenticatedRequestMethod.post,
        path: path,
        body: {'message': body},
        parse: (value) =>
            MobileChatMessage.fromJson(_messagingData(value)['message']),
      );
    }

    final name = (attachmentName ?? '').trim();
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    if (name.isEmpty ||
        bytes.length > attachmentMaxBytes ||
        !supportedAttachmentExtensions.contains(extension)) {
      throw ArgumentError.value(attachmentName, 'attachmentName');
    }
    return _authService.multipartRequestWithSession<MobileChatMessage>(
      path: path,
      fields: {'message': body},
      fileField: 'attachment',
      fileBytes: bytes,
      fileName: name,
      parse: (value) =>
          MobileChatMessage.fromJson(_messagingData(value)['message']),
    );
  }

  @override
  Future<int> markRead(int conversationId) async {
    _checkConversationId(conversationId);
    final response = await _authService.requestWithSession<Object?>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/chat/conversations/$conversationId/read',
      parse: (value) => value,
    );
    return _unreadCount(response);
  }

  @override
  Future<MobileAttachmentContent> downloadAttachment(int attachmentId) async {
    _checkConversationId(attachmentId, field: 'attachmentId');
    final response = await _authService.downloadWithSession(
      path: '/api/mobile/buyer/chat/attachments/$attachmentId',
    );
    return MobileAttachmentContent(
      bytes: response.bytes,
      mimeType: (response.contentType ?? 'application/octet-stream')
          .split(';')
          .first
          .trim()
          .toLowerCase(),
    );
  }

  void _checkConversationId(int id, {String field = 'conversationId'}) {
    if (id < 1) throw RangeError.value(id, field, 'Must be positive.');
  }

  void _checkPage(int page, int perPage) {
    if (page < 1) throw RangeError.value(page, 'page', 'Must be positive.');
    if (perPage < 1 || perPage > 50) {
      throw RangeError.value(perPage, 'perPage', 'Must be between 1 and 50.');
    }
  }
}

int _unreadCount(Object? value) {
  final count = _messagingData(value)['unread_count'];
  if (count is int && count >= 0) return count;
  if (count is String) {
    final parsed = int.tryParse(count);
    if (parsed != null && parsed >= 0) return parsed;
  }
  throw const MobileMessagingFormatException('data.unread_count');
}

Map<String, Object?> _messagingData(Object? value) {
  if (value is! Map || value['data'] is! Map) {
    throw const MobileMessagingFormatException('data');
  }
  final data = value['data'] as Map;
  return {
    for (final entry in data.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}
