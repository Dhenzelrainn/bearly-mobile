import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import 'rider_shared.dart';

class RiderRequestsPage extends StatelessWidget {
  const RiderRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RiderPageScaffold(
      title: 'Delivery Requests',
      module: 'MODULE 03',
      subtitle:
          'Review pickup and delivery details, then claim a nearby request.',
      child: Column(
        children: [
          riderSummary(
            context,
            Icons.radar_rounded,
            '${riderJobs.length}',
            'Open requests nearby',
          ),
          const SizedBox(height: 14),
          ...riderJobs.map((job) => _jobCard(context, job)),
        ],
      ),
    );
  }

  Widget _jobCard(BuildContext context, RiderJob job) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.id,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: BearlyColors.gold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${job.order} • ${job.store}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (job.priority) _pill('Priority'),
            ],
          ),
          const SizedBox(height: 12),
          riderRouteRow(
            context,
            Icons.storefront_outlined,
            'Pickup',
            job.pickup,
          ),
          const SizedBox(height: 7),
          riderRouteRow(
            context,
            Icons.location_on_outlined,
            'Drop-off',
            job.dropoff,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                job.payout,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: BearlyColors.brown700),
              ),
              const SizedBox(width: 8),
              Text(
                '${job.distance} • ${job.eta}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: () {
                  riderMessage(context, '${job.id} accepted.');
                  Navigator.pushNamed(context, AppRoutes.riderPickup);
                },
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: BearlyColors.cream200,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text),
  );
}
