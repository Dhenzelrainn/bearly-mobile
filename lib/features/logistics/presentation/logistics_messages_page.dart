import 'package:flutter/material.dart';

import '../../messaging/presentation/mobile_messages_page.dart';
import '../data/logistics_messages_repository.dart';

class LogisticsMessagesPage extends StatelessWidget {
  const LogisticsMessagesPage({super.key, required this.repository});

  final LogisticsMessagesRepository repository;

  @override
  Widget build(BuildContext context) => MobileMessagesPage(
    repository: repository,
    initiationRepository: repository,
    title: 'Messages',
  );
}
