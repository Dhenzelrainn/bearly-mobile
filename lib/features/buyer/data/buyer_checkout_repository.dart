import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_checkout_attempt.dart';
import '../models/buyer_checkout_models.dart';
import '../models/buyer_order_models.dart';
import '../models/buyer_tracking_models.dart';
import 'buyer_checkout_attempt_store.dart';

enum BuyerCheckoutFailureCategory {
  noBuyerSession,
  sessionChanged,
  invalidRequest,
  notFound,
  conflict,
  validation,
  rateLimited,
  server,
  client,
  timeout,
  connectivity,
  malformedResponse,
  secureStorage,
  unresolvedAttempt,
  rejectedAttempt,
  expiredQuote,
}

class BuyerCheckoutException implements Exception {
  const BuyerCheckoutException(
    this.category, {
    this.statusCode,
    this.serverErrorCode,
    this.validationErrors = const {},
    this.requestMayHaveReachedServer = false,
  });

  final BuyerCheckoutFailureCategory category;
  final int? statusCode;
  final String? serverErrorCode;
  final Map<String, List<String>> validationErrors;
  final bool requestMayHaveReachedServer;

  @override
  String toString() => 'Buyer checkout request failed: ${category.name}.';
}

/// Buyer checkout, COD order, history, detail, tracking, and receipt API data
/// access. It has no presentation or navigation dependencies.
class BuyerCheckoutRepository {
  BuyerCheckoutRepository({
    required AuthService authService,
    BuyerCheckoutAttemptStore? attemptStore,
    String Function()? uuidGenerator,
    DateTime Function()? clock,
  }) : _authService = authService,
       _attemptStore = attemptStore ?? SecureBuyerCheckoutAttemptStore(),
       _uuidGenerator = uuidGenerator ?? _generateUuidV4,
       _clock = clock ?? DateTime.now;

  final AuthService _authService;
  final BuyerCheckoutAttemptStore _attemptStore;
  final String Function() _uuidGenerator;
  final DateTime Function() _clock;
  final Set<int> _activeAttemptOperations = <int>{};
  final Map<int, BuyerCheckoutAttempt> _cachedAttempts = {};

