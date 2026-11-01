import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_chat_repository.dart';
import '../models/buyer_chat_models.dart';

class BuyerChatThreadPage extends StatefulWidget {
  const BuyerChatThreadPage({
    super.key,
    required this.repository,
    required this.conversationId,
  });

  final BuyerChatDataSource repository;
  final int conversationId;

  @override
  State<BuyerChatThreadPage> createState() => _BuyerChatThreadPageState();
}

class _BuyerChatThreadPageState extends State<BuyerChatThreadPage> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  List<BuyerChatMessage> _messages = const [];
  String _title = 'Conversation';
  String _context = '';
  String _status = 'open';
  Object? _error;
  Object? _refreshError;
  String? _messageError;
  String? _notice;
  String? _uncertainText;
  int? _uncertainAfterId;
  bool _allowExplicitRetry = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadThread(initial: true);
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _latestMessageId => _messages.isEmpty ? 0 : _messages.last.id;

  Future<void> _loadThread({bool initial = false, bool manual = false}) async {
    final reconcileText = _uncertainText;
    final afterId = initial
        ? null
        : reconcileText != null
        ? (_uncertainAfterId ?? 0)
        : _latestMessageId;
    setState(() {
      if (initial) _loading = true;
      _refreshing = !initial;
      _error = null;
      _refreshError = null;
    });
    try {
      final thread = await widget.repository.getMessages(
        widget.conversationId,
        afterId: afterId == null || afterId == 0 ? null : afterId,
      );
      if (!mounted) return;
      final merged = _mergeMessages(_messages, thread.messages);
      final matchingUncertain =
          reconcileText != null &&
          thread.messages.any(
            (message) =>
                message.id > (_uncertainAfterId ?? 0) &&
                message.isMine &&
                message.text == reconcileText,
          );
      setState(() {
        _messages = merged;
        _title = thread.title;
        _context = thread.context;
        _status = thread.status;
        _loading = false;
        _refreshing = false;
        if (matchingUncertain) {
          _uncertainText = null;
          _uncertainAfterId = null;
          _allowExplicitRetry = false;
          if (_composer.text.trim() == reconcileText) _composer.clear();
          _notice = 'The server confirms your message is in this conversation.';
          _messageError = null;
        } else if (reconcileText != null && manual) {
          _allowExplicitRetry = true;
          _messageError =
              'The message is not visible yet. Check again or choose Send again after reviewing this thread.';
        }
      });
      _scrollToLatest();
      try {
        await widget.repository.markRead(widget.conversationId);
      } catch (_) {
        // The thread remains readable; a later refresh can retry its receipt.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (_messages.isEmpty && initial) {
          _error = error;
        } else {
          _refreshError = error;
        }
      });
    }
  }

  List<BuyerChatMessage> _mergeMessages(
    List<BuyerChatMessage> current,
    List<BuyerChatMessage> incoming,
  ) {
    final byId = <int, BuyerChatMessage>{
      for (final message in current) message.id: message,
      for (final message in incoming) message.id: message,
    };
    final result = byId.values.toList()
      ..sort((a, b) {
        final time = (a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        return time != 0 ? time : a.id.compareTo(b.id);
      });
    return List.unmodifiable(result);
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    if (_sending || _uncertainText != null || _status != 'open') return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    await _submit(text);
  }

  Future<void> _submit(String text) async {
    final baseline = _latestMessageId;
    setState(() {
      _sending = true;
      _messageError = null;
      _notice = null;
    });
    try {
      final message = await widget.repository.sendMessage(
        widget.conversationId,
        text,
      );
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(_messages, [message]);
        if (_composer.text.trim() == text) _composer.clear();
        _sending = false;
        _messageError = null;
        _uncertainText = null;
        _uncertainAfterId = null;
        _allowExplicitRetry = false;
        _notice = 'Message sent.';
      });
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiHttpException && error.statusCode < 500) {
        setState(() {
          _sending = false;
          _messageError = _safeError(error);
        });
        return;
      }

      setState(() {
        _sending = false;
        _uncertainText = text;
        _uncertainAfterId = baseline;
        _allowExplicitRetry = false;
        _messageError =
            'The send result is uncertain. Checking the server conversation before another send.';
      });
      await _loadThread();
    }
  }

  Future<void> _sendAgainAfterReconciliation() async {
    if (!_allowExplicitRetry || _uncertainText == null || _sending) return;
    final text = _uncertainText!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send this message again?'),
        content: const Text(
          'A refreshed server thread did not show the message. Sending again creates a new message if the first request completes later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send again'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _uncertainText = null;
      _uncertainAfterId = null;
      _allowExplicitRetry = false;
      _messageError = null;
    });
    await _submit(text);
  }

  String _safeError(Object error) {
    if (error is ApiHttpException && error.validationErrors.isNotEmpty) {
      for (final messages in error.validationErrors.values) {
        if (messages.isNotEmpty) return messages.first;
      }
    }
    if (error is ApiHttpException && error.statusCode == 409) {
      return 'This conversation is closed and cannot receive messages.';
    }
    if (error is ApiHttpException && error.statusCode == 429) {
      return 'Too many messages were sent. Wait a moment and try again.';
    }
    return 'The message could not be sent. Review it and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_context.isNotEmpty)
              Text(
                _context,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('buyer-chat-refresh'),
            onPressed: _refreshing ? null : () => _loadThread(manual: true),
            tooltip: 'Refresh conversation',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_notice != null) _noticeBanner(_notice!, isError: false),
          if (_messageError != null)
            _noticeBanner(_messageError!, isError: true),
          if (_refreshError != null)
            _noticeBanner(
              'The conversation could not be refreshed. Check your connection and retry.',
              isError: true,
            ),
          if (_uncertainText != null && _allowExplicitRetry)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : _sendAgainAfterReconciliation,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send again'),
                ),
              ),
            ),
          Expanded(child: _threadBody()),
          _composerBar(),
        ],
      ),
    );
  }

  Widget _threadBody() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This conversation could not be loaded.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _loadThread(initial: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadThread(manual: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(Icons.waving_hand_outlined, size: 42),
            SizedBox(height: 12),
            Center(child: Text('Start the conversation with the Seller.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadThread(manual: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final showDay =
              index == 0 || _messages[index - 1].dayLabel != message.dayLabel;
          return Column(
            children: [
              if (showDay && message.dayLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    message.dayLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              _messageBubble(message),
            ],
          );
        },
      ),
    );
  }

  Widget _messageBubble(BuyerChatMessage message) {
    final background = message.isMine
        ? BearlyColors.brown950
        : BearlyColors.cream100;
    final foreground = message.isMine ? Colors.white : BearlyColors.brown950;
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  softWrap: true,
                  style: TextStyle(color: foreground),
                ),
              for (final name in message.attachmentNames)
                Padding(
                  padding: EdgeInsets.only(top: message.text.isEmpty ? 0 : 6),
                  child: Text(
                    'Attachment: $name (view in Buyer Web)',
                    style: TextStyle(
                      color: foreground,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (message.timeLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  message.timeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: .72),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _composerBar() {
    final closed = _status != 'open';
    final locked = _sending || _uncertainText != null || closed;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 4,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('buyer-chat-composer'),
                  controller: _composer,
                  enabled: !locked,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: closed
                        ? 'This conversation is closed'
                        : _uncertainText != null
                        ? 'Refresh to reconcile before sending'
                        : 'Write a message',
                    counterText: '',
                    filled: true,
                    fillColor: BearlyColors.cream100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const ValueKey('buyer-chat-send'),
                onPressed: locked ? null : _send,
                tooltip: _sending ? 'Sending message' : 'Send message',
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noticeBanner(String message, {required bool isError}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    color: isError ? const Color(0xFFFFE8E1) : const Color(0xFFE5F4E8),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: isError ? BearlyColors.error : BearlyColors.success,
      ),
    ),
  );
}
