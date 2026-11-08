class RiderAttendanceResult {
  const RiderAttendanceResult({
    required this.message,
    required this.scanType,
    required this.workDate,
    required this.shiftState,
    required this.scannedAt,
    required this.shiftId,
    required this.checkedInAt,
    required this.checkedOutAt,
    required this.evidenceId,
    required this.evidenceGeneration,
  });

  final String message;
  final String scanType;
  final String workDate;
  final String shiftState;
  final DateTime? scannedAt;
  final int shiftId;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final int evidenceId;
  final int evidenceGeneration;

  bool get checkedIn => scanType == 'check_in';

  factory RiderAttendanceResult.fromResponse(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Bearly returned an invalid attendance scan response.',
      );
    }
    final response = Map<String, Object?>.from(value);
    final dataValue = response['data'];
    if (dataValue is! Map) {
      throw const FormatException(
        'Bearly returned an invalid attendance scan result.',
      );
    }
    final data = Map<String, Object?>.from(dataValue);
    final shiftValue = data['shift'];
    final shift = shiftValue is Map
        ? Map<String, Object?>.from(shiftValue)
        : const <String, Object?>{};
    final evidenceValue = data['evidence'];
    final evidence = evidenceValue is Map
        ? Map<String, Object?>.from(evidenceValue)
        : const <String, Object?>{};
    final scanType = _string(data['scan_type']);
    final shiftState = _string(data['shift_state']);
    if (!const {'check_in', 'check_out'}.contains(scanType) ||
        !const {'checked_in', 'checked_out'}.contains(shiftState) ||
        _integer(shift['id']) <= 0 ||
        _integer(evidence['id']) <= 0 ||
        _integer(evidence['generation']) <= 0) {
      throw const FormatException(
        'Bearly returned incomplete attendance evidence.',
      );
    }

    return RiderAttendanceResult(
      message: _string(response['message']),
      scanType: scanType,
      workDate: _string(data['work_date']),
      shiftState: shiftState,
      scannedAt: _date(data['scanned_at']),
      shiftId: _integer(shift['id']),
      checkedInAt: _date(shift['checked_in_at']),
      checkedOutAt: _date(shift['checked_out_at']),
      evidenceId: _integer(evidence['id']),
      evidenceGeneration: _integer(evidence['generation']),
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static int _integer(Object? value) => value is int
      ? value
      : value is num
      ? value.toInt()
      : value is String
      ? int.tryParse(value) ?? 0
      : 0;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
