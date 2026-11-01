import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_chat_repository.dart';
import '../models/buyer_chat_models.dart';

class BuyerMessagesPage extends StatefulWidget {
  const BuyerMessagesPage({
    super.key,
    required this.repository,
    required this.onOpenConversation,
  });

  final BuyerChatDataSource repository;
  final Future<void> Function(int conversationId) onOpenConversation;

  @override
  State<BuyerMessagesPage> createState() => _BuyerMessagesPageState();
}

class _BuyerMessagesPageState extends State<BuyerMessagesPage> {
  List<BuyerChatConversation> _conversations = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversations = await widget.repository.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openConversation(int conversationId) async {
    await widget.onOpenConversation(conversationId);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            key: const ValueKey('buyer-messages-refresh'),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh messages',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _conversations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _conversations.isEmpty
          ? _errorState()
          : _conversations.isEmpty
          ? _emptyState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _conversations.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (context, index) =>
                    _conversationTile(_conversations[index]),
              ),
            ),
    );
  }

  Widget _conversationTile(BuyerChatConversation conversation) {
    return ListTile(
      onTap: () => _openConversation(conversation.id),
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
            Text(
              conversation.context,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BearlyColors.brown700),
            ),
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
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (conversation.timeLabel.isNotEmpty)
              Text(
                conversation.timeLabel,
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
  }

  Widget _emptyState() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 150),
        Icon(Icons.forum_outlined, size: 48, color: BearlyColors.brown700),
        SizedBox(height: 16),
        Center(child: Text('No conversations yet')),
        SizedBox(height: 8),
        Center(child: Text('Open a product and choose Chat Seller to start.')),
      ],
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          const Text('Messages could not be loaded.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  String _initials(String title) {
    final words = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
  }
}
