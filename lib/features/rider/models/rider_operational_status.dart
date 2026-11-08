class RiderOperationalStatus {
  const RiderOperationalStatus({
    required this.availabilityStatus,
    required this.operationalState,
    required this.workType,
    required this.activeShiftId,
    required this.checkedInAt,
    required this.activePickups,
    required this.activePickupsInProgress,
    required this.activeDeliveries,
    required this.activeDeliveriesInProgress,
    required this.activeCourierRuns,
    required this.activeCourierRunsInProgress,
    required this.canGoOnline,
    required this.canGoOffline,
    required this.canStartShift,
    required this.canEndShift,
    required this.availabilityNote,
    required this.shiftNote,
    required this.assignmentRulesNote,
  });

  final String availabilityStatus;
  final String operationalState;
  final String workType;
  final int? activeShiftId;
  final DateTime? checkedInAt;
  final int activePickups;
  final int activePickupsInProgress;
  final int activeDeliveries;
  final int activeDeliveriesInProgress;
  final int activeCourierRuns;
  final int activeCourierRunsInProgress;
  final bool canGoOnline;
  final bool canGoOffline;
  final bool canStartShift;
  final bool canEndShift;
  final String availabilityNote;
  final String shiftNote;
  final String assignmentRulesNote;

  bool get hasActiveShift => activeShiftId != null;
  int get activeWorkCount =>
      activePickups + activeDeliveries + activeCourierRuns;

  factory RiderOperationalStatus.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Bearly returned an invalid Rider operational status.',
      );
    }
    final map = Map<String, Object?>.from(value);
    final shiftValue = map['active_shift'];
    final shift = shiftValue is Map
        ? Map<String, Object?>.from(shiftValue)
        : const <String, Object?>{};
    final workValue = map['active_work'];
    final work = workValue is Map
        ? Map<String, Object?>.from(workValue)
        : const <String, Object?>{};
    final transitionValue = map['transitions'];
    final transitions = transitionValue is Map
        ? Map<String, Object?>.from(transitionValue)
        : const <String, Object?>{};

    return RiderOperationalStatus(
      availabilityStatus: _string(map['availability_status'], 'offline'),
      operationalState: _string(map['operational_state'], 'offline'),
      workType: _string(map['work_type'], 'unknown'),
      activeShiftId: _integer(shift['id']),
      checkedInAt: DateTime.tryParse(_string(shift['checked_in_at'], '')),
      activePickups: _integer(work['pickups']),
      activePickupsInProgress: _integer(work['pickups_in_progress']),
      activeDeliveries: _integer(work['deliveries']),
      activeDeliveriesInProgress: _integer(work['deliveries_in_progress']),
      activeCourierRuns: _integer(work['courier_runs']),
      activeCourierRunsInProgress: _integer(work['courier_runs_in_progress']),
      canGoOnline: transitions['can_go_online'] == true,
      canGoOffline: transitions['can_go_offline'] == true,
      canStartShift: transitions['can_start_shift'] == true,
      canEndShift: transitions['can_end_shift'] == true,
      availabilityNote: _string(map['availability_note'], ''),
      shiftNote: _string(map['shift_note'], ''),
      assignmentRulesNote: _string(map['assignment_rules_note'], ''),
    );
  }

  static String _string(Object? value, String fallback) =>
      value is String ? value : fallback;

  static int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
