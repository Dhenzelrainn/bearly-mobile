class MobileMessageParticipant {
  const MobileMessageParticipant({required this.name, required this.role});

  final String name;
  final String role;

  factory MobileMessageParticipant.fromJson(Object? value) {
    final json = _messagingMap(value, 'participant');
    return MobileMessageParticipant(
      name: _messagingString(json['name']),
      role: _messagingString(json['role']),
    );
  }
}

class MobileMessageRecipient {
  const MobileMessageRecipient({
    required this.id,
    required this.name,
    required this.role,
    required this.label,
  });

  final int id;
  final String name;
  final String role;
  final String label;

  factory MobileMessageRecipient.fromJson(Object? value) {
    final json = _messagingMap(value, 'recipient');
    final id = _messagingInt(json['id']);
    if (id < 1) throw const MobileMessagingFormatException('recipient.id');
    return MobileMessageRecipient(
      id: id,
      name: _messagingString(json['name']),
      role: _messagingString(json['role']),
      label: _messagingString(json['label']),
    );
  }
}

class MobileConversation {
  const MobileConversation({
    required this.id,
    required this.subject,
    required this.status,
    required this.type,
    required this.counterparts,
    required this.preview,
    required this.lastMessageAt,
    required this.latestMessageId,
    required this.latestMessageFromMe,
    required this.hasAttachments,
    required this.unread,
  });

  final int id;
  final String subject;
  final String status;
  final String type;
  final List<MobileMessageParticipant> counterparts;
  final String preview;
  final DateTime? lastMessageAt;
  final int? latestMessageId;
  final bool latestMessageFromMe;
  final bool hasAttachments;
  final int unread;

  String get title => counterparts.isEmpty
      ? (subject.isEmpty ? 'Conversation' : subject)
      : counterparts.first.name;

  String get participantSubtitle => counterparts.isEmpty
      ? subject
      : counterparts.map((participant) => participant.role).join(', ');

  factory MobileConversation.fromJson(Object? value) {
    final json = _messagingMap(value, 'conversation');
    final id = _messagingInt(json['id']);
    final unread = _messagingInt(json['unread']);
    final rawCounterparts = json['counterparts'];
    final latest = _messagingMap(json['latest_message'], 'latest_message');
    final latestIdValue = latest['id'];
    final latestId = latestIdValue == null
        ? null
        : _messagingInt(latestIdValue);
    if (id < 1 || unread < 0 || (latestId != null && latestId < 1)) {
      throw const MobileMessagingFormatException('conversation');
    }
    if (rawCounterparts is! List) {
      throw const MobileMessagingFormatException('conversation.counterparts');
    }
    final timestamp = latest['sent_at'];
    return MobileConversation(
      id: id,
      subject: _messagingString(json['subject']),
      status: _messagingString(json['status']),
      type: _messagingString(json['type']),
      counterparts: List.unmodifiable(
        rawCounterparts.map(MobileMessageParticipant.fromJson),
      ),
      preview: _messagingString(latest['preview']),
      lastMessageAt: timestamp is String ? DateTime.tryParse(timestamp) : null,
      latestMessageId: latestId,
      latestMessageFromMe: latest['from_me'] == true,
      hasAttachments: latest['has_attachments'] == true,
      unread: unread,
    );
  }
}

class MobileMessagesInbox {
  const MobileMessagesInbox({
    required this.conversations,
    required this.unreadCount,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.nextPage,
  });

  final List<MobileConversation> conversations;
  final int unreadCount;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? nextPage;

  factory MobileMessagesInbox.fromJson(Object? value) {
    final data = _messagingEnvelope(value);
    final rawConversations = data['conversations'];
    if (rawConversations is! List) {
      throw const MobileMessagingFormatException('data.conversations');
    }
    final meta = _messagingMap(data['meta'], 'data.meta');
    final next = meta['next_page'];
    return MobileMessagesInbox(
      conversations: List.unmodifiable(
        rawConversations.map(MobileConversation.fromJson),
      ),
      unreadCount: _messagingInt(data['unread_count']),
      currentPage: _messagingInt(meta['current_page']),
      lastPage: _messagingInt(meta['last_page']),
      total: _messagingInt(meta['total']),
      nextPage: next == null ? null : _messagingInt(next),
    );
  }
}

