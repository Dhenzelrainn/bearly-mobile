import '../../auth/data/auth_service.dart';
import '../../notifications/data/mobile_notifications_data_source.dart';
import '../../notifications/models/mobile_notification.dart';

/// Rider/Courier access to Laravel's role-scoped notification records.
class RiderNotificationsRepository implements MobileNotificationsDataSource {
  RiderNotificationsRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  @override
  Future<MobileNotificationPage> getNotifications({
    int page = 1,
    int perPage = 15,
  }) async {
    if (page < 1) throw RangeError.value(page, 'page', 'Must be positive.');
    if (perPage < 1 || perPage > 50) {
      throw RangeError.value(perPage, 'perPage', 'Must be between 1 and 50.');
    }

    final response = await _authService.getWithSession(
      '/api/mobile/rider/notifications',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return MobileNotificationPage.fromJson(response);
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _authService.getWithSession(
      '/api/mobile/rider/notifications/unread-count',
    );
    return _unreadCount(response);
  }

  @override
  Future<int> markRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        notificationId,
        'notificationId',
        'Must not be empty.',
      );
    }
    return _authService.requestWithSession<int>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/rider/notifications/${Uri.encodeComponent(id)}/read',
      parse: _unreadCount,
    );
  }

  @override
  Future<int> markAllRead() => _authService.requestWithSession<int>(
    method: AuthenticatedRequestMethod.post,
    path: '/api/mobile/rider/notifications/read-all',
    parse: _unreadCount,
  );
}

int _unreadCount(Object? value) {
  if (value is! Map || value['data'] is! Map) {
    throw const MobileNotificationsFormatException('data');
  }
  final data = value['data'] as Map;
  final count = data['unread_count'];
  if (count is int && count >= 0) return count;
  if (count is String) {
    final parsed = int.tryParse(count);
    if (parsed != null && parsed >= 0) return parsed;
  }
  throw const MobileNotificationsFormatException('data.unread_count');
}
