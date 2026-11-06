import 'dart:async';

import 'package:bearly_mobile/features/messaging/presentation/mobile_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'messaging_test_fixtures.dart';

void main() {
  testWidgets('shows loading, empty, and retryable error states', (
    tester,
  ) async {
    final pending = FakeMobileMessagingDataSource()
      ..inboxCompleter = Completer();
    await tester.pumpWidget(
      MaterialApp(home: MobileMessagesPage(repository: pending)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.inboxCompleter!.complete(
      testInbox(conversations: const [], unreadCount: 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final failing = FakeMobileMessagingDataSource(failInboxOnce: true);
    await tester.pumpWidget(
      MaterialApp(home: MobileMessagesPage(repository: failing)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Messages unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Use the north gate.'), findsOneWidget);
  });

  testWidgets('opens a thread, marks it read, and sends a reply', (
    tester,
  ) async {
    final repository = FakeMobileMessagingDataSource();
    await tester.pumpWidget(
      MaterialApp(home: MobileMessagesPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsNWidgets(2));
    await tester.tap(find.text('Bearly Support').first);
    await tester.pumpAndSettle();
    expect(find.text('Use the north gate.'), findsOneWidget);
    expect(repository.readRequests, 1);

    await tester.enterText(
      find.byKey(const ValueKey('mobile-message-composer')),
      'I am on my way.',
    );
    await tester.tap(find.byKey(const ValueKey('mobile-message-send')));
    await tester.pumpAndSettle();
    expect(repository.sendRequests, 1);
    expect(find.text('I am on my way.'), findsOneWidget);
    expect(repository.readRequests, 2);
  });

  testWidgets('shows refresh errors while keeping the inbox visible', (
    tester,
  ) async {
    final repository = FakeMobileMessagingDataSource();
    await tester.pumpWidget(
      MaterialApp(home: MobileMessagesPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    repository.failInboxOnce = true;
    await tester.tap(find.byKey(const ValueKey('mobile-messages-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('Could not refresh messages'), findsOneWidget);
    expect(find.text('Bearly Support'), findsWidgets);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not refresh messages'), findsNothing);
  });

  testWidgets('loads older thread messages from the cursor control', (
    tester,
  ) async {
    final repository = FakeMobileMessagingDataSource()..pendingPage = 2;
    await tester.pumpWidget(
      MaterialApp(home: MobileMessagesPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearly Support').first);
    await tester.pumpAndSettle();

    expect(find.text('Load earlier messages'), findsOneWidget);
    await tester.tap(find.text('Load earlier messages'));
    await tester.pumpAndSettle();
    expect(repository.threadRequests, 2);
  });

  testWidgets('conversation error state retries successfully', (tester) async {
    final repository = FakeMobileMessagingDataSource()..failThreadOnce = true;
    await tester.pumpWidget(
      MaterialApp(home: MobileMessagesPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearly Support').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not load this conversation'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Use the north gate.'), findsOneWidget);
  });

  testWidgets('loads another inbox page from the pagination control', (
    tester,
  ) async {
    final conversations = [
      for (var id = 1; id <= 12; id++) testConversation(id: id, unread: 0),
    ];
    final repository = FakeMobileMessagingDataSource(
      conversations: conversations,
    )..pendingPage = 2;
    await tester.pumpWidget(
      MaterialApp(home: MobileMessagesPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(repository.inboxRequests, 2);
    expect(find.text('Bearly Support'), findsWidgets);
  });

  testWidgets('starts a conversation with a server-authorized contact', (
    tester,
  ) async {
    final repository = FakeMobileMessagingDataSource();
    final initiation = FakeMobileMessagingInitiationDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: MobileMessagesPage(
          repository: repository,
          initiationRepository: initiation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('mobile-messages-new-conversation')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New conversation'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mobile-message-recipient')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dispatch Admin · Administrator').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mobile-message-subject')),
      'Pickup coordination',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mobile-message-first-message')),
      'Please confirm the pickup window.',
    );
    await tester.tap(find.byKey(const ValueKey('mobile-message-start')));
    await tester.pumpAndSettle();

    expect(initiation.startRequests, 1);
    expect(initiation.lastRecipientId, 83);
    expect(initiation.lastSubject, 'Pickup coordination');
    expect(initiation.lastMessage, 'Please confirm the pickup window.');
    expect(find.text('Use the north gate.'), findsOneWidget);
  });
}
