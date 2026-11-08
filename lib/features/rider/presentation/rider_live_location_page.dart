import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/rider_device_location.dart';
import '../data/rider_location_repository.dart';
import '../models/rider_map_data.dart';
import '../widgets/rider_assignment_map.dart';

class RiderLiveLocationPage extends StatefulWidget {
  const RiderLiveLocationPage({
    super.key,
    required this.repository,
    required this.deviceLocation,
  });

  final RiderLocationDataSource repository;
  final RiderDeviceLocationSource deviceLocation;

  @override
  State<RiderLiveLocationPage> createState() => _RiderLiveLocationPageState();
}

class _RiderLiveLocationPageState extends State<RiderLiveLocationPage>
    with WidgetsBindingObserver {
  static const _heartbeat = Duration(seconds: 15);

  late Future<RiderMapData> _mapDataFuture;
  RiderMapData? _loadedMapData;
  RiderLiveLocation? _liveLocation;
  RiderDevicePosition? _latestPosition;
  StreamSubscription<RiderDevicePosition>? _positionSubscription;
  Timer? _heartbeatTimer;
  final Stopwatch _timeSinceLastServerFix = Stopwatch();
  DateTime? _lastSentAt;
  Future<void>? _pendingLocationUpdate;
  String? _error;
  RiderLocationSettingsAction? _settingsAction;
  bool _sharing = false;
  bool _starting = false;
  bool _stopping = false;
  bool _cancelStartRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapDataFuture = _loadMapData();
  }

  Future<RiderMapData> _loadMapData() async {
    final data = await widget.repository.loadMapData();
    _loadedMapData = data;
    if (!_sharing) {
      _liveLocation = data.currentLocation;
      _lastSentAt = data.currentLocation.lastSeenAt;
    }
    return data;
  }

  Future<void> _refreshMap() async {
    final future = _loadMapData();
    setState(() => _mapDataFuture = future);
    await future;
  }

  Future<void> _startSharing() async {
    if (_starting || _sharing) return;
    var mayHaveReachedServer = false;
    _cancelStartRequested = false;
    setState(() {
      _starting = true;
      _error = null;
      _settingsAction = null;
    });

    try {
      final position = await widget.deviceLocation.requestForegroundPosition();
      if (!mounted || _cancelStartRequested) return;
      mayHaveReachedServer = true;
      final location = await _sendPosition(position);
      if (!mounted) {
        await widget.repository.stopSharing();
        return;
      }
      if (_cancelStartRequested) {
        await widget.repository.stopSharing();
        return;
      }
      setState(() {
        _sharing = true;
        _latestPosition = position;
        _lastSentAt = location.lastSeenAt ?? DateTime.now();
        _timeSinceLastServerFix
          ..reset()
          ..start();
        _liveLocation = location;
      });
      _positionSubscription = widget.deviceLocation
          .watchForegroundPosition()
          .listen((position) {
            _latestPosition = position;
          }, onError: (Object error) => unawaited(_handleTrackingError(error)));
      _heartbeatTimer = Timer.periodic(
        _heartbeat,
        (_) => unawaited(_sendHeartbeat()),
      );
    } catch (error) {
      if (mayHaveReachedServer) {
        try {
          await widget.repository.stopSharing();
        } catch (_) {
          // The last accepted fix expires under Laravel's freshness rule.
        }
      }
      if (!mounted) return;
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _settingsAction = error is RiderDeviceLocationException
              ? error.action
              : null;
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<RiderLiveLocation> _sendPosition(RiderDevicePosition position) =>
      widget.repository.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracyMeters,
      );

  Future<void> _sendHeartbeat() async {
    final position = _latestPosition;
    if (!_sharing || position == null || _pendingLocationUpdate != null) return;
    final update = _uploadPosition(position);
    _pendingLocationUpdate = update;
    await update;
    if (identical(_pendingLocationUpdate, update)) {
      _pendingLocationUpdate = null;
    }
  }

  Future<void> _uploadPosition(RiderDevicePosition position) async {
    try {
      final location = await _sendPosition(position);
      _lastSentAt = location.lastSeenAt ?? DateTime.now();
      _timeSinceLastServerFix
        ..reset()
        ..start();
      _liveLocation = location;
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  Future<void> _stopSharing({bool showFailure = true}) async {
    if (_stopping) return;
    final hadSharing = _sharing || _positionSubscription != null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final cancellation = _positionSubscription?.cancel();
    _positionSubscription = null;
    if (cancellation != null) {
      unawaited(cancellation.catchError((Object _) {}));
    }
    await _pendingLocationUpdate;
    _latestPosition = null;
    _lastSentAt = null;
    _timeSinceLastServerFix
      ..stop()
      ..reset();

    if (mounted) {
      setState(() {
        _sharing = false;
        _stopping = true;
        _liveLocation = const RiderLiveLocation.missing();
        _error = null;
      });
    }
    if (!hadSharing) {
      if (mounted) setState(() => _stopping = false);
      return;
    }

    try {
      await widget.repository.stopSharing();
      if (mounted) _showMessage('Live location sharing stopped.');
    } catch (_) {
      if (showFailure && mounted) {
        setState(() {
          _error =
              'Sharing stopped on this device. Bearly will treat the last fix as stale after ${_loadedMapData?.staleAfterSeconds ?? 180} seconds.';
        });
      }
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  Future<void> _handleTrackingError(Object error) async {
    await _stopSharing(showFailure: false);
    if (mounted) setState(() => _error = _errorText(error));
  }

  Future<void> _clearRemoteLocation() async {
    await _pendingLocationUpdate;
    try {
      await widget.repository.stopSharing();
    } catch (_) {
      // The last successful fix expires under Laravel's normal freshness rule.
    }
  }

  Future<void> _openSettings() async {
    final action = _settingsAction;
    if (action == null) return;
    await widget.deviceLocation.openSettings(action);
  }

  String _errorText(Object error) {
    if (error is RiderDeviceLocationException) return error.message;
    if (error is ApiHttpException && error.responseData is Map) {
      final response = Map<String, Object?>.from(error.responseData as Map);
      if (response['message'] is String) return response['message'] as String;
      final errors = response['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty && value.first is String) {
            return value.first as String;
          }
        }
      }
    }
    return 'Could not update live location. Check your connection and try again.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (_sharing) {
        unawaited(_stopSharing());
      } else if (_starting) {
        _cancelStartRequested = true;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    unawaited(_positionSubscription?.cancel());
    if (_sharing) unawaited(_clearRemoteLocation());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Live GPS & Map')),
    body: FutureBuilder<RiderMapData>(
      future: _mapDataFuture,
      builder: (context, snapshot) {
        final data = _loadedMapData ?? snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && data == null) {
          return _loadError();
        }
        if (data == null) return _loadError();
        final lastServerFixIsStale =
            _sharing &&
            data.staleAfterSeconds > 0 &&
            _timeSinceLastServerFix.elapsed.inSeconds >= data.staleAfterSeconds;
        final currentLocation = _liveLocation ?? data.currentLocation;
        final location = lastServerFixIsStale
            ? currentLocation.withFreshnessState('stale')
            : currentLocation;

        return RefreshIndicator(
          onRefresh: _refreshMap,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _sharingStatus(context, location),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _starting || _stopping
                    ? null
                    : _sharing
                    ? () => unawaited(_stopSharing())
                    : () => unawaited(_startSharing()),
                icon: _starting || _stopping
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _sharing
                            ? Icons.location_off_outlined
                            : Icons.my_location,
                      ),
                label: Text(
                  _starting
                      ? 'Getting GPS fix…'
                      : _stopping
                      ? 'Stopping…'
                      : _sharing
                      ? 'Stop Sharing'
                      : 'Start Sharing',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _errorCard(context),
              ],
              const SizedBox(height: 16),
              RiderAssignmentMap(
                mapData: data,
                currentLocation: location,
                height: 320,
              ),
              const SizedBox(height: 16),
              Text(
                'Assigned destinations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (data.destinations.isEmpty)
                const _EmptyDestinations()
              else
                ...data.destinations.map(
                  (destination) => _destinationTile(context, destination),
                ),
              const SizedBox(height: 12),
              Text(
                'Location is shared only while Bearly is open on this screen. Switching apps, leaving this screen, or closing Bearly stops device tracking. The last server fix expires after ${data.staleAfterSeconds} seconds.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _sharingStatus(BuildContext context, RiderLiveLocation location) {
    final title = _sharing
        ? location.freshnessState == 'stale'
              ? 'Tracking active; last server fix is stale'
              : 'Sharing live location'
        : location.freshnessState == 'stale'
        ? 'Last shared location is stale'
        : location.freshnessState == 'fresh'
        ? 'A recent fix is on the server'
        : 'Location sharing is off';
    final accuracy = location.accuracyMeters;
    final detail = _sharing
        ? [
            if (accuracy != null)
              'GPS accuracy ±${accuracy.toStringAsFixed(0)} m',
            if (_lastSentAt != null) 'Updated ${_formatTime(_lastSentAt!)}',
            if (location.hasCoordinates)
              '${location.latitude!.toStringAsFixed(5)}, ${location.longitude!.toStringAsFixed(5)}',
          ].join(' · ')
        : location.lastSeenAt == null
        ? 'Use Start Sharing to send your device location to your Logistics provider.'
        : 'Last successful update ${_formatTime(location.lastSeenAt!)}${accuracy == null ? '' : ' · accuracy ±${accuracy.toStringAsFixed(0)} m'}';
    return Card(
      child: ListTile(
        leading: Icon(_sharing ? Icons.location_on : Icons.location_searching),
        title: Text(title),
        subtitle: Text(detail),
      ),
    );
  }

  Widget _errorCard(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          if (_settingsAction != null)
            TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text(
                _settingsAction == RiderLocationSettingsAction.app
                    ? 'Open app settings'
                    : 'Open location settings',
              ),
            ),
        ],
      ),
    ),
  );

  Widget _destinationTile(
    BuildContext context,
    RiderMapDestination destination,
  ) => Card(
    child: ListTile(
      leading: Icon(_destinationIcon(destination.kind)),
      title: Text(destination.title),
      subtitle: Text(
        [
          if (destination.reference.isNotEmpty) destination.reference,
          if (destination.address.isNotEmpty) destination.address,
          '${destination.latitude.toStringAsFixed(5)}, ${destination.longitude.toStringAsFixed(5)}',
          if (destination.status.isNotEmpty) destination.status,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.place_outlined),
    ),
  );

  IconData _destinationIcon(String kind) => switch (kind) {
    'pickup' => Icons.inventory_2_outlined,
    'delivery' => Icons.local_shipping_outlined,
    'linehaul_destination' => Icons.warehouse_outlined,
    _ => Icons.place_outlined,
  };

  Widget _loadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 10),
          const Text(
            'Could not load GPS and map data. Check your connection and retry.',
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: _refreshMap,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _EmptyDestinations extends StatelessWidget {
  const _EmptyDestinations();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No active assigned destination has verified coordinates. Your map will show destinations when coordinates are available.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
      ),
    ),
  );
}
