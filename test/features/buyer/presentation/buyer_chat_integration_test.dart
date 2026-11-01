import 'dart:async';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_chat_repository.dart';
import 'package:bearly_mobile/features/buyer/models/buyer_chat_models.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_chat_thread_page.dart';
import 'package:bearly_mobile/features/buyer/presentation/buyer_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Buyer messages', () {
    testWidgets('conversation list loads empty and error states', (
      tester,
    ) async {
      final pending = Completer<List<BuyerChatConversation>>();
      final loading = _FakeChatDataSource()
        ..onConversations = () => pending.future;

      await tester.pumpWidget(
        _app(
          BuyerMessagesPage(
            repository: loading,
            onOpenConversation: (_) async {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('No conversations yet'), findsOneWidget);

      loading.onConversations = () async => throw const ApiTransportException();
      await tester.tap(find.byKey(const ValueKey('buyer-messages-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Messages could not be loaded.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets(
      'conversation list shows Seller preview, time, and unread count',
      (tester) async {
        final source = _FakeChatDataSource()
          ..conversations = [
            _conversation(
              id: 8,
              title: 'Sundays Market',
              preview: 'Your order is ready for pickup.',
              unread: 2,
            ),
          ];
        var opened = 0;
        await tester.pumpWidget(
          _app(
            BuyerMessagesPage(
              repository: source,
              onOpenConversation: (id) async => opened = id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sundays Market'), findsOneWidget);
        expect(find.text('Your order is ready for pickup.'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        await tester.tap(find.text('Sundays Market'));
        await tester.pumpAndSettle();
        expect(opened, 8);
        expect(source.inboxRequests, 2);
      },
    );

    testWidgets(
      'thread aligns participants and prevents duplicate taps while sending',
      (tester) async {
        final response = Completer<BuyerChatMessage>();
        final source = _FakeChatDataSource();
        source.onMessages = (_, _) async => _thread([
          _message(1, mine: false, text: 'Hello from Seller'),
          _message(2, mine: true, text: 'Hello from Buyer'),
        ]);
        source.onSend = (_, _) => response.future;

        await tester.pumpWidget(
          _app(BuyerChatThreadPage(repository: source, conversationId: 4)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hello from Seller'), findsOneWidget);
        expect(find.text('Hello from Buyer'), findsOneWidget);
        expect(source.readCount, 1);

        await tester.enterText(
          find.byKey(const ValueKey('buyer-chat-composer')),
          'Question about this product',
        );
        await tester.tap(find.byKey(const ValueKey('buyer-chat-send')));
        await tester.pump();
        expect(source.sendCount, 1);
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('buyer-chat-send')))
              .onPressed,
          isNull,
        );
        response.complete(
          _message(3, mine: true, text: 'Question about this product'),
        );
        await tester.pumpAndSettle();
        expect(source.sendCount, 1);
        expect(find.text('Message sent.'), findsOneWidget);
        expect(find.text('Question about this product'), findsOneWidget);
      },
    );

    testWidgets('uncertain send is reconciled from the server without replay', (
      tester,
    ) async {
      var reads = 0;
      final source = _FakeChatDataSource()
        ..onMessages = (_, _) async {
          reads++;
          return _thread([
            _message(1, mine: true, text: 'Earlier buyer note'),
            if (reads > 1)
              _message(2, mine: true, text: 'Sent before the timeout'),
          ]);
        }
        ..onSend = (_, _) async =>
            throw const ApiTimeoutException(Duration(seconds: 30));

      await tester.pumpWidget(
        _app(BuyerChatThreadPage(repository: source, conversationId: 4)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('buyer-chat-composer')),
        'Sent before the timeout',
      );
      await tester.tap(find.byKey(const ValueKey('buyer-chat-send')));
      await tester.pumpAndSettle();

      expect(source.sendCount, 1);
      expect(
        find.text('The server confirms your message is in this conversation.'),
        findsOneWidget,
      );
      expect(find.text('Sent before the timeout'), findsOneWidget);
      expect(find.text('Send again'), findsNothing);
    });

    testWidgets(
      'uncertain send requires refresh and explicit confirmation before another POST',
      (tester) async {
        var attempts = 0;
        final source = _FakeChatDataSource();
        source.onMessages = (_, _) async => _thread(const []);
        source.onSend = (_, _) async {
          attempts++;
          if (attempts == 1) {
            throw const ApiTimeoutException(Duration(seconds: 30));
          }
          return _message(1, mine: true, text: 'Please confirm availability');
        };

        await tester.pumpWidget(
          _app(BuyerChatThreadPage(repository: source, conversationId: 5)),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('buyer-chat-composer')),
          'Please confirm availability',
        );
        await tester.tap(find.byKey(const ValueKey('buyer-chat-send')));
        await tester.pumpAndSettle();
        expect(source.sendCount, 1);
        expect(find.text('Send again'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('buyer-chat-refresh')));
        await tester.pumpAndSettle();
        expect(find.text('Send again'), findsOneWidget);
        expect(source.sendCount, 1);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Send again'));
        await tester.pumpAndSettle();
        expect(find.text('Send this message again?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Send again'));
        await tester.pumpAndSettle();
        expect(source.sendCount, 2);
        expect(find.text('Please confirm availability'), findsOneWidget);
      },
    );

    testWidgets(
      'long text wraps on a narrow screen with increased text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final longText = List.filled(35, 'Long message text').join(' ');
        final source = _FakeChatDataSource()
          ..onMessages = (_, _) async =>
              _thread([_message(1, mine: false, text: longText)]);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: BuyerChatThreadPage(repository: source, conversationId: 4),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(longText), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Widget _app(Widget child) => MaterialApp(home: child);

BuyerChatConversation _conversation({
  int id = 4,
  String title = 'Bearly Store',
  String preview = 'Latest message',
  int unread = 0,
}) => BuyerChatConversation(
  id: id,
  title: title,
  preview: preview,
  timeLabel: '9:15 AM',
  context: 'Product question',
  unread: unread,
  status: 'open',
);

BuyerChatThread _thread(List<BuyerChatMessage> messages) => BuyerChatThread(
  id: 4,
  title: 'Bearly Store',
  context: 'Product question',
  status: 'open',
  messages: messages,
);

BuyerChatMessage _message(int id, {required bool mine, required String text}) =>
    BuyerChatMessage(
      id: id,
      isMine: mine,
      text: text,
      sentAt: DateTime.utc(2026, 11, 1, 1, id),
      timeLabel: '9:0$id AM',
      dayLabel: 'Today',
      attachmentNames: const [],
    );

class _FakeChatDataSource implements BuyerChatDataSource {
  List<BuyerChatConversation> conversations = const [];
  Future<List<BuyerChatConversation>> Function()? onConversations;
  Future<BuyerChatThread> Function(int, int?)? onMessages;
  Future<BuyerChatMessage> Function(int, String)? onSend;
  int inboxRequests = 0;
  int sendCount = 0;
  int readCount = 0;

  @override
  Future<List<BuyerChatConversation>> getConversations() async {
    inboxRequests++;
    return onConversations == null ? conversations : onConversations!();
  }

  @override
  Future<int> startProductConversation(int productId) async => 17;

  @override
  Future<BuyerChatThread> getMessages(
    int conversationId, {
    int? afterId,
  }) async {
    if (onMessages == null) return _thread(const []);
    return onMessages!(conversationId, afterId);
  }

  @override
  Future<BuyerChatMessage> sendMessage(
    int conversationId,
    String message,
  ) async {
    sendCount++;
    if (onSend != null) return onSend!(conversationId, message);
    return _message(sendCount, mine: true, text: message);
  }

  @override
  Future<void> markRead(int conversationId) async {
    readCount++;
  }
}
