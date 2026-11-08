import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/rider/models/rider_map_data.dart';

abstract interface class RiderLocationDataSource {
  Future<RiderMapData> loadMapData();

  Future<RiderLiveLocation> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  });

  Future<void> stopSharing();
}

class RiderLocationRepository implements RiderLocationDataSource {
  RiderLocationRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  @override
  Future<RiderMapData> loadMapData() async => RiderMapData.fromJson(
    _data(await _authService.getWithSession('/api/mobile/rider/map')),
  );

  @override
  Future<RiderLiveLocation> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async => RiderLiveLocation.fromJson(
    _data(
      await _authService.requestWithSession<Object?>(
        method: AuthenticatedRequestMethod.post,
        path: '/api/mobile/rider/location',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy_meters': accuracyMeters,
        },
        parse: (response) => response,
      ),
    ),
  );

  @override
  Future<void> stopSharing() async {
    await _authService.requestWithSession<Object?>(
      method: AuthenticatedRequestMethod.delete,
      path: '/api/mobile/rider/location',
      parse: (response) => response,
    );
  }

  static Object? _data(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Bearly returned an invalid Rider location response.',
      );
    }
    return value['data'];
  }
}
