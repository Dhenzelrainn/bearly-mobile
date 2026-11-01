class BuyerChatConversation {
  const BuyerChatConversation({
    required this.id,
    required this.title,
    required this.preview,
    required this.timeLabel,
    required this.context,
    required this.unread,
    required this.status,
  });

  final int id;
  final String title;
  final String preview;
  final String timeLabel;
  final String context;
  final int unread;
  final String status;

  factory BuyerChatConversation.fromJson(Object? value) {
    final json = _chatMap(value, 'conversation');
    final id = _chatInt(json['id'], 'conversation.id');
    final unread = _chatInt(json['unread'], 'conversation.unread');
    if (id < 1 || unread < 0) {
      throw const BuyerChatFormatException('conversation');
    }
    return BuyerChatConversation(
      id: id,
      title: _chatString(json['title'], 'conversation.title'),
      preview: _chatString(json['preview'], 'conversation.preview'),
      timeLabel: _chatString(json['time_label'], 'conversation.time_label'),
      context: _chatString(json['context'], 'conversation.context'),
      unread: unread,
      status: _chatString(json['status'], 'conversation.status'),
    );
  }
}

class BuyerChatThread {
  const BuyerChatThread({
    required this.id,
    required this.title,
    required this.context,
    required this.status,
    required this.messages,
  });

  final int id;
  final String title;
  final String context;
  final String status;
  final List<BuyerChatMessage> messages;

  factory BuyerChatThread.fromJson(Object? value) {
    final json = _chatMap(value, 'thread');
    final conversation = _chatMap(json['conversation'], 'thread.conversation');
    final rawMessages = json['messages'];
    if (rawMessages is! List) {
      throw const BuyerChatFormatException('thread.messages');
    }
    final id = _chatInt(conversation['id'], 'thread.conversation.id');
    if (id < 1) throw const BuyerChatFormatException('thread.conversation.id');
    return BuyerChatThread(
      id: id,
      title: _chatString(conversation['title'], 'thread.conversation.title'),
      context: _chatString(
        conversation['context'],
        'thread.conversation.context',
      ),
      status: _chatString(conversation['status'], 'thread.conversation.status'),
      messages: List.unmodifiable(rawMessages.map(BuyerChatMessage.fromJson)),
    );
  }
}

class BuyerChatMessage {
  const BuyerChatMessage({
    required this.id,
    required this.isMine,
    required this.text,
    required this.sentAt,
    required this.timeLabel,
    required this.dayLabel,
    required this.attachmentNames,
  });

  final int id;
  final bool isMine;
  final String text;
  final DateTime? sentAt;
  final String timeLabel;
  final String dayLabel;
  final List<String> attachmentNames;

  factory BuyerChatMessage.fromJson(Object? value) {
    final json = _chatMap(value, 'message');
    final id = _chatInt(json['id'], 'message.id');
    final from = json['from'];
    final rawAttachments = json['attachments'];
    if (id < 1 || (from != 'me' && from != 'them') || rawAttachments is! List) {
      throw const BuyerChatFormatException('message');
    }
    final timestamp = json['sent_at'];
    final sentAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
    return BuyerChatMessage(
      id: id,
      isMine: from == 'me',
      text: _chatString(json['text'], 'message.text'),
      sentAt: sentAt,
      timeLabel: _chatString(json['time_label'], 'message.time_label'),
      dayLabel: _chatString(json['day_label'], 'message.day_label'),
      attachmentNames: List.unmodifiable(
        rawAttachments.map((attachment) {
          final row = _chatMap(attachment, 'message.attachment');
          return _chatString(row['name'], 'message.attachment.name');
        }),
      ),
    );
  }
}

class BuyerChatFormatException implements Exception {
  const BuyerChatFormatException(this.field);

  final String field;

  @override
  String toString() => 'Invalid chat response field: $field';
}

Map<String, Object?> _chatMap(Object? value, String field) {
  if (value is! Map) throw BuyerChatFormatException(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw BuyerChatFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

int _chatInt(Object? value, String field) {
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? (throw BuyerChatFormatException(field));
  }
  throw BuyerChatFormatException(field);
}

String _chatString(Object? value, String field) {
  if (value is String) return value;
  throw BuyerChatFormatException(field);
}
