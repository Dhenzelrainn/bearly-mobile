import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum RiderLocationSettingsAction { app, location }

class RiderDeviceLocationException implements Exception {
  const RiderDeviceLocationException(this.message, {this.action});

  final String message;
  final RiderLocationSettingsAction? action;

  @override
  String toString() => message;
}

class RiderDevicePosition {
  const RiderDevicePosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;

  factory RiderDevicePosition.fromPosition(Position position) =>
      RiderDevicePosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
}

abstract interface class RiderDeviceLocationSource {
  Future<RiderDevicePosition> requestForegroundPosition();

  Stream<RiderDevicePosition> watchForegroundPosition();

  Future<void> openSettings(RiderLocationSettingsAction action);
}

class GeolocatorRiderDeviceLocation implements RiderDeviceLocationSource {
  const GeolocatorRiderDeviceLocation();

  @override
  Future<RiderDevicePosition> requestForegroundPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const RiderDeviceLocationException(
        'Turn on Location Services on your device, then try again.',
        action: RiderLocationSettingsAction.location,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const RiderDeviceLocationException(
        'Location permission is blocked. Allow Bearly to access location while using the app in Settings.',
        action: RiderLocationSettingsAction.app,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const RiderDeviceLocationException(
        'Location permission was denied. Allow location while using Bearly to share your position.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      return RiderDevicePosition.fromPosition(position);
    } on TimeoutException {
      throw const RiderDeviceLocationException(
        'The device did not get a GPS fix. Check Location Services and try again.',
        action: RiderLocationSettingsAction.location,
      );
    } on LocationServiceDisabledException {
      throw const RiderDeviceLocationException(
        'Turn on Location Services on your device, then try again.',
        action: RiderLocationSettingsAction.location,
      );
    } on PermissionDeniedException {
      throw const RiderDeviceLocationException(
        'Location permission is unavailable. Allow location while using Bearly in Settings.',
        action: RiderLocationSettingsAction.app,
      );
    }
  }

  @override
  Stream<RiderDevicePosition> watchForegroundPosition() {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map(RiderDevicePosition.fromPosition);
  }

  @override
  Future<void> openSettings(RiderLocationSettingsAction action) async {
    if (action == RiderLocationSettingsAction.app) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
  }
}
