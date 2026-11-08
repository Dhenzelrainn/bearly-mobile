import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/rider_map_tile_cache.dart';
import '../models/rider_map_data.dart';

class RiderMapMarker {
  const RiderMapMarker({
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.kind,
    this.current = false,
    this.stale = false,
  });

  final String title;
  final double latitude;
  final double longitude;
  final String kind;
  final bool current;
  final bool stale;
}

class RiderAssignmentMap extends StatelessWidget {
  const RiderAssignmentMap({
    super.key,
    required this.mapData,
    required this.currentLocation,
    this.height = 320,
    this.tileCache,
  });

  final RiderMapData mapData;
  final RiderLiveLocation currentLocation;
  final double height;
  final RiderMapTileSource? tileCache;

  @override
  Widget build(BuildContext context) {
    if (!mapData.providerConfigured || mapData.tileUrl == null) {
      return _unavailable(
        context,
        'Map tiles are not configured in Laravel. Assigned destinations remain listed below.',
      );
    }

    final markers = _markers();
    if (markers.isEmpty) {
      return _unavailable(
        context,
        'Your map will appear after location sharing starts or an assigned destination has verified coordinates.',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, height);
            final view = _fitView(markers, size);
            return Stack(
              fit: StackFit.expand,
              children: [
                _TileLayer(
                  tileUrl: mapData.tileUrl!,
                  centerLatitude: view.$1,
                  centerLongitude: view.$2,
                  zoom: view.$3,
                  markers: markers,
                  size: size,
                  tileCache: tileCache ?? RiderMapTileCache.instance,
                ),
                Positioned(
                  left: 7,
                  bottom: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        mapData.tileAttribution,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<RiderMapMarker> _markers() {
    final markers = <RiderMapMarker>[];
    if (currentLocation.hasCoordinates) {
      markers.add(
        RiderMapMarker(
          title: currentLocation.freshnessState == 'stale'
              ? 'Last shared location (stale)'
              : 'Your location',
          latitude: currentLocation.latitude!,
          longitude: currentLocation.longitude!,
          kind: 'rider',
          current: true,
          stale: currentLocation.freshnessState == 'stale',
        ),
      );
    }
    markers.addAll(
      mapData.destinations.map(
        (destination) => RiderMapMarker(
          title: destination.title,
          latitude: destination.latitude,
          longitude: destination.longitude,
          kind: destination.kind,
        ),
      ),
    );
    return markers;
  }

  (double, double, int) _fitView(List<RiderMapMarker> markers, Size size) {
    const worldSize = 256.0;
    final points = markers
        .map(
          (marker) => _worldPixel(marker.latitude, marker.longitude, worldSize),
        )
        .toList(growable: false);
    var minX = points.first.$1;
    var maxX = points.first.$1;
    var minY = points.first.$2;
    var maxY = points.first.$2;
    for (final point in points.skip(1)) {
      if (point.$1 < minX) minX = point.$1;
      if (point.$1 > maxX) maxX = point.$1;
      if (point.$2 < minY) minY = point.$2;
      if (point.$2 > maxY) maxY = point.$2;
    }
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final spanX = maxX - minX;
    final spanY = maxY - minY;
    final zoomX = spanX == 0 ? double.infinity : size.width * .72 / spanX;
    final zoomY = spanY == 0 ? double.infinity : size.height * .72 / spanY;
    final zoomScale = math.min(zoomX, zoomY);
    final zoom = zoomScale.isInfinite ? 15.0 : math.log(zoomScale) / math.ln2;
    final zoomLevel = zoom.floor().clamp(0, 15).toInt();
    final longitude = centerX / worldSize * 360 - 180;
    final mercator = math.pi - 2 * math.pi * centerY / worldSize;
    final sinh = (math.exp(mercator) - math.exp(-mercator)) / 2;
    final latitude = math.atan(sinh) * 180 / math.pi;
    return (latitude, longitude, zoomLevel);
  }

  Widget _unavailable(BuildContext context, String message) => Container(
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(message, textAlign: TextAlign.center),
  );
}

class _TileLayer extends StatelessWidget {
  const _TileLayer({
    required this.tileUrl,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.zoom,
    required this.markers,
    required this.size,
    required this.tileCache,
  });

  final String tileUrl;
  final double centerLatitude;
  final double centerLongitude;
  final int zoom;
  final List<RiderMapMarker> markers;
  final Size size;
  final RiderMapTileSource tileCache;

  static const _tileSize = 256.0;
  @override
  Widget build(BuildContext context) {
    final worldSize = _tileSize * math.pow(2, zoom).toDouble();
    final center = _worldPixel(centerLatitude, centerLongitude, worldSize);
    final leftMost = ((center.$1 - size.width / 2) / _tileSize).floor();
    final rightMost = ((center.$1 + size.width / 2) / _tileSize).floor();
    final topMost = ((center.$2 - size.height / 2) / _tileSize).floor();
    final bottomMost = ((center.$2 + size.height / 2) / _tileSize).floor();
    final tileCount = 1 << zoom;
    final children = <Widget>[];

    for (var x = leftMost; x <= rightMost; x++) {
      for (var y = topMost; y <= bottomMost; y++) {
        if (y < 0 || y >= tileCount) continue;
        final wrappedX = ((x % tileCount) + tileCount) % tileCount;
        final left = size.width / 2 + (x * _tileSize - center.$1);
        final top = size.height / 2 + (y * _tileSize - center.$2);
        children.add(
          Positioned(
            left: left,
            top: top,
            width: _tileSize,
            height: _tileSize,
            child: _CachedTileImage(
              cache: tileCache,
              url: tileUrl
                  .replaceAll('{z}', '$zoom')
                  .replaceAll('{x}', '$wrappedX')
                  .replaceAll('{y}', '$y'),
            ),
          ),
        );
      }
    }

    for (final marker in markers) {
      final point = _worldPixel(marker.latitude, marker.longitude, worldSize);
      final left = size.width / 2 + point.$1 - center.$1 - 13;
      final top = size.height / 2 + point.$2 - center.$2 - 27;
      if (left < -30 ||
          top < -35 ||
          left > size.width + 15 ||
          top > size.height + 15) {
        continue;
      }
      final color = marker.current
          ? (marker.stale ? Colors.blueGrey : const Color(0xff147d4a))
          : const Color(0xffc84335);
      children.add(
        Positioned(
          left: left,
          top: top,
          child: Tooltip(
            message: marker.title,
            child: Icon(
              marker.current ? Icons.my_location : Icons.location_on,
              size: 28,
              color: color,
              shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xffe8ece8),
      child: Stack(clipBehavior: Clip.hardEdge, children: children),
    );
  }
}

class _CachedTileImage extends StatefulWidget {
  const _CachedTileImage({required this.cache, required this.url});

  final RiderMapTileSource cache;
  final String url;

  @override
  State<_CachedTileImage> createState() => _CachedTileImageState();
}

class _CachedTileImageState extends State<_CachedTileImage> {
  late Future<RiderMapTileContent> _tile;

  @override
  void initState() {
    super.initState();
    _tile = widget.cache.load(widget.url);
  }

  @override
  void didUpdateWidget(covariant _CachedTileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.cache != widget.cache) {
      _tile = widget.cache.load(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RiderMapTileContent>(
    future: _tile,
    builder: (context, snapshot) {
      final tile = snapshot.data;
      if (tile != null) {
        return Image.memory(
          tile.bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              const _TileUnavailable(),
        );
      }
      if (snapshot.hasError) return const _TileUnavailable();
      return const ColoredBox(color: Color(0xffe8ece8));
    },
  );
}

class _TileUnavailable extends StatelessWidget {
  const _TileUnavailable();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xffe8ece8),
    child: Center(
      child: Text(
        'Map tile unavailable',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
    ),
  );
}

(double, double) _worldPixel(
  double latitude,
  double longitude,
  double worldSize,
) {
  final safeLatitude = latitude.clamp(-85.05112878, 85.05112878);
  final x = (longitude + 180) / 360 * worldSize;
  final latitudeRadians = safeLatitude * math.pi / 180;
  final y =
      (1 -
          math.log(math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians)) /
              math.pi) /
      2 *
      worldSize;
  return (x, y);
}
