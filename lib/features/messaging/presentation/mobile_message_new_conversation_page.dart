import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mobile_messaging_data_source.dart';
import '../models/mobile_messaging_models.dart';

class MobileMessageNewConversationPage extends StatefulWidget {
  const MobileMessageNewConversationPage({super.key, required this.repository});

  final MobileMessagingInitiationDataSource repository;

  @override
  State<MobileMessageNewConversationPage> createState() =>
      _MobileMessageNewConversationPageState();
}

class _MobileMessageNewConversationPageState
    extends State<MobileMessageNewConversationPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  List<MobileMessageRecipient> _recipients = const [];
  MobileMessageRecipient? _recipient;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecipients());
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipients = await widget.repository.getRecipients();
      if (!mounted) return;
      setState(() {
        _recipients = recipients;
        if (_recipient != null &&
            !recipients.any((item) => item.id == _recipient!.id)) {
          _recipient = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load authorized contacts. Check your connection and retry.';
      });
    }
  }

  Future<void> _send() async {
    if (_sending || _recipient == null || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final conversation = await widget.repository.startConversation(
        recipientId: _recipient!.id,
        subject: _subjectController.text,
        message: _messageController.text,
      );
      if (mounted) Navigator.of(context).pop(conversation);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error =
              'Could not start this conversation. Review the details and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New conversation')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _recipients.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadRecipients,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        : _recipients.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'There are no authorized messaging contacts for this provider yet.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<MobileMessageRecipient>(
                  key: const ValueKey('mobile-message-recipient'),
                  initialValue: _recipient,
                  decoration: const InputDecoration(labelText: 'Contact'),
                  items: _recipients
                      .map(
                        (recipient) => DropdownMenuItem(
                          value: recipient,
                          child: Text('${recipient.name} · ${recipient.label}'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _sending
                      ? null
                      : (recipient) => setState(() => _recipient = recipient),
                  validator: (recipient) => recipient == null
                      ? 'Select an authorized contact.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('mobile-message-subject'),
                  controller: _subjectController,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('mobile-message-first-message'),
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final message = value?.trim() ?? '';
                    if (message.isEmpty) return 'Write a message to continue.';
                    if (message.length > 5000) return 'Message is too long.';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('mobile-message-start'),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Starting…' : 'Start conversation'),
                ),
              ],
            ),
          ),
  );
}
