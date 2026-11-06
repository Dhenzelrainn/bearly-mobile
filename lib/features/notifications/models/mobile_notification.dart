class MobileNotification {
  const MobileNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    this.event,
    this.category,
    this.type,
    this.url,
    this.createdAt,
    this.createdAtHuman,
  });

  final String id;
  final String title;
  final String body;
  final bool read;
  final String? event;
  final String? category;
  final String? type;
  final String? url;
  final DateTime? createdAt;
  final String? createdAtHuman;

  MobileNotification copyWith({bool? read}) => MobileNotification(
    id: id,
    title: title,
    body: body,
    read: read ?? this.read,
    event: event,
    category: category,
    type: type,
    url: url,
    createdAt: createdAt,
    createdAtHuman: createdAtHuman,
  );

  factory MobileNotification.fromJson(Object? value) {
    final json = _notificationMap(value, 'notification');
    final id = json['id'];
    final title = json['title'];
    final body = json['body'];
    final read = json['read'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        body is! String ||
        read is! bool) {
      throw const MobileNotificationsFormatException('data.items[].fields');
    }

    final createdAtValue = json['created_at'];
    final createdAt = createdAtValue is String
        ? DateTime.tryParse(createdAtValue)
        : null;

    return MobileNotification(
      id: id,
      title: title,
      body: body,
      read: read,
      event: _optionalString(json['event']),
      category: _optionalString(json['category']),
      type: _optionalString(json['type']),
      url: _optionalString(json['url']),
      createdAt: createdAt,
      createdAtHuman: _optionalString(json['created_at_human']),
    );
  }
}

class MobileNotificationPage {
  const MobileNotificationPage({
    required this.items,
    required this.unreadCount,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.nextPage,
  });

  final List<MobileNotification> items;
  final int unreadCount;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? nextPage;

  factory MobileNotificationPage.fromJson(Object? value) {
    final envelope = _notificationMap(value, 'response');
    final data = _notificationMap(envelope['data'], 'data');
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const MobileNotificationsFormatException('data.items');
    }

    return MobileNotificationPage(
      items: List.unmodifiable(rawItems.map(MobileNotification.fromJson)),
      unreadCount: _requiredInt(data['unread_count'], 'data.unread_count'),
      currentPage: _requiredInt(data['current_page'], 'data.current_page'),
      lastPage: _requiredInt(data['last_page'], 'data.last_page'),
      total: _requiredInt(data['total'], 'data.total'),
      nextPage: _optionalInt(data['next_page']),
    );
  }
}

class MobileNotificationsFormatException implements Exception {
  const MobileNotificationsFormatException(this.field);

  final String field;

  @override
  String toString() => 'Bearly returned invalid notification data ($field).';
}

Map<String, Object?> _notificationMap(Object? value, String field) {
  if (value is! Map) throw MobileNotificationsFormatException(field);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw MobileNotificationsFormatException(field);
    result[entry.key as String] = entry.value;
  }
  return result;
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int _requiredInt(Object? value, String field) {
  final parsed = _optionalInt(value);
  if (parsed == null || parsed < 0) {
    throw MobileNotificationsFormatException(field);
  }
  return parsed;
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
