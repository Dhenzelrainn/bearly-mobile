class RiderJob {
  const RiderJob({
    required this.id,
    required this.order,
    required this.store,
    required this.pickup,
    required this.dropoff,
    required this.distance,
    required this.payout,
    required this.eta,
    required this.size,
    required this.priority,
  });

  final String id;
  final String order;
  final String store;
  final String pickup;
  final String dropoff;
  final String distance;
  final String payout;
  final String eta;
  final String size;
  final bool priority;
}