class MobileMessageAttachment {
  const MobileMessageAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.isImage,
    required this.isVideo,
    required this.isPreviewable,
  });

  final int id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final bool isImage;
  final bool isVideo;
  final bool isPreviewable;

  factory MobileMessageAttachment.fromJson(Object? value) {
    final json = _messagingMap(value, 'attachment');
    final id = _messagingInt(json['id']);
    if (id < 1) throw const MobileMessagingFormatException('attachment.id');
    return MobileMessageAttachment(
      id: id,
      name: _messagingString(json['name']),
      mimeType: _messagingString(json['mime_type']),
      sizeBytes: _messagingInt(json['size_bytes']),
      isImage: json['is_image'] == true,
      isVideo: json['is_video'] == true,
      isPreviewable: json['is_previewable'] == true,
    );
  }
}

class MobileChatMessage {
  const MobileChatMessage({
    required this.id,
    required this.isMine,
    required this.text,
    required this.sentAt,
    required this.timeLabel,
    required this.dayLabel,
    required this.sender,
    required this.receiptLabel,
    required this.attachments,
  });

  final int id;
  final bool isMine;
  final String text;
  final DateTime? sentAt;
  final String timeLabel;
  final String dayLabel;
  final MobileMessageParticipant sender;
  final String? receiptLabel;
  final List<MobileMessageAttachment> attachments;

  factory MobileChatMessage.fromJson(Object? value) {
    final json = _messagingMap(value, 'message');
    final id = _messagingInt(json['id']);
    final from = json['from'];
    final rawAttachments = json['attachments'];
    if (id < 1 || (from != 'me' && from != 'them') || rawAttachments is! List) {
      throw const MobileMessagingFormatException('message');
    }
    final timestamp = json['sent_at'];
    final receipt = json['receipt'];
    final receiptLabel = receipt is Map && receipt['label'] is String
        ? receipt['label'] as String
        : null;
    return MobileChatMessage(
      id: id,
      isMine: from == 'me',
      text: _messagingString(json['text']),
      sentAt: timestamp is String ? DateTime.tryParse(timestamp) : null,
      timeLabel: _messagingString(json['time_label']),
      dayLabel: _messagingString(json['day_label']),
      sender: MobileMessageParticipant.fromJson(json['sender']),
      receiptLabel: receiptLabel,
      attachments: List.unmodifiable(
        rawAttachments.map(MobileMessageAttachment.fromJson),
      ),
    );
  }
}

class MobileMessagePage {
  const MobileMessagePage({
    required this.conversation,
    required this.messages,
    required this.hasMore,
    required this.nextBeforeId,
  });

  final MobileConversation conversation;
  final List<MobileChatMessage> messages;
  final bool hasMore;
  final int? nextBeforeId;

  factory MobileMessagePage.fromJson(Object? value) {
    final data = _messagingEnvelope(value);
    final rawMessages = data['messages'];
    if (rawMessages is! List) {
      throw const MobileMessagingFormatException('data.messages');
    }
    final pagination = _messagingMap(data['pagination'], 'data.pagination');
    final next = pagination['next_before_id'];
    return MobileMessagePage(
      conversation: MobileConversation.fromJson(data['conversation']),
      messages: List.unmodifiable(rawMessages.map(MobileChatMessage.fromJson)),
      hasMore: pagination['has_more'] == true,
      nextBeforeId: next == null ? null : _messagingInt(next),
    );
  }
}

class MobileAttachmentContent {
  const MobileAttachmentContent({required this.bytes, required this.mimeType});

  final List<int> bytes;
  final String mimeType;
}

class MobileMessagingFormatException implements Exception {
  const MobileMessagingFormatException(this.field);

  final String field;

  @override
  String toString() => 'Invalid messaging response field: $field';
}

Map<String, Object?> _messagingEnvelope(Object? value) {
  final root = _messagingMap(value, 'response');
  return _messagingMap(root['data'], 'data');
}

Map<String, Object?> _messagingMap(Object? value, String field) {
  if (value is! Map) throw MobileMessagingFormatException(field);
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

int _messagingInt(Object? value) {
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ??
        (throw const MobileMessagingFormatException('integer'));
  }
  throw const MobileMessagingFormatException('integer');
}

String _messagingString(Object? value) => value is String ? value : '';
