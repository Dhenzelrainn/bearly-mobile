import 'package:bearly_mobile/features/rider/models/rider_map_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drops invalid destination coordinates instead of inventing zeroes', () {
    final data = RiderMapData.fromJson({
      'work_type': 'local',
      'current_location': {
        'sharing': true,
        'latitude': 14.5,
        'longitude': 121.0,
        'freshness_state': 'fresh',
      },
      'destinations': [
        {'id': 'valid', 'latitude': 14.6, 'longitude': 121.1},
        {'id': 'missing', 'latitude': null, 'longitude': 121.2},
        {'id': 'out-of-range', 'latitude': 91, 'longitude': 121.2},
      ],
      'map': {'provider_configured': false},
      'stale_after_seconds': 180,
    });

    expect(data.destinations, hasLength(1));
    expect(data.destinations.single.latitude, 14.6);
    expect(data.currentLocation.hasCoordinates, isTrue);
  });

  test('rejects invalid live location coordinates and unsafe tile URLs', () {
    final data = RiderMapData.fromJson({
      'current_location': {
        'sharing': true,
        'latitude': 0,
        'longitude': 181,
        'freshness_state': 'fresh',
      },
      'destinations': [],
      'map': {
        'provider_configured': true,
        'tile_url': 'http://tile.openstreetmap.org/{z}/{x}/{y}.png',
      },
    });

    expect(data.currentLocation.hasCoordinates, isFalse);
    expect(data.currentLocation.sharing, isFalse);
    expect(data.providerConfigured, isFalse);
    expect(data.tileUrl, isNull);
  });

  test(
    'accepts HTTPS OSM tiles and converts the attribution to visible text',
    () {
      final data = RiderMapData.fromJson({
        'current_location': {},
        'destinations': [],
        'map': {
          'provider_configured': true,
          'tile_url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          'attribution': '&copy; OpenStreetMap contributors',
        },
      });

      expect(data.providerConfigured, isTrue);
      expect(data.tileUrl, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      expect(data.tileAttribution, '© OpenStreetMap contributors');
    },
  );

  test('keeps explicit HTTPS provider configuration supported', () {
    final data = RiderMapData.fromJson({
      'current_location': {},
      'destinations': [],
      'map': {
        'provider_configured': true,
        'tile_url': 'https://tiles.example.test/{z}/{x}/{y}.png?key=mobile-key',
        'attribution': 'Example Tiles',
      },
    });

    expect(data.providerConfigured, isTrue);
    expect(
      data.tileUrl,
      'https://tiles.example.test/{z}/{x}/{y}.png?key=mobile-key',
    );
    expect(data.tileAttribution, 'Example Tiles');
  });
}
