import 'package:flutter/material.dart';

import '../../notifications/data/mobile_notifications_data_source.dart';
import '../../notifications/presentation/mobile_notifications_page.dart';

/// Buyer entry point for the shared role-scoped Mobile notification screen.
class BuyerNotificationsPage extends StatelessWidget {
  const BuyerNotificationsPage({
    super.key,
    required this.repository,
    this.initialUnreadCount = 0,
  });

  final MobileNotificationsDataSource repository;
  final int initialUnreadCount;

  @override
  Widget build(BuildContext context) => MobileNotificationsPage(
    repository: repository,
    initialUnreadCount: initialUnreadCount,
  );
}
