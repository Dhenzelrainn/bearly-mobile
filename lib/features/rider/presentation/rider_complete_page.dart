import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderCompletePage extends StatefulWidget {
  const RiderCompletePage({super.key});

  @override
  State<RiderCompletePage> createState() => _RiderCompletePageState();
}

class _RiderCompletePageState extends State<RiderCompletePage> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: 'Complete Delivery',
    subtitle: 'Record the handoff details and close the active delivery.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        riderSummary(
          context,
          Icons.check_circle_outline_rounded,
          'ORD-71042',
          'Ready to record the customer handoff',
        ),
        const SizedBox(height: 14),
        riderContactCard(
          context,
          Icons.person_outline_rounded,
          'Mika Reyes',
          'Greenhills Shopping Center, San Juan',
        ),
        const SizedBox(height: 14),
        Text(
          'Proof of delivery',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => riderMessage(
            context,
            'Camera and signature capture will connect to Laravel.',
          ),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Take delivery photo'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Handoff note',
            hintText: 'Add a short delivery note',
          ),
        ),
        const SizedBox(height: 14),
        riderNotice(
          context,
          'Safety reminder',
          'Only mark completed after the parcel has been handed to the customer.',
          Icons.shield_outlined,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _complete,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Mark delivery complete'),
        ),
      ],
    ),
  );

  void _complete() {
    riderMessage(context, 'Delivery completed and payout prepared.');
    Navigator.pushNamedAndRemoveUntil(context, AppRouteNames.rider, (_) => false);
  }
}
