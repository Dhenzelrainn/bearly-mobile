import 'package:bearly_mobile/features/rider/data/rider_map_tile_cache.dart';
import 'package:bearly_mobile/features/rider/models/rider_map_data.dart';
import 'package:bearly_mobile/features/rider/widgets/rider_assignment_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders OSM attribution and authorized Rider markers', (
    tester,
  ) async {
    const current = RiderLiveLocation(
      sharing: true,
      latitude: 14.3121,
      longitude: 121.1112,
      accuracyMeters: 8,
      lastSeenAt: null,
      freshnessState: 'fresh',
      gpsQuality: 'usable',
      maxUsableAccuracyMeters: 100,
    );
    const data = RiderMapData(
      workType: 'local',
      currentLocation: current,
      destinations: [
        RiderMapDestination(
          id: 'PU-100',
          kind: 'pickup',
          title: 'Assigned pickup',
          address: 'Santa Rosa',
          status: 'assigned',
          latitude: 14.313,
          longitude: 121.112,
        ),
      ],
      tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      tileAttribution: '© OpenStreetMap contributors',
      providerConfigured: true,
      staleAfterSeconds: 180,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderAssignmentMap(
            mapData: data,
            currentLocation: current,
            tileCache: _UnavailableTileSource(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Map tile unavailable'), findsWidgets);
  });
}

class _UnavailableTileSource implements RiderMapTileSource {
  @override
  Future<RiderMapTileContent> load(String tileUrl) =>
      Future.error(const FormatException('Tile server is unavailable.'));
}
