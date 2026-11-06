import '../../auth/data/auth_service.dart';
import '../../messaging/data/mobile_messaging_data_source.dart';
import '../../messaging/models/mobile_messaging_models.dart';

class RiderMessagesRepository implements MobileMessagingDataSource {
  RiderMessagesRepository({required AuthService authService})
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
        '/api/mobile/rider/messages',
        queryParameters: {'page': page, 'per_page': perPage},
      ),
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _authService.getWithSession(
      '/api/mobile/rider/messages/unread-count',
    );
    return _unreadCount(response, 'data.unread_count');
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
    if (beforeId != null) {
      queryParameters['before_id'] = beforeId;
    }
    return MobileMessagePage.fromJson(
      await _authService.getWithSession(
        '/api/mobile/rider/messages/$conversationId/messages',
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
      throw ArgumentError.value(
        message,
        'message',
        'Write up to $messageMaxLength characters or attach a supported file.',
      );
    }

    final path = '/api/mobile/rider/messages/$conversationId/messages';
    final bytes = attachmentBytes;
    if (bytes == null || bytes.isEmpty) {
      return _authService.requestWithSession<MobileChatMessage>(
        method: AuthenticatedRequestMethod.post,
        path: path,
        body: {'message': body},
        parse: (response) =>
            MobileChatMessage.fromJson(_messagingData(response)['message']),
      );
    }

    final name = (attachmentName ?? '').trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        attachmentName,
        'attachmentName',
        'Required for file uploads.',
      );
    }
    if (bytes.length > attachmentMaxBytes) {
      throw ArgumentError.value(
        attachmentBytes,
        'attachmentBytes',
        'File exceeds 10 MB.',
      );
    }
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    if (!supportedAttachmentExtensions.contains(extension)) {
      throw ArgumentError.value(
        attachmentName,
        'attachmentName',
        'Unsupported file type.',
      );
    }

    return _authService.multipartRequestWithSession<MobileChatMessage>(
      path: path,
      fields: {'message': body},
      fileField: 'attachment',
      fileBytes: bytes,
      fileName: name,
      parse: (response) =>
          MobileChatMessage.fromJson(_messagingData(response)['message']),
    );
  }

  @override
  Future<int> markRead(int conversationId) async {
    _checkConversationId(conversationId);
    final response = await _authService.requestWithSession<Object?>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/rider/messages/$conversationId/read',
      parse: (value) => value,
    );
    return _unreadCount(response, 'data.unread_count');
  }

  @override
  Future<MobileAttachmentContent> downloadAttachment(int attachmentId) async {
    if (attachmentId < 1) {
      throw RangeError.value(attachmentId, 'attachmentId', 'Must be positive.');
    }
    final response = await _authService.downloadWithSession(
      path: '/api/mobile/rider/messages/attachments/$attachmentId',
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

  void _checkConversationId(int id) {
    if (id < 1) {
      throw RangeError.value(id, 'conversationId', 'Must be positive.');
    }
  }

  void _checkPage(int page, int perPage) {
    if (page < 1) throw RangeError.value(page, 'page', 'Must be positive.');
    if (perPage < 1 || perPage > 50) {
      throw RangeError.value(perPage, 'perPage', 'Must be between 1 and 50.');
    }
  }
}

int _unreadCount(Object? value, String field) {
  final count = _messagingData(value)['unread_count'];
  if (count is int && count >= 0) return count;
  if (count is String) {
    final parsed = int.tryParse(count);
    if (parsed != null && parsed >= 0) return parsed;
  }
  throw MobileMessagingFormatException(field);
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
