import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/rider_account.dart';
import '../models/rider_assignment.dart';
import '../models/rider_earnings.dart';
import '../models/rider_history.dart';

/// Rider mobile API calls for assignments, profile, and history.
class RiderRepository {
  RiderRepository({required AuthService authService})
    : _authService = authService,
      _workAccessCache = _cacheFor(authService);

  static final Expando<_RiderWorkAccessCache> _caches =
      Expando<_RiderWorkAccessCache>('Rider work access');

  static _RiderWorkAccessCache _cacheFor(AuthService authService) =>
      _caches[authService] ??= _RiderWorkAccessCache();

  final AuthService _authService;
  final _RiderWorkAccessCache _workAccessCache;

  static const workAccessCacheDuration = Duration(seconds: 45);

  /// A previous server-confirmed capability for the current signed-in Rider.
  /// It may be used to keep navigation stable, but never authorizes local jobs.
  RiderWorkAccess? get lastKnownWorkAccess =>
      _workAccessForCurrentSession(requireFresh: false);

  /// Only a recent server-confirmed capability can open local Rider screens.
  RiderWorkAccess? get verifiedWorkAccess =>
      _workAccessForCurrentSession(requireFresh: true);

  bool get hasRiderSession =>
      _authService.currentSession?.role == AccountRole.rider;

  int get sessionEpoch => _authService.sessionEpoch;

  int? get currentAccountId => _authService.currentSession?.id;

  void addSessionListener(void Function() listener) =>
      _authService.addListener(listener);

  void removeSessionListener(void Function() listener) =>
      _authService.removeListener(listener);

  Future<RiderDashboard> dashboard() async {
    final context = _currentSessionContext;
    final dashboard = RiderDashboard.fromJson(
      await _authService.getWithSession('/api/mobile/rider/dashboard'),
    );
    _rememberWorkAccess(
      dashboard.workType,
      dashboard.supportsLocalFulfillment,
      context,
    );
    return dashboard;
  }

  Future<RiderAccount> account() async {
    final context = _currentSessionContext;
    final account = RiderAccount.fromJson(
      _data(await _authService.getWithSession('/api/mobile/rider/account')),
    );
    _rememberWorkAccess(
      account.workType,
      account.supportsLocalFulfillment,
      context,
    );
    return account;
  }

  /// Returns a recent server capability or verifies it through the account API.
  /// `account()` remains an uncached profile read; only this navigation hint is
  /// reused, and every job API continues to enforce authorization on Laravel.
  Future<RiderWorkAccess> workAccess({bool forceRefresh = false}) {
    final cached = verifiedWorkAccess;
    if (!forceRefresh && cached != null) return Future.value(cached);

    final context = _currentSessionContext;
    if (context == null) {
      return Future.error(StateError('A signed-in Rider session is required.'));
    }

    final cache = _workAccessCache;
    final pending = cache.pending;
    final pendingContext = cache.pendingContext;
    if (pending != null && pendingContext?.matches(context) == true) {
      return pending;
    }

    final request = _loadWorkAccess(context);
    cache
      ..pending = request
      ..pendingContext = context;
    return request.whenComplete(() {
      if (identical(cache.pending, request)) {
        cache
          ..pending = null
          ..pendingContext = null;
      }
    });
  }

  Future<RiderWorkAccess> _loadWorkAccess(_RiderSessionContext context) async {
    final riderAccount = await account();
    if (_authService.currentSession?.id != context.accountId ||
        _authService.sessionEpoch != context.sessionEpoch) {
      throw StateError('The Rider session changed during access verification.');
    }
    return RiderWorkAccess(
      workType: riderAccount.workType,
      supportsLocalFulfillment: riderAccount.supportsLocalFulfillment,
    );
  }

  RiderWorkAccess? _workAccessForCurrentSession({required bool requireFresh}) {
    final session = _authService.currentSession;
    if (session == null || session.role != AccountRole.rider) return null;

    final cache = _workAccessCache;
    if (cache.accountId != session.id ||
        cache.sessionEpoch != _authService.sessionEpoch) {
      return null;
    }
    if (requireFresh &&
        (cache.verifiedAt == null ||
            DateTime.now().difference(cache.verifiedAt!) >
                workAccessCacheDuration)) {
      return null;
    }
    return cache.access;
  }

  _RiderSessionContext? get _currentSessionContext {
    final session = _authService.currentSession;
    if (session == null || session.role != AccountRole.rider) return null;
    return _RiderSessionContext(session.id, _authService.sessionEpoch);
  }