  Future<BuyerCheckoutQuote> requestQuote(
    BuyerCheckoutQuoteRequest request,
  ) async {
    final buyer = _requireBuyer();
    try {
      return await _authenticated<BuyerCheckoutQuote>(
        buyer,
        method: AuthenticatedRequestMethod.post,
        path: '/api/mobile/buyer/checkout/quote',
        body: request.toJson(),
        parse: (response) => BuyerCheckoutQuote.fromResponse(
          response,
          buyerAccountId: buyer.accountId,
          sourceRequest: request,
        ),
      );
    } on BuyerCheckoutException {
      rethrow;
    } on BuyerCheckoutFormatException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
      );
    }
  }

  /// Creates and securely persists one immutable request before any POST.
  /// The request is derived from the quote's bound selection.
  Future<BuyerCheckoutAttempt> beginPlacementAttempt({
    required BuyerCheckoutQuote quote,
    String? sellerNote,
  }) async {
    final buyer = _requireBuyer();
    _enterAttemptOperation(buyer.accountId);
    try {
      if (quote.buyerAccountId != buyer.accountId) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.sessionChanged,
        );
      }
      if (!quote.quoteExpiresAt.isAfter(_clock())) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.expiredQuote,
        );
      }
      final selection = quote.sourceRequest;
      if (selection == null || quote.paymentMethod != 'cod') {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.invalidRequest,
        );
      }

      final previous = await _readAttempt(buyer.accountId);
      if (previous != null) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.unresolvedAttempt,
        );
      }
      final request = BuyerCheckoutPlacementRequest(
        checkoutRequestKey: _uuidGenerator(),
        quoteToken: quote.quoteToken,
        addressId: selection.addressId,
        cartItemIds: selection.cartItemIds,
        vouchers: selection.vouchers,
        sellerNote: sellerNote,
      );
      final attempt = BuyerCheckoutAttempt(
        buyerAccountId: buyer.accountId,
        request: request,
        status: BuyerCheckoutAttemptStatus.ready,
        updatedAt: _clock().toUtc(),
      );
      await _writeAttempt(attempt);
      return attempt;
    } on BuyerCheckoutException {
      rethrow;
    } on ArgumentError {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.invalidRequest,
      );
    } on BuyerCheckoutAttemptStorageException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.secureStorage,
      );
    } finally {
      _leaveAttemptOperation(buyer.accountId);
    }
  }

  /// Restores the current Buyer's secure attempt without submitting it.
  Future<BuyerCheckoutAttempt?> restorePlacementAttempt() async {
    final buyer = _requireBuyer();
    final attempt = await _readAttempt(buyer.accountId);
    if (attempt == null) return null;
    if (attempt.status == BuyerCheckoutAttemptStatus.submitting) {
      final recovered = attempt.copyWith(
        status: BuyerCheckoutAttemptStatus.indeterminate,
        failureCategory: 'recovered_after_interruption',
        updatedAt: _clock().toUtc(),
      );
      await _writeAttempt(recovered);
      return recovered;
    }
    return attempt;
  }

  /// Submits or explicitly retries the exact secure attempt. No replacement
  /// UUID, token, selection, or payload is generated during a retry.
  Future<BuyerPlacedOrder> submitPlacementAttempt() async {
    final buyer = _requireBuyer();
    _enterAttemptOperation(buyer.accountId);
    try {
      var attempt = await _readAttempt(buyer.accountId);
      if (attempt == null) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.unresolvedAttempt,
        );
      }
      if (attempt.status == BuyerCheckoutAttemptStatus.succeeded &&
          attempt.result != null) {
        return attempt.result!;
      }
      if (attempt.status == BuyerCheckoutAttemptStatus.rejected) {
        throw BuyerCheckoutException(
          BuyerCheckoutFailureCategory.rejectedAttempt,
          serverErrorCode: attempt.serverErrorCode,
          validationErrors: attempt.validationErrors,
        );
      }
      if (attempt.status == BuyerCheckoutAttemptStatus.submitting) {
        attempt = attempt.copyWith(
          status: BuyerCheckoutAttemptStatus.indeterminate,
          failureCategory: 'recovered_after_interruption',
          updatedAt: _clock().toUtc(),
        );
        await _writeAttempt(attempt);
      }

      final pending = attempt.copyWith(
        status: BuyerCheckoutAttemptStatus.submitting,
        clearFailureDetails: true,
        updatedAt: _clock().toUtc(),
      );
      await _writeAttempt(pending);
      late final _BuyerContext context;
      try {
        context = _requireBuyer();
      } on BuyerCheckoutException {
        final ready = pending.copyWith(
          status: BuyerCheckoutAttemptStatus.ready,
          failureCategory: 'session_changed_before_send',
          updatedAt: _clock().toUtc(),
        );
        await _writeAttempt(ready);
        rethrow;
      }
      if (context.accountId != pending.buyerAccountId ||
          context.epoch != buyer.epoch) {
        final ready = pending.copyWith(
          status: BuyerCheckoutAttemptStatus.ready,
          failureCategory: 'session_changed_before_send',
          updatedAt: _clock().toUtc(),
        );
        await _writeAttempt(ready);
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.sessionChanged,
        );
      }

      try {
        final order = await _authenticated<BuyerPlacedOrder>(
          context,
          method: AuthenticatedRequestMethod.post,
          path: '/api/mobile/buyer/checkout/place',
          body: pending.request.toJson(),
          parse: BuyerPlacedOrder.fromResponse,
        );
        final succeeded = pending.copyWith(
          status: BuyerCheckoutAttemptStatus.succeeded,
          result: order,
          clearFailureDetails: true,
          updatedAt: _clock().toUtc(),
        );
        _cachedAttempts[buyer.accountId] = succeeded;
        try {
          await _writeAttempt(succeeded);
        } on BuyerCheckoutAttemptStorageException {
          // The authoritative order is already confirmed. The saved submitting
          // record can safely be retried with the same server idempotency key.
        }
        return order;
      } on BuyerCheckoutException catch (error) {
        final ambiguous =
            error.requestMayHaveReachedServer ||
            error.category == BuyerCheckoutFailureCategory.timeout ||
            error.category == BuyerCheckoutFailureCategory.connectivity ||
            error.category == BuyerCheckoutFailureCategory.malformedResponse ||
            error.category == BuyerCheckoutFailureCategory.server;
        final failed = pending.copyWith(
          status:
              error.category == BuyerCheckoutFailureCategory.sessionChanged &&
                  !error.requestMayHaveReachedServer
              ? BuyerCheckoutAttemptStatus.ready
              : ambiguous
              ? BuyerCheckoutAttemptStatus.indeterminate
              : BuyerCheckoutAttemptStatus.rejected,
          failureCategory: error.category.name,
          serverErrorCode: error.serverErrorCode,
          validationErrors: error.validationErrors,
          updatedAt: _clock().toUtc(),
        );
        await _writeAttempt(failed);
        rethrow;
      }
    } on BuyerCheckoutException {
      rethrow;
    } on BuyerCheckoutAttemptStorageException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.secureStorage,
      );
    } finally {
      _leaveAttemptOperation(buyer.accountId);
    }
  }

  /// Removes only a resolved attempt after the caller has reconciled it.
  Future<void> clearResolvedPlacementAttempt() async {
    final buyer = _requireBuyer();
    _enterAttemptOperation(buyer.accountId);
    try {
      final attempt = await _readAttempt(buyer.accountId);
      if (attempt == null) return;
      if (attempt.status != BuyerCheckoutAttemptStatus.rejected &&
          attempt.status != BuyerCheckoutAttemptStatus.succeeded) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.unresolvedAttempt,
        );
      }
      await _attemptStore.clear(buyer.accountId);
      _cachedAttempts.remove(buyer.accountId);
    } on BuyerCheckoutAttemptStorageException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.secureStorage,
      );
    } finally {
      _leaveAttemptOperation(buyer.accountId);
    }
  }

  /// Clears only an attempt whose persisted state proves no placement POST
  /// began. A `ready` attempt is written before the repository transitions it
  /// to `submitting`, and the latter write completes before HTTP is dispatched.
  Future<void> clearUnsubmittedPlacementAttempt() async {
    final buyer = _requireBuyer();
    _enterAttemptOperation(buyer.accountId);
    try {
      final attempt = await _readAttempt(buyer.accountId);
      if (attempt == null) return;
      if (attempt.status != BuyerCheckoutAttemptStatus.ready) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.unresolvedAttempt,
        );
      }
      await _attemptStore.clear(buyer.accountId);
      _cachedAttempts.remove(buyer.accountId);
    } on BuyerCheckoutException {
      rethrow;
    } on BuyerCheckoutAttemptStorageException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.secureStorage,
      );
    } finally {
      _leaveAttemptOperation(buyer.accountId);
    }
  }

  Future<BuyerOrderHistoryPage> fetchOrderHistory({
    int page = 1,
    int perPage = 20,
  }) async {
    if (page < 1 || perPage < 1 || perPage > 50) {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.invalidRequest,
      );
    }
    final buyer = _requireBuyer();
    try {
      return await _authenticated(
        buyer,
        method: AuthenticatedRequestMethod.get,
        path: '/api/mobile/buyer/orders',
        queryParameters: {'page': page, 'per_page': perPage},
        parse: BuyerOrderHistoryPage.fromResponse,
      );
    } on BuyerCheckoutFormatException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
      );
    }
  }

  Future<BuyerOrderDetail> fetchOrderDetail(int orderId) async {
    _validateOrderId(orderId);
    final buyer = _requireBuyer();
    try {
      return await _authenticated(
        buyer,
        method: AuthenticatedRequestMethod.get,
        path: '/api/mobile/buyer/orders/$orderId',
        parse: BuyerOrderDetail.fromResponse,
      );
    } on BuyerCheckoutFormatException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
      );
    }
  }

  Future<BuyerOrderTracking> fetchTracking(int orderId) async {
    _validateOrderId(orderId);
    final buyer = _requireBuyer();
    try {
      return await _authenticated(
        buyer,
        method: AuthenticatedRequestMethod.get,
        path: '/api/mobile/buyer/orders/$orderId/tracking',
        parse: (response) {
          final tracking = BuyerOrderTracking.fromResponse(response);
          if (tracking.orderId != orderId) {
            throw const BuyerCheckoutFormatException('data.order_id');
          }
          return tracking;
        },
      );
    } on BuyerCheckoutFormatException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
      );
    }
  }

  Future<BuyerReceiptConfirmation> confirmReceipt(int orderId) async {
    _validateOrderId(orderId);
    final buyer = _requireBuyer();
    try {
      return await _authenticated(
        buyer,
        method: AuthenticatedRequestMethod.post,
        path: '/api/mobile/buyer/orders/$orderId/confirm-receipt',
        parse: (response) {
          final confirmation = BuyerReceiptConfirmation.fromResponse(response);
          if (confirmation.orderId != orderId) {
            throw const BuyerCheckoutFormatException('data.order_id');
          }
          return confirmation;
        },
      );
    } on BuyerCheckoutFormatException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
      );
    }
  }

  Future<T> _authenticated<T>(
    _BuyerContext buyer, {
    required AuthenticatedRequestMethod method,
    required String path,
    Map<String, Object?>? queryParameters,
    Object? body,
    required T Function(Object? response) parse,
  }) async {
    try {
      return await _authService.requestWithSession<T>(
        method: method,
        path: path,
        queryParameters: queryParameters,
        body: body,
        expectedSessionEpoch: buyer.epoch,
        expectedAccountId: buyer.accountId,
        parse: parse,
      );
    } on AuthSessionChangedException catch (error) {
      throw BuyerCheckoutException(
        BuyerCheckoutFailureCategory.sessionChanged,
        requestMayHaveReachedServer: error.requestMayHaveReachedServer,
      );
    } on AuthException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.noBuyerSession,
      );
    } on ApiHttpException catch (error) {
      throw BuyerCheckoutException(
        _categoryForHttp(error.statusCode),
        statusCode: error.statusCode,
        serverErrorCode: _safeServerCode(error.responseData),
        validationErrors: error.validationErrors,
        requestMayHaveReachedServer: error.statusCode >= 500,
      );
    } on ApiTimeoutException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.timeout,
        requestMayHaveReachedServer: true,
      );
    } on ApiTransportException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.connectivity,
        requestMayHaveReachedServer: true,
      );
    } on ApiFormatException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
        requestMayHaveReachedServer: true,
      );
    } on BuyerCheckoutFormatException {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
        requestMayHaveReachedServer: true,
      );
    }
  }

  _BuyerContext _requireBuyer() {
    final session = _authService.currentSession;
    if (session == null || session.role != AccountRole.buyer) {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.noBuyerSession,
      );
    }
    return _BuyerContext(session.id, _authService.sessionEpoch);
  }

  Future<BuyerCheckoutAttempt?> _readAttempt(int accountId) async {
    final cached = _cachedAttempts[accountId];
    if (cached?.status == BuyerCheckoutAttemptStatus.succeeded) return cached;
    final attempt = await _attemptStore.read(accountId);
    if (attempt != null && attempt.buyerAccountId != accountId) {
      throw const BuyerCheckoutAttemptStorageException();
    }
    if (attempt != null) _cachedAttempts[accountId] = attempt;
    return attempt;
  }

  Future<void> _writeAttempt(BuyerCheckoutAttempt attempt) async {
    await _attemptStore.write(attempt);
    _cachedAttempts[attempt.buyerAccountId] = attempt;
  }

  void _enterAttemptOperation(int accountId) {
    if (!_activeAttemptOperations.add(accountId)) {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.unresolvedAttempt,
      );
    }
  }

  void _leaveAttemptOperation(int accountId) =>
      _activeAttemptOperations.remove(accountId);

  static void _validateOrderId(int orderId) {
    if (orderId < 1) {
      throw const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.invalidRequest,
      );
    }
  }

  static BuyerCheckoutFailureCategory _categoryForHttp(int status) =>
      switch (status) {
        401 => BuyerCheckoutFailureCategory.noBuyerSession,
        403 => BuyerCheckoutFailureCategory.client,
        404 => BuyerCheckoutFailureCategory.notFound,
        409 => BuyerCheckoutFailureCategory.conflict,
        422 => BuyerCheckoutFailureCategory.validation,
        429 => BuyerCheckoutFailureCategory.rateLimited,
        >= 500 => BuyerCheckoutFailureCategory.server,
        _ => BuyerCheckoutFailureCategory.client,
      };

  static String? _safeServerCode(Object? value) {
    if (value is! Map) {
      return null;
    }
    Object? code = value['code'];
    if (code == null && value['error'] is Map) {
      code = (value['error'] as Map)['code'];
    }
    if (code == null && value['data'] is Map) {
      code = (value['data'] as Map)['code'];
    }
    if (code is! String ||
        code.length > 80 ||
        !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(code)) {
      return null;
    }
    return code;
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class _BuyerContext {
  const _BuyerContext(this.accountId, this.epoch);
  final int accountId;
  final int epoch;
}
