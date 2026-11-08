class RiderMapData {
  const RiderMapData({
    required this.workType,
    required this.currentLocation,
    required this.destinations,
    required this.tileUrl,
    required this.tileAttribution,
    required this.providerConfigured,
    required this.staleAfterSeconds,
  });

  final String workType;
  final RiderLiveLocation currentLocation;
  final List<RiderMapDestination> destinations;
  final String? tileUrl;
  final String tileAttribution;
  final bool providerConfigured;
  final int staleAfterSeconds;

  RiderMapData copyWith({RiderLiveLocation? currentLocation}) => RiderMapData(
    workType: workType,
    currentLocation: currentLocation ?? this.currentLocation,
    destinations: destinations,
    tileUrl: tileUrl,
    tileAttribution: tileAttribution,
    providerConfigured: providerConfigured,
    staleAfterSeconds: staleAfterSeconds,
  );

  factory RiderMapData.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Bearly returned invalid Rider map data.');
    }
    final map = Map<String, Object?>.from(value);
    final mapValue = map['map'];
    final mapConfig = mapValue is Map
        ? Map<String, Object?>.from(mapValue)
        : const <String, Object?>{};
    final tileUrl = _mobileTileUrl(mapConfig['tile_url']);
    final configuredAttribution = _string(
      mapConfig['attribution'],
      '',
    ).replaceAll('&copy;', '©');
    final destinationValues = map['destinations'];

    return RiderMapData(
      workType: _string(map['work_type'], 'local'),
      currentLocation: RiderLiveLocation.fromJson(map['current_location']),
      destinations: destinationValues is List
          ? destinationValues
                .whereType<Map>()
                .map(
                  (item) => RiderMapDestination.parse(
                    Map<String, Object?>.from(item),
                  ),
                )
                .whereType<RiderMapDestination>()
                .toList(growable: false)
          : const [],
      tileUrl: tileUrl,
      tileAttribution: configuredAttribution.isNotEmpty
          ? configuredAttribution
          : Uri.tryParse(tileUrl ?? '')?.host.toLowerCase() ==
                'tile.openstreetmap.org'
          ? '© OpenStreetMap contributors'
          : '',
      providerConfigured:
          mapConfig['provider_configured'] == true && tileUrl != null,
      staleAfterSeconds: _integer(map['stale_after_seconds']),
    );
  }
}

class RiderLiveLocation {
  const RiderLiveLocation({
    required this.sharing,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.lastSeenAt,
    required this.freshnessState,
    required this.gpsQuality,
    required this.maxUsableAccuracyMeters,
  });

  const RiderLiveLocation.missing()
    : sharing = false,
      latitude = null,
      longitude = null,
      accuracyMeters = null,
      lastSeenAt = null,
      freshnessState = 'missing',
      gpsQuality = 'unknown',
      maxUsableAccuracyMeters = 100;

  final bool sharing;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? lastSeenAt;
  final String freshnessState;
  final String gpsQuality;
  final int maxUsableAccuracyMeters;

  bool get hasCoordinates => _validCoordinatePair(latitude, longitude);

  RiderLiveLocation withFreshnessState(String value) => RiderLiveLocation(
    sharing: sharing,
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: accuracyMeters,
    lastSeenAt: lastSeenAt,
    freshnessState: value,
    gpsQuality: gpsQuality,
    maxUsableAccuracyMeters: maxUsableAccuracyMeters,
  );

  factory RiderLiveLocation.fromJson(Object? value) {
    if (value is! Map) return const RiderLiveLocation.missing();
    final map = Map<String, Object?>.from(value);
    final latitude = _double(map['latitude']);
    final longitude = _double(map['longitude']);
    if (!_validCoordinatePair(latitude, longitude)) {
      return const RiderLiveLocation.missing();
    }
    return RiderLiveLocation(
      sharing: map['sharing'] == true,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: _double(map['accuracy_meters']),
      lastSeenAt: DateTime.tryParse(_string(map['last_seen_at'], '')),
      freshnessState: _string(map['freshness_state'], 'missing'),
      gpsQuality: _string(map['gps_quality'], 'unknown'),
      maxUsableAccuracyMeters: _integer(map['max_usable_accuracy_meters'], 100),
    );
  }
}

class RiderMapDestination {
  const RiderMapDestination({
    required this.id,
    required this.kind,
    required this.title,
    required this.address,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.reference = '',
  });

  final String id;
  final String kind;
  final String title;
  final String address;
  final String status;
  final double latitude;
  final double longitude;
  final String reference;

  static RiderMapDestination? parse(Map<String, Object?> map) {
    final latitude = _double(map['latitude']);
    final longitude = _double(map['longitude']);
    if (!_validCoordinatePair(latitude, longitude)) return null;

    return RiderMapDestination(
      id: _string(map['id'], ''),
      kind: _string(map['kind'], ''),
      title: _string(map['title'], 'Assignment'),
      address: _string(map['address'], ''),
      status: _string(map['status'], ''),
      latitude: latitude!,
      longitude: longitude!,
      reference: _string(map['reference'], ''),
    );
  }
}

String _string(Object? value, String fallback) =>
    value is String ? value : fallback;

double? _double(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value)
      : null;
  return parsed != null && parsed.isFinite ? parsed : null;
}

bool _validCoordinatePair(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

String? _mobileTileUrl(Object? value) {
  if (value is! String) {
    return null;
  }
  final uri = Uri.tryParse(value);
  final schemeSeparator = value.indexOf('://');
  final pathStart = schemeSeparator < 0
      ? -1
      : value.indexOf('/', schemeSeparator + 3);
  final rawPath = pathStart < 0
      ? ''
      : value.substring(pathStart).split(RegExp(r'[?#]')).first;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !rawPath.contains('/{z}/') ||
      !rawPath.contains('/{x}/') ||
      !rawPath.contains('/{y}.')) {
    return null;
  }
  if (uri.host.toLowerCase() == 'tile.openstreetmap.org' &&
      (rawPath != '/{z}/{x}/{y}.png' || uri.hasQuery || uri.hasFragment)) {
    return null;
  }
  if (uri.host.toLowerCase() == 'api.maptiler.com' &&
      (uri.queryParameters['key']?.trim().isEmpty ?? true)) {
    return null;
  }
  return value;
}

int _integer(Object? value, [int fallback = 0]) => value is int
    ? value
    : value is num
    ? value.toInt()
    : value is String
    ? int.tryParse(value) ?? fallback
    : fallback;
