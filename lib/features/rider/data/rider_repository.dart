import '../../auth/data/auth_service.dart';
import '../models/rider_account.dart';
import '../models/rider_assignment.dart';
import '../models/rider_history.dart';

/// Read-only Rider mobile API calls for the first integration milestone.
class RiderRepository {
  const RiderRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<RiderDashboard> dashboard() async => RiderDashboard.fromJson(
    await _authService.getWithSession('/api/mobile/rider/dashboard'),
  );

  Future<RiderAccount> account() async => RiderAccount.fromJson(
    _data(await _authService.getWithSession('/api/mobile/rider/account')),
  );

  Future<RiderHistory> history({String? search, int page = 1}) async {
    final parameters = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      parameters['search'] = search.trim();
    }
    if (page > 1) parameters['page'] = '$page';
    final query = parameters.isEmpty
        ? ''
        : '?${Uri(queryParameters: parameters).query}';
    return RiderHistory.fromJson(
      await _authService.getWithSession('/api/mobile/rider/history$query'),
    );
  }

  Future<List<RiderAssignment>> pickupJobs() async =>
      _jobs(await _authService.getWithSession('/api/mobile/rider/pickups'));

  Future<RiderAssignment> pickupDetail(String pickupNo) async =>
      RiderAssignment.fromJson(
        _data(
          await _authService.getWithSession(
            '/api/mobile/rider/pickups/${Uri.encodeComponent(pickupNo)}',
          ),
        ),
      );

  Future<List<RiderAssignment>> deliveryJobs() async =>
      _jobs(await _authService.getWithSession('/api/mobile/rider/deliveries'));

  Future<RiderAssignment> deliveryDetail(String shipmentNo) async =>
      RiderAssignment.fromJson(
        _data(
          await _authService.getWithSession(
            '/api/mobile/rider/deliveries/${Uri.encodeComponent(shipmentNo)}',
          ),
        ),
      );

  Future<List<RiderAssignment>> _jobs(Object? value) async {
    final data = _data(value);
    if (data is! List) {
      throw const FormatException('Bearly returned an invalid Rider job list.');
    }
    return data.map(RiderAssignment.fromJson).toList(growable: false);
  }

  static Object? _data(Object? value) {
    if (value is! Map) {
      throw const FormatException('Bearly returned an invalid Rider response.');
    }
    return value['data'];
  }
}