  void _rememberWorkAccess(
    String workType,
    bool supportsLocalFulfillment,
    _RiderSessionContext? context,
  ) {
    if (context == null) return;
    if (_authService.currentSession?.id != context.accountId ||
        _authService.sessionEpoch != context.sessionEpoch) {
      return;
    }

    _workAccessCache
      ..accountId = context.accountId
      ..sessionEpoch = context.sessionEpoch
      ..access = RiderWorkAccess(
        workType: workType,
        supportsLocalFulfillment: supportsLocalFulfillment,
      )
      ..verifiedAt = DateTime.now();
  }

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

  Future<RiderEarningsData> earnings({int page = 1}) async {
    if (page < 1) throw RangeError.value(page, 'page', 'Must be positive.');
    return RiderEarningsData.fromJson(
      await _authService.getWithSession(
        '/api/mobile/rider/earnings',
        queryParameters: {'page': page},
      ),
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

  Future<RiderAssignment> acceptPickup(
    String pickupNo,
  ) async => RiderAssignment.fromJson(
    _data(
      await _authService.requestWithSession<Object?>(
        method: AuthenticatedRequestMethod.post,
        path:
            '/api/mobile/rider/pickups/${Uri.encodeComponent(pickupNo)}/accept',
        parse: (response) => response,
      ),
    ),
  );

  Future<RiderAssignment> confirmPickup(
    String pickupNo, {
    required String waybillIdentifier,
    String scanMethod = 'manual',
  }) async => RiderAssignment.fromJson(
    _data(
      await _authService.requestWithSession<Object?>(
        method: AuthenticatedRequestMethod.post,
        path:
            '/api/mobile/rider/pickups/${Uri.encodeComponent(pickupNo)}/confirm',
        body: {
          'waybill_identifier': waybillIdentifier.trim(),
          'scan_method': scanMethod,
        },
        parse: (response) => response,
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

  Future<RiderAssignment> startDelivery(
    String shipmentNo,
  ) async => RiderAssignment.fromJson(
    _data(
      await _authService.requestWithSession<Object?>(
        method: AuthenticatedRequestMethod.post,
        path:
            '/api/mobile/rider/deliveries/${Uri.encodeComponent(shipmentNo)}/start',
        parse: (response) => response,
      ),
    ),
  );

  Future<RiderAssignment> failDelivery(
    String shipmentNo, {
    required String failureReason,
  }) async => RiderAssignment.fromJson(
    _data(
      await _authService.requestWithSession<Object?>(
        method: AuthenticatedRequestMethod.post,
        path:
            '/api/mobile/rider/deliveries/${Uri.encodeComponent(shipmentNo)}/fail',
        body: {'failure_reason': failureReason.trim()},
        parse: (response) => response,
      ),
    ),
  );

  Future<RiderAssignment> retryDelivery(
    String shipmentNo,
  ) async => RiderAssignment.fromJson(
    _data(
      await _authService.requestWithSession<Object?>(
        method: AuthenticatedRequestMethod.post,
        path:
            '/api/mobile/rider/deliveries/${Uri.encodeComponent(shipmentNo)}/retry',
        parse: (response) => response,
      ),
    ),
  );

  Future<RiderDeliveryCompletion> deliveryCompletionStatus(
    String shipmentNo,
  ) async => RiderDeliveryCompletion.fromJson(
    _data(
      await _authService.getWithSession(
        '/api/mobile/rider/deliveries/${Uri.encodeComponent(shipmentNo)}/completion-status',
      ),
    ),
  );

  Future<RiderDeliveryCompletion> completeDelivery(
    String shipmentNo, {
    required String recipientName,
    required List<int> proofPhotoBytes,
    required String proofPhotoName,
    String? codCollectedAmount,
  }) async {
    final fields = <String, String>{'recipient_name': recipientName.trim()};
    if (codCollectedAmount != null) {
      fields['cod_collected_amount'] = codCollectedAmount.trim();
    }

    return RiderDeliveryCompletion.fromJson(
      _data(
        await _authService.multipartRequestWithSession<Object?>(
          path:
              '/api/mobile/rider/deliveries/${Uri.encodeComponent(shipmentNo)}/complete',
          fields: fields,
          fileField: 'proof_photo',
          fileBytes: proofPhotoBytes,
          fileName: proofPhotoName,
          parse: (response) => response,
        ),
      ),
    );
  }

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

class RiderWorkAccess {
  const RiderWorkAccess({
    required this.workType,
    required this.supportsLocalFulfillment,
  });

  final String workType;
  final bool supportsLocalFulfillment;
}

class _RiderWorkAccessCache {
  int? accountId;
  int? sessionEpoch;
  RiderWorkAccess? access;
  DateTime? verifiedAt;
  Future<RiderWorkAccess>? pending;
  _RiderSessionContext? pendingContext;
}

class _RiderSessionContext {
  const _RiderSessionContext(this.accountId, this.sessionEpoch);

  final int accountId;
  final int sessionEpoch;

  bool matches(_RiderSessionContext other) =>
      accountId == other.accountId && sessionEpoch == other.sessionEpoch;
}
