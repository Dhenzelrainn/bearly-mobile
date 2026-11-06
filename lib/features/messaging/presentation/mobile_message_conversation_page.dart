import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/mobile_messaging_data_source.dart';
import '../models/mobile_messaging_models.dart';

class MobileMessageConversationPage extends StatefulWidget {
  const MobileMessageConversationPage({
    super.key,
    required this.repository,
    required this.conversation,
  });

  final MobileMessagingDataSource repository;
  final MobileConversation conversation;

  @override
  State<MobileMessageConversationPage> createState() =>
      _MobileMessageConversationPageState();
}

class _MobileMessageConversationPageState
    extends State<MobileMessageConversationPage> {
  static const _maxMessageLength = 5000;
  static const _maxAttachmentBytes = 10 * 1024 * 1024;
  static const _allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'mp4',
    'mov',
    'webm',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
    'csv',
    'zip',
  ];

  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  List<MobileChatMessage> _messages = const [];
  PlatformFile? _attachment;
  int? _nextBeforeId;
  bool _hasMore = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _pickingAttachment = false;
  int? _unreadCount;
  String? _loadError;
  String? _sendError;
  _UncertainDraft? _uncertainDraft;

  bool get _isOpen => widget.conversation.status == 'open';

  int get _latestMessageId => _messages.isEmpty ? 0 : _messages.last.id;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final page = await widget.repository.getMessages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = page.messages;
        _hasMore = page.hasMore;
        _nextBeforeId = page.nextBeforeId;
        _loading = false;
        _loadError = null;
      });
      _scrollToLatest();
      await _markRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Could not load this conversation. Check your connection and retry.';
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMore || _loadingOlder) return;
    if (_scrollController.position.extentBefore < 70 &&
        _scrollController.position.maxScrollExtent > 0) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    final beforeId = _nextBeforeId;
    if (beforeId == null || _loadingOlder) return;
    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    setState(() => _loadingOlder = true);
    try {
      final page = await widget.repository.getMessages(
        widget.conversation.id,
        beforeId: beforeId,
      );
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(page.messages, _messages);
        _hasMore = page.hasMore;
        _nextBeforeId = page.nextBeforeId;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final addedExtent =
              _scrollController.position.maxScrollExtent - oldExtent;
          _scrollController.jumpTo(
            (oldOffset + addedExtent).clamp(
              0,
              _scrollController.position.maxScrollExtent,
            ),
          );
        }
      });
    } catch (_) {
      if (mounted) _showMessage('Could not load earlier messages. Try again.');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _loadError = null;
    });
    try {
      final page = await widget.repository.getMessages(widget.conversation.id);
      if (!mounted) return;
      final draft = _uncertainDraft;
      final confirmed =
          draft != null &&
          page.messages.any(
            (message) =>
                message.id > draft.afterId &&
                message.isMine &&
                message.text == draft.message &&
                (draft.attachmentName == null ||
                    message.attachments.any(
                      (attachment) => attachment.name == draft.attachmentName,
                    )),
          );
      setState(() {
        _messages = _mergeMessages(_messages, page.messages);
        if (_messages.isEmpty) {
          _hasMore = page.hasMore;
          _nextBeforeId = page.nextBeforeId;
        } else if (_nextBeforeId == null) {
          _hasMore = page.hasMore;
          _nextBeforeId = page.nextBeforeId;
        }
        if (confirmed) {
          _uncertainDraft = null;
          if (_composer.text.trim() == draft.message) _composer.clear();
          if (_attachment?.name == draft.attachmentName) _attachment = null;
          _sendError = null;
        } else if (draft != null) {
          _sendError =
              'The message is not visible yet. Review the thread before trying again.';
        }
      });
      await _markRead();
      if (confirmed && mounted) {
        _showMessage('Bearly confirms your message was sent.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not refresh this conversation.');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _markRead() async {
    try {
      final count = await widget.repository.markRead(widget.conversation.id);
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Reading remains available while the receipt update is retried later.
    }
  }

  Future<void> _pickAttachment() async {
    if (_sending || _uncertainDraft != null || _pickingAttachment) return;
    setState(() => _pickingAttachment = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      if (file.size > _maxAttachmentBytes) {
        _showMessage('Attachments must be 10 MB or smaller.');
        return;
      }
      if (file.bytes == null || file.bytes!.isEmpty) {
        _showMessage('Bearly could not read that file. Choose it again.');
        return;
      }
      setState(() => _attachment = file);
    } catch (_) {
      if (mounted) _showMessage('Could not open the file picker.');
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _uncertainDraft != null || !_isOpen) return;
    final message = _composer.text.trim();
    final file = _attachment;
    if (message.isEmpty && file == null) return;
    if (message.length > _maxMessageLength) return;

    final baseline = _latestMessageId;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final sent = await widget.repository.sendMessage(
        widget.conversation.id,
        message: message,
        attachmentBytes: file?.bytes,
        attachmentName: file?.name,
      );
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(_messages, [sent]);
        if (_composer.text.trim() == message) _composer.clear();
        if (_attachment?.name == file?.name) _attachment = null;
        _sendError = null;
        _uncertainDraft = null;
      });
      _scrollToLatest();
      await _markRead();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiHttpException && error.statusCode < 500) {
        setState(
          () => _sendError = error.statusCode == 422
              ? 'The message or attachment was rejected. Check its content and try again.'
              : 'The message could not be sent. Try again.',
        );
      } else {
        setState(() {
          _uncertainDraft = _UncertainDraft(
            afterId: baseline,
            message: message,
            attachmentName: file?.name,
          );
          _sendError =
              'The send result is uncertain. Refresh the conversation before retrying.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmRetry() async {
    final draft = _uncertainDraft;
    if (draft == null || _sending) return;
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send this message again?'),
        content: const Text(
          'The refreshed conversation did not confirm the message. Sending it again may create a duplicate if the first request finishes later.',
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
    if (retry != true || !mounted) return;
    setState(() => _uncertainDraft = null);
    await _send();
  }

  Future<void> _openAttachment(MobileMessageAttachment attachment) async {
    try {
      final content = await widget.repository.downloadAttachment(attachment.id);
      if (!mounted) return;
      if (attachment.isImage && content.mimeType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(
                Uint8List.fromList(content.bytes),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('This image could not be previewed.'),
                ),
              ),
            ),
          ),
        );
        return;
      }

      final savedPath = await FilePicker.saveFile(
        fileName: attachment.name,
        bytes: Uint8List.fromList(content.bytes),
      );
      if (mounted) {
        _showMessage(
          savedPath == null ? 'File save was cancelled.' : 'Attachment saved.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not retrieve this attachment. Check your connection.',
        );
      }
    }
  }

  List<MobileChatMessage> _mergeMessages(
    List<MobileChatMessage> earlier,
    List<MobileChatMessage> later,
  ) {
    final byId = <int, MobileChatMessage>{
      for (final message in earlier) message.id: message,
      for (final message in later) message.id: message,
    };
    final merged = byId.values.toList()
      ..sort((a, b) {
        final timestamp = (a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        return timestamp != 0 ? timestamp : a.id.compareTo(b.id);
      });
    return List.unmodifiable(merged);
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.conversation.subject.isNotEmpty)
            Text(
              widget.conversation.subject,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      actions: [
        if ((_unreadCount ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(child: Text('${_unreadCount!} unread')),
          ),
        IconButton(
          key: const ValueKey('mobile-conversation-refresh'),
          tooltip: 'Refresh conversation',
          onPressed: _refreshing || _loading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(child: _thread()),
        _composerBar(),
      ],
    ),
  );

  Widget _thread() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadInitial,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        key: const ValueKey('mobile-message-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: _messages.length + (_hasMore || _loadingOlder ? 1 : 0),
        itemBuilder: (context, index) {
          if ((_hasMore || _loadingOlder) && index == 0) {
            return Center(
              child: TextButton.icon(
                onPressed: _loadingOlder ? null : _loadOlder,
                icon: _loadingOlder
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_less_rounded),
                label: Text(
                  _loadingOlder
                      ? 'Loading earlier messages'
                      : 'Load earlier messages',
                ),
              ),
            );
          }
          if (_messages.isEmpty) {
            return const SizedBox(
              height: 260,
              child: Center(
                child: Text('No messages in this conversation yet.'),
              ),
            );
          }
          final offset = (_hasMore || _loadingOlder) ? 1 : 0;
          return _messageBubble(_messages[index - offset]);
        },
      ),
    );
  }

  Widget _messageBubble(MobileChatMessage message) {
    final alignment = message.isMine
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = message.isMine ? BearlyColors.cream100 : Colors.white;
    final name = message.isMine ? 'You' : message.sender.name;
    final role = message.isMine ? '' : message.sender.role;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: Card(
          color: color,
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.isEmpty ? name : '$name · $role',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BearlyColors.brown900,
                  ),
                ),
                if (message.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(message.text),
                ],
                for (final attachment in message.attachments)
                  _attachmentTile(attachment),
                const SizedBox(height: 5),
                Text(
                  [
                    message.dayLabel,
                    message.timeLabel,
                    if (message.isMine && message.receiptLabel != null)
                      message.receiptLabel!,
                  ].where((value) => value.isNotEmpty).join(' · '),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: BearlyColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentTile(MobileMessageAttachment attachment) => InkWell(
    key: ValueKey('message-attachment-${attachment.id}'),
    onTap: () => _openAttachment(attachment),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            attachment.isImage
                ? Icons.image_outlined
                : attachment.isVideo
                ? Icons.video_file_outlined
                : Icons.attach_file_rounded,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_sizeLabel(attachment.sizeBytes)} · ${attachment.mimeType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Icon(
            attachment.isImage
                ? Icons.visibility_outlined
                : Icons.download_outlined,
            size: 20,
          ),
        ],
      ),
    ),
  );

  Widget _composerBar() => SafeArea(
    top: false,
    child: Material(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isOpen)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'This conversation is closed. You can still read its messages.',
                ),
              ),
            if (_attachment != null)
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(Icons.attach_file_rounded, size: 18),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 230),
                    child: Text(
                      _attachment!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: _sending
                      ? null
                      : () => setState(() => _attachment = null),
                ),
              ),
            if (_sendError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _sendError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (_uncertainDraft != null)
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Refresh'),
                    ),
                  if (_uncertainDraft != null && !_refreshing)
                    TextButton(
                      onPressed: _confirmRetry,
                      child: const Text('Send again'),
                    ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const ValueKey('mobile-message-attach'),
                  tooltip: 'Attach a file',
                  onPressed:
                      !_isOpen ||
                          _sending ||
                          _uncertainDraft != null ||
                          _pickingAttachment
                      ? null
                      : _pickAttachment,
                  icon: _pickingAttachment
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_rounded),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('mobile-message-composer'),
                    controller: _composer,
                    enabled: _isOpen && !_sending && _uncertainDraft == null,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: _maxMessageLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                      counterText: '',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  key: const ValueKey('mobile-message-send'),
                  tooltip: 'Send message',
                  onPressed: !_isOpen || _sending || _uncertainDraft != null
                      ? null
                      : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String _sizeLabel(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UncertainDraft {
  const _UncertainDraft({
    required this.afterId,
    required this.message,
    required this.attachmentName,
  });

  final int afterId;
  final String message;
  final String? attachmentName;
}
