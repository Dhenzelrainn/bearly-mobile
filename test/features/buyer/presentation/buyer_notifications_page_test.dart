import 'package:bearly_mobile/features/buyer/presentation/buyer_notifications_page.dart';
import 'package:bearly_mobile/features/notifications/data/mobile_notifications_data_source.dart';
import 'package:bearly_mobile/features/notifications/models/mobile_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows notifications and updates read state and unread count', (
    tester,
  ) async {
    final repository = _FakeNotifications();
    await tester.pumpWidget(
      MaterialApp(home: BuyerNotificationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order packed'), findsOneWidget);
    expect(find.text('Your order is ready for dispatch.'), findsOneWidget);
    expect(find.text('Voucher received'), findsOneWidget);
    expect(find.byTooltip('Mark all as read'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark as read').first);
    await tester.pumpAndSettle();
    expect(repository.unreadCount, 1);
    expect(find.byTooltip('Mark as read'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();
    expect(repository.unreadCount, 0);
    expect(find.byTooltip('Mark all as read'), findsNothing);
    expect(find.byTooltip('Mark as read'), findsNothing);
  });

  testWidgets('shows empty state and refreshes the notification list', (
    tester,
  ) async {
    final repository = _FakeNotifications(items: const []);
    await tester.pumpWidget(
      MaterialApp(home: BuyerNotificationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repository.listRequests, 2);
  });

  testWidgets('shows a retry state when the first request fails', (
    tester,
  ) async {
    final repository = _FakeNotifications(failNextListRequest: true);
    await tester.pumpWidget(
      MaterialApp(home: BuyerNotificationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Order packed'), findsOneWidget);
  });
}

class _FakeNotifications implements MobileNotificationsDataSource {
  _FakeNotifications({
    List<MobileNotification>? items,
    this.failNextListRequest = false,
  }) : _items =
           items ??
           [
             _unreadNotification(),
             _secondUnreadNotification(),
             _readNotification(),
           ];

  List<MobileNotification> _items;
  bool failNextListRequest;
  int listRequests = 0;
  int unreadCount = 2;

  @override
  Future<MobileNotificationPage> getNotifications({
    int page = 1,
    int perPage = 15,
  }) async {
    listRequests++;
    if (failNextListRequest) {
      failNextListRequest = false;
      throw StateError('network unavailable');
    }
    return MobileNotificationPage(
      items: List.unmodifiable(_items),
      unreadCount: unreadCount,
      currentPage: page,
      lastPage: 1,
      total: _items.length,
    );
  }

  @override
  Future<int> getUnreadCount() async => unreadCount;

  @override
  Future<int> markRead(String notificationId) async {
    _items = [
      for (final item in _items)
        if (item.id == notificationId && !item.read)
          item.copyWith(read: true)
        else
          item,
    ];
    unreadCount--;
    return unreadCount;
  }

  @override
  Future<int> markAllRead() async {
    _items = _items.map((item) => item.copyWith(read: true)).toList();
    unreadCount = 0;
    return unreadCount;
  }
}

MobileNotification _unreadNotification() => MobileNotification(
  id: 'order-1',
  title: 'Order packed',
  body: 'Your order is ready for dispatch.',
  read: false,
  createdAt: DateTime(2026, 11, 6, 10),
);

MobileNotification _readNotification() => MobileNotification(
  id: 'voucher-1',
  title: 'Voucher received',
  body: 'A voucher was added to your account.',
  read: true,
  createdAt: DateTime(2026, 11, 5, 9),
);

MobileNotification _secondUnreadNotification() => MobileNotification(
  id: 'shipment-1',
  title: 'Shipment update',
  body: 'Your parcel is moving to the next facility.',
  read: false,
  createdAt: DateTime(2026, 11, 6, 8),
);
