import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/mobile_messaging_data_source.dart';
import '../models/mobile_messaging_models.dart';
import 'mobile_message_new_conversation_page.dart';
import 'mobile_message_conversation_page.dart';

class MobileMessagesPage extends StatefulWidget {
  const MobileMessagesPage({
    super.key,
    required this.repository,
    this.title = 'Messages',
    this.initiationRepository,
  });

  final MobileMessagingDataSource repository;
  final String title;
  final MobileMessagingInitiationDataSource? initiationRepository;

  @override
  State<MobileMessagesPage> createState() => _MobileMessagesPageState();
}

class _MobileMessagesPageState extends State<MobileMessagesPage> {
  final _scrollController = ScrollController();
  List<MobileConversation> _conversations = const [];
  int _unreadCount = 0;
  int? _nextPage;
  bool _loading = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  String? _error;
  String? _paginationError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkPagination);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_checkPagination)
      ..dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading && !refresh) return;
    if (refresh) {
      setState(() {
        _refreshing = true;
        _paginationError = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final inbox = await widget.repository.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = inbox.conversations;
        _unreadCount = inbox.unreadCount;
        _nextPage = inbox.nextPage;
        _error = null;
        _paginationError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not load messages. Check your connection and retry.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _checkPagination() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 180) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadNextPage() async {
    final page = _nextPage;
    if (page == null || _loading || _refreshing || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _paginationError = null;
    });
    try {
      final inbox = await widget.repository.getConversations(page: page);
      if (!mounted) return;
      final seen = _conversations
          .map((conversation) => conversation.id)
          .toSet();
      setState(() {
        _conversations = [
          ..._conversations,
          ...inbox.conversations.where(
            (conversation) => !seen.contains(conversation.id),
          ),
        ];
        _unreadCount = inbox.unreadCount;
        _nextPage = inbox.nextPage;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _paginationError = 'Could not load more conversations.');
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openConversation(MobileConversation conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MobileMessageConversationPage(
          repository: widget.repository,
          conversation: conversation,
        ),
      ),
    );
    if (mounted) {
      await _load(refresh: true);
    }
  }

  Future<void> _startConversation() async {
    final initiation = widget.initiationRepository;
    if (initiation == null) return;
    final conversation = await Navigator.of(context).push<MobileConversation>(
      MaterialPageRoute<MobileConversation>(
        builder: (_) =>
            MobileMessageNewConversationPage(repository: initiation),
      ),
    );
    if (conversation == null || !mounted) return;
    await _load(refresh: true);
    if (mounted) await _openConversation(conversation);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 10),
            Badge(
              label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
              child: const Icon(Icons.mark_chat_unread_rounded, size: 20),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.initiationRepository != null)
          IconButton(
            key: const ValueKey('mobile-messages-new-conversation'),
            tooltip: 'New conversation',
            onPressed: _startConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        IconButton(
          key: const ValueKey('mobile-messages-refresh'),
          tooltip: 'Refresh messages',
          onPressed: _loading || _refreshing
              ? null
              : () => _load(refresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: _body(),
    ),
  );

  Widget _body() {
    if (_loading && _conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 300,
            child: _NoticeState(
              icon: Icons.cloud_off_outlined,
              title: _conversations.isEmpty
                  ? 'Messages unavailable'
                  : 'Could not refresh messages',
              message: _error!,
              actionLabel: 'Retry',
              onAction: () => _load(refresh: true),
            ),
          ),
          for (final conversation in _conversations)
            _conversationTile(conversation),
        ],
      );
    }
    if (_conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 145),
          Icon(Icons.forum_outlined, size: 48, color: BearlyColors.brown700),
          SizedBox(height: 14),
          Center(child: Text('No conversations yet')),
          SizedBox(height: 8),
          Center(child: Text('Your available messages will appear here.')),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount:
          _conversations.length +
          (_nextPage != null || _loadingMore || _paginationError != null
              ? 1
              : 0),
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        if (index >= _conversations.length) {
          if (_paginationError != null) {
            return TextButton(
              onPressed: _loadNextPage,
              child: Text('$_paginationError Tap to retry.'),
            );
          }
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_nextPage != null) {
            return TextButton(
              onPressed: _loadNextPage,
              child: const Text('Load more conversations'),
            );
          }
          return const SizedBox.shrink();
        }
        return _conversationTile(_conversations[index]);
      },
    );
  }

  Widget _conversationTile(MobileConversation conversation) => ListTile(
    onTap: () => _openConversation(conversation),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    leading: CircleAvatar(
      backgroundColor: BearlyColors.gold.withValues(alpha: .24),
      foregroundColor: BearlyColors.brown950,
      child: Text(_initials(conversation.title)),
    ),
    title: Text(
      conversation.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conversation.participantSubtitle.isNotEmpty)
            Text(
              conversation.participantSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BearlyColors.brown700),
            ),
          if (conversation.subject.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              conversation.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 2),
          Text(
            conversation.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
    trailing: SizedBox(
      width: 78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (conversation.lastMessageAt != null)
            Text(
              _dateLabel(conversation.lastMessageAt!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (conversation.unread > 0) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: BearlyColors.gold,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                conversation.unread > 99 ? '99+' : '${conversation.unread}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BearlyColors.brown950,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    return material.formatMediumDate(local);
  }

  String _initials(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word.characters.first.toUpperCase())
      .join();
}

class _NoticeState extends StatelessWidget {
  const _NoticeState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
