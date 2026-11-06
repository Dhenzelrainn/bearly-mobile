import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mobile_notifications_data_source.dart';
import '../models/mobile_notification.dart';

class MobileNotificationsPage extends StatefulWidget {
  const MobileNotificationsPage({
    super.key,
    required this.repository,
    this.title = 'Notifications',
    this.initialUnreadCount = 0,
  });

  final MobileNotificationsDataSource repository;
  final String title;
  final int initialUnreadCount;

  @override
  State<MobileNotificationsPage> createState() =>
      _MobileNotificationsPageState();
}

class _MobileNotificationsPageState extends State<MobileNotificationsPage> {
  final _scrollController = ScrollController();
  List<MobileNotification> _items = const [];
  int _unreadCount = 0;
  int? _nextPage;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _markingAll = false;
  String? _error;
  String? _paginationError;
  Future<void>? _firstRequest;

  @override
  void initState() {
    super.initState();
    _unreadCount = widget.initialUnreadCount;
    _scrollController.addListener(_checkPagination);
    _firstRequest = _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_checkPagination)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage({bool refresh = false}) async {
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
      final result = await widget.repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _unreadCount = result.unreadCount;
        _nextPage = result.nextPage;
        _error = null;
        _paginationError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not load notifications. Check your connection and retry.';
      });
      if (refresh && _items.isNotEmpty) _showMessage(_error!);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
      _firstRequest = null;
    }
  }

  Future<void> _refresh() async {
    final pending = _firstRequest;
    if (pending != null) {
      await pending;
      return;
    }
    await _loadFirstPage(refresh: true);
  }

  void _checkPagination() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 220) {
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
      final result = await widget.repository.getNotifications(page: page);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _unreadCount = result.unreadCount;
        _nextPage = result.nextPage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _paginationError = 'Could not load more notifications.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markRead(MobileNotification item) async {
    if (item.read) return;
    try {
      final count = await widget.repository.markRead(item.id);
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
        _items = [
          for (final current in _items)
            if (current.id == item.id)
              current.copyWith(read: true)
            else
              current,
        ];
      });
    } catch (_) {
      if (mounted) _showMessage('Could not mark this notification as read.');
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0 || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      final count = await widget.repository.markAllRead();
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
        _items = _items.map((item) => item.copyWith(read: true)).toList();
      });
    } catch (_) {
      if (mounted) _showMessage('Could not mark notifications as read.');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  String _dateLabel(BuildContext context, MobileNotification item) {
    final date = item.createdAt;
    if (date == null) return item.createdAtHuman ?? '';
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '${material.formatMediumDate(local)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop<int>(_unreadCount),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(widget.title),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: _markingAll ? null : _markAllRead,
              icon: _markingAll
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_read_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _itemCount,
          itemBuilder: (context, index) {
            if (_loading && _items.isEmpty) {
              return const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null && _items.isEmpty) {
              return SizedBox(
                height: 300,
                child: _NoticeState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Notifications unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              );
            }
            if (_items.isEmpty) {
              return const SizedBox(
                height: 300,
                child: _NoticeState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message:
                      'Updates about your Bearly activity will appear here.',
                ),
              );
            }
            if (index >= _items.length) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_paginationError != null) {
                return TextButton(
                  onPressed: _loadNextPage,
                  child: Text('$_paginationError Tap to retry.'),
                );
              }
              return const SizedBox.shrink();
            }

            final item = _items[index];
            return _NotificationTile(
              notification: item,
              dateLabel: _dateLabel(context, item),
              onTap: () => _markRead(item),
              onMarkRead: item.read ? null : () => _markRead(item),
            );
          },
        ),
      ),
    );
  }

  int get _itemCount {
    if (_loading && _items.isEmpty) return 1;
    if (_error != null && _items.isEmpty) return 1;
    if (_items.isEmpty) return 1;
    return _items.length +
        (_nextPage != null || _loadingMore || _paginationError != null ? 1 : 0);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.dateLabel,
    required this.onTap,
    required this.onMarkRead,
  });

  final MobileNotification notification;
  final String dateLabel;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: notification.read
          ? null
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          notification.read
              ? Icons.notifications_none_rounded
              : Icons.notifications_active_rounded,
          color: notification.read
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
        ),
        title: Text(
          notification.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.body.isNotEmpty) Text(notification.body),
              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(dateLabel, style: theme.textTheme.labelSmall),
              ],
            ],
          ),
        ),
        trailing: onMarkRead == null
            ? null
            : IconButton(
                tooltip: 'Mark as read',
                onPressed: onMarkRead,
                icon: const Icon(Icons.mark_email_read_outlined),
              ),
        isThreeLine: notification.body.isNotEmpty && dateLabel.isNotEmpty,
      ),
    );
  }
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
