import 'package:flutter/material.dart';

import '../widgets/rider_shared_widgets.dart';

class RiderMessagesPage extends StatefulWidget {
  const RiderMessagesPage({super.key});

  @override
  State<RiderMessagesPage> createState() => _RiderMessagesPageState();
}

class _RiderMessagesPageState extends State<RiderMessagesPage> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: 'Chat / Messaging',
    subtitle: 'Coordinate with buyers, sellers, and Bearly support.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => riderMessage(
            context,
            'New conversation composer will connect to Laravel.',
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('New message'),
        ),
        const SizedBox(height: 12),
        ...[
          [
            'Mika Reyes',
            'Buyer',
            'Please call when you reach the lobby.',
            'MR',
          ],
          [
            'Northstar Watches',
            'Seller',
            'The parcel is ready at counter 3.',
            'NW',
          ],
          [
            'Bearly Support',
            'Admin',
            'Your weekly courier summary is ready.',
            'BS',
          ],
          ['Karen Yu', 'Buyer', 'Thank you for the delivery!', 'KY'],
        ].map(
          (row) => Card(
            color: Colors.white,
            child: ListTile(
              onTap: () => _openChat(context, row[0]),
              leading: CircleAvatar(child: Text(row[3])),
              title: Text(row[0]),
              subtitle: Text('${row[1]} • ${row[2]}'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Write a message...',
            suffixIcon: IconButton(
              onPressed: () {
                if (_message.text.trim().isNotEmpty) {
                  _message.clear();
                  riderMessage(context, 'Message queued for sending.');
                }
              },
              icon: const Icon(Icons.send_rounded),
            ),
          ),
        ),
      ],
    ),
  );

  void _openChat(BuildContext context, String name) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(name),
      content: const Text(
        'Hi! Please call when you reach the lobby.\n\nSure, I am about 10 minutes away.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
