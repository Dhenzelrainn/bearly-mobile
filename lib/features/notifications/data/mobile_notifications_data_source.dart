import '../models/mobile_notification.dart';

/// Contract shared by role-scoped Mobile notification repositories.
/// Each implementation supplies a fixed endpoint namespace; the server still
/// enforces the account role and scopes records to the authenticated user.
abstract interface class MobileNotificationsDataSource {
  Future<MobileNotificationPage> getNotifications({
    int page = 1,
    int perPage = 15,
  });

  Future<int> getUnreadCount();
  Future<int> markRead(String notificationId);
  Future<int> markAllRead();
}
