import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_checkout_attempt.dart';
import '../models/buyer_checkout_models.dart';
import '../models/buyer_order_models.dart';
import 'buyer_cart_controller.dart';
import 'buyer_checkout_repository.dart';

/// Coordinates Checkout Review placement and secure recovery presentation.
/// The repository remains the only owner of placement requests and attempts.
class BuyerCheckoutPlacementController extends ChangeNotifier {
  BuyerCheckoutPlacementController({
    required AuthService authService,
    required BuyerCheckoutRepository checkoutRepository,
    required BuyerCartController cartController,
    DateTime Function()? clock,
  }) : _authService = authService,
       _checkoutRepository = checkoutRepository,
       _cartController = cartController,
       _clock = clock ?? DateTime.now {
    _ownerAccountId = _activeBuyerId;
    _ownerSessionEpoch = authService.sessionEpoch;
    _authService.addListener(_onAuthChanged);
  }

  final AuthService _authService;
  final BuyerCheckoutRepository _checkoutRepository;
  final BuyerCartController _cartController;
  final DateTime Function() _clock;

  BuyerCheckoutAttempt? _attempt;
  BuyerPlacedOrder? _confirmedOrder;
  int? _confirmedBuyerId;
  int? _ownerAccountId;
  late int _ownerSessionEpoch;
  Object? _attemptLoadError;
  BuyerCheckoutException? _actionError;
  bool _isInitializing = false;
  bool _attemptCheckComplete = false;
  bool _isSubmitting = false;
  bool _isRefreshingCart = false;
  bool _cartRefreshFailed = false;
  int _sessionGeneration = 0;

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  BuyerCheckoutAttempt? get attempt {
    final currentId = _activeBuyerId;
    return currentId != null && _attempt?.buyerAccountId == currentId
        ? _attempt
        : null;
  }

  BuyerPlacedOrder? get confirmedOrder {
    final currentId = _activeBuyerId;
    if (currentId == null || currentId != _confirmedBuyerId) return null;
    return _confirmedOrder ??
        (attempt?.status == BuyerCheckoutAttemptStatus.succeeded
            ? attempt?.result
            : null);
  }

  Object? get attemptLoadError => _attemptLoadError;
  BuyerCheckoutException? get actionError => _actionError;
  bool get isInitializing => _isInitializing;
  bool get isSubmitting => _isSubmitting;
  bool get isRefreshingCart => _isRefreshingCart;
  bool get cartRefreshFailed => _cartRefreshFailed;
  bool get attemptCheckComplete => _attemptCheckComplete;
  int get sessionGeneration => _sessionGeneration;
  bool get canShowCheckoutReview =>
      _attemptCheckComplete &&
      _attemptLoadError == null &&
      _activeBuyerId != null &&
      attempt == null &&
      confirmedOrder == null;

  bool get canRetryOriginalRequest {
    final current = attempt;
    return !_isSubmitting &&
        current != null &&
        (current.status == BuyerCheckoutAttemptStatus.indeterminate ||
            (current.status == BuyerCheckoutAttemptStatus.succeeded &&
                current.result == null));
  }

  bool get hasUnsubmittedAttempt =>
      attempt?.status == BuyerCheckoutAttemptStatus.ready;

  bool get canStartFreshCheckoutAfterRejection {
    final current = attempt;
    return !_isSubmitting &&
        current?.status == BuyerCheckoutAttemptStatus.rejected &&
        !_isConflict(current!);
  }

  bool get hasUnresolvedConflict => _isConflict(attempt);

  bool canPlaceOrder(BuyerCheckoutQuote? quote) {
    final buyerId = _activeBuyerId;
    return buyerId != null &&
        _attemptCheckComplete &&
        _attemptLoadError == null &&
        !_isSubmitting &&
        attempt == null &&
        confirmedOrder == null &&
        quote != null &&
        quote.buyerAccountId == buyerId &&
        quote.paymentMethod == 'cod' &&
        quote.availablePaymentMethods.contains('cod') &&
        quote.quoteExpiresAt.isAfter(_clock());
  }

  /// Checks the encrypted, current-Buyer record before Review may request a
  /// quote. Restoring a record never submits it.
  Future<void> initialize({bool force = false}) async {
    if (_isInitializing) return;
    if (_attemptCheckComplete && !force) return;

    final buyerId = _activeBuyerId;
    if (buyerId == null) {
      _attemptLoadError = const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.noBuyerSession,
      );
      _attemptCheckComplete = true;
      notifyListeners();
      return;
    }

    final epoch = _authService.sessionEpoch;
    final generation = ++_sessionGeneration;
    _ownerAccountId = buyerId;
    _ownerSessionEpoch = epoch;
    _attemptLoadError = null;
    _actionError = null;
    _isInitializing = true;
    _attemptCheckComplete = false;
    notifyListeners();

    try {
      final restored = await _checkoutRepository.restorePlacementAttempt();
      if (!_isCurrentSession(buyerId, epoch, generation)) {
        return;
      }
      _attempt = restored;
      if (restored?.status == BuyerCheckoutAttemptStatus.succeeded) {
        _confirmedOrder = restored?.result;
        _confirmedBuyerId = buyerId;
      }
      _attemptCheckComplete = true;
      if (confirmedOrder != null) {
        await _refreshCartAfterSuccess(buyerId, epoch);
      }
    } on Object catch (error) {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _attemptLoadError = error;
        _attemptCheckComplete = true;
      }
    } finally {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _isInitializing = false;
        notifyListeners();
      }
    }
  }

  /// Persists the immutable request through M4B before allowing its POST.
  Future<void> placeOrder(BuyerCheckoutQuote quote) async {
    if (!canPlaceOrder(quote)) return;
    final buyerId = _activeBuyerId!;
    final epoch = _authService.sessionEpoch;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _actionError = null;
    notifyListeners();

    try {
      final persisted = await _checkoutRepository.beginPlacementAttempt(
        quote: quote,
      );
      if (!_isCurrentSession(buyerId, epoch, generation)) return;
      _attempt = persisted;
      notifyListeners();
      await _submitPersistedAttempt(buyerId, epoch, generation);
    } on BuyerCheckoutException catch (error) {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        await _handlePlacementFailure(error, buyerId, epoch, generation);
      }
    } on Object {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        await _handlePlacementFailure(
          const BuyerCheckoutException(
            BuyerCheckoutFailureCategory.secureStorage,
          ),
          buyerId,
          epoch,
          generation,
        );
      }
    } finally {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  /// Sends only the exact request already stored for this Buyer.
  Future<void> retryOriginalRequest() async {
    if (!canRetryOriginalRequest) return;
    final buyerId = _activeBuyerId!;
    final epoch = _authService.sessionEpoch;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _actionError = null;
    notifyListeners();
    try {
      await _submitPersistedAttempt(buyerId, epoch, generation);
    } on BuyerCheckoutException catch (error) {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        await _handlePlacementFailure(error, buyerId, epoch, generation);
      }
    } on Object {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        await _handlePlacementFailure(
          const BuyerCheckoutException(
            BuyerCheckoutFailureCategory.server,
            requestMayHaveReachedServer: true,
          ),
          buyerId,
          epoch,
          generation,
        );
      }
    } finally {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  Future<void> _submitPersistedAttempt(
    int buyerId,
    int epoch,
    int generation,
  ) async {
    try {
      final order = await _checkoutRepository.submitPlacementAttempt();
      if (!_isCurrentSession(buyerId, epoch, generation)) return;
      _attempt = await _checkoutRepository.restorePlacementAttempt();
      _confirmedOrder = order;
      _confirmedBuyerId = buyerId;
      _actionError = null;
      _attemptLoadError = null;
      _attemptCheckComplete = true;
      notifyListeners();
      await _refreshCartAfterSuccess(buyerId, epoch);
    } on BuyerCheckoutException {
      rethrow;
    }
  }

  Future<void> _handlePlacementFailure(
    BuyerCheckoutException error,
    int buyerId,
    int epoch,
    int generation,
  ) async {
    _actionError = error;
    try {
      final restored = await _checkoutRepository.restorePlacementAttempt();
      if (!_isCurrentSession(buyerId, epoch, generation)) return;
      _attempt = restored;
      if (restored?.status == BuyerCheckoutAttemptStatus.succeeded) {
        _confirmedOrder = restored?.result;
        _confirmedBuyerId = buyerId;
        await _refreshCartAfterSuccess(buyerId, epoch);
      }
    } on Object catch (storageError) {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _attemptLoadError = storageError;
        _attemptCheckComplete = true;
      }
    }
    if (_isCurrentSession(buyerId, epoch, generation)) notifyListeners();
  }

  Future<void> _refreshCartAfterSuccess(int buyerId, int epoch) async {
    _isRefreshingCart = true;
    _cartRefreshFailed = false;
    notifyListeners();
    try {
      await _cartController.refresh(force: true);
      if (_isCurrentSession(buyerId, epoch, _sessionGeneration)) {
        _cartRefreshFailed = _cartController.loadError != null;
      }
    } on Object {
      if (_isCurrentSession(buyerId, epoch, _sessionGeneration)) {
        _cartRefreshFailed = true;
      }
    } finally {
      if (_isCurrentSession(buyerId, epoch, _sessionGeneration)) {
        _isRefreshingCart = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshCart() async {
    final buyerId = _activeBuyerId;
    if (buyerId == null || confirmedOrder == null || _isRefreshingCart) return;
    await _refreshCartAfterSuccess(buyerId, _authService.sessionEpoch);
  }

  /// Discard is permitted only for `ready`, which proves the placement POST
  /// never started. The caller then deliberately obtains a fresh quote.
  Future<void> discardUnsubmittedAttempt() async {
    if (!hasUnsubmittedAttempt || _isSubmitting) return;
    final buyerId = _activeBuyerId!;
    final epoch = _authService.sessionEpoch;
    final generation = _sessionGeneration;
    try {
      await _checkoutRepository.clearUnsubmittedPlacementAttempt();
      if (!_isCurrentSession(buyerId, epoch, generation)) return;
      _attempt = null;
      _actionError = null;
      _attemptCheckComplete = true;
      notifyListeners();
    } on BuyerCheckoutException catch (error) {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _actionError = error;
        notifyListeners();
      }
    }
  }

  /// A definitive HTTP rejection can be cleared only after the Buyer chooses
  /// to review the Cart and request a new quote. A 409 key conflict is kept.
  Future<void> clearDefinitiveRejection() async {
    if (!canStartFreshCheckoutAfterRejection) return;
    final buyerId = _activeBuyerId!;
    final epoch = _authService.sessionEpoch;
    final generation = _sessionGeneration;
    try {
      await _checkoutRepository.clearResolvedPlacementAttempt();
      if (!_isCurrentSession(buyerId, epoch, generation)) return;
      _attempt = null;
      _actionError = null;
      _attemptCheckComplete = true;
      notifyListeners();
    } on BuyerCheckoutException catch (error) {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _actionError = error;
        notifyListeners();
      }
    }
  }

  /// Acknowledges the authoritative result before the UI leaves checkout.
  Future<bool> acknowledgeSuccess() async {
    final order = confirmedOrder;
    if (order == null || _isSubmitting) return false;
    final buyerId = _activeBuyerId!;
    final epoch = _authService.sessionEpoch;
    final generation = _sessionGeneration;
    try {
      await _checkoutRepository.clearResolvedPlacementAttempt();
      if (!_isCurrentSession(buyerId, epoch, generation)) return false;
      _attempt = null;
      _confirmedOrder = order;
      _confirmedBuyerId = buyerId;
      _actionError = null;
      notifyListeners();
      return true;
    } on BuyerCheckoutException catch (error) {
      if (_isCurrentSession(buyerId, epoch, generation)) {
        _actionError = error;
        notifyListeners();
      }
      return false;
    }
  }

  String messageFor(BuyerCheckoutException error) {
    final validation = error.validationErrors.values
        .expand((messages) => messages)
        .where((message) => message.trim().isNotEmpty)
        .firstOrNull;
    if (validation != null) {
      return validation.length > 200
          ? '${validation.substring(0, 197)}…'
          : validation;
    }
    return switch (error.category) {
      BuyerCheckoutFailureCategory.noBuyerSession =>
        'Sign in with an eligible Buyer account to continue checkout.',
      BuyerCheckoutFailureCategory.sessionChanged =>
        'Your Buyer account changed. The saved attempt remains with its original account.',
      BuyerCheckoutFailureCategory.invalidRequest =>
        'Review the selected Cart items and delivery address, then request a current quote.',
      BuyerCheckoutFailureCategory.notFound =>
        'A selected Cart item or delivery address is no longer available. Review the Cart and quote again.',
      BuyerCheckoutFailureCategory.conflict =>
        'Bearly returned checkout_request_conflict. This saved attempt is being kept because the server has a different or unverifiable request under this key. Contact support before starting another order.',
      BuyerCheckoutFailureCategory.validation =>
        'Bearly rejected this checkout. Review the Cart and request a fresh quote before trying again.',
      BuyerCheckoutFailureCategory.rateLimited =>
        'Bearly is receiving too many checkout requests. Wait a moment, then review and request a fresh quote.',
      BuyerCheckoutFailureCategory.server =>
        'Bearly could not confirm whether the order was created. Keep this attempt and retry the original request when ready.',
      BuyerCheckoutFailureCategory.timeout ||
      BuyerCheckoutFailureCategory.connectivity =>
        'We could not confirm whether the order was created. Keep this attempt and retry the original request when ready.',
      BuyerCheckoutFailureCategory.malformedResponse =>
        'Bearly may have created the order, but its response could not be verified. Retry only the original request.',
      BuyerCheckoutFailureCategory.secureStorage =>
        'Secure checkout recovery is unavailable. No new order request will be sent until its recovery record can be saved.',
      BuyerCheckoutFailureCategory.unresolvedAttempt =>
        'An earlier checkout attempt still needs review before another order can be placed.',
      BuyerCheckoutFailureCategory.rejectedAttempt =>
        'Bearly rejected this attempt. Review the response, then request a fresh quote before trying again.',
      BuyerCheckoutFailureCategory.expiredQuote =>
        'This quote expired before it could be sent. Request a fresh quote to continue.',
      BuyerCheckoutFailureCategory.client =>
        'Bearly rejected the checkout request. Review the Cart and address before continuing.',
    };
  }

  Future<void> _onAuthChanged() async {
    final buyerId = _activeBuyerId;
    final epoch = _authService.sessionEpoch;
    if (buyerId == _ownerAccountId && epoch == _ownerSessionEpoch) return;

    _sessionGeneration++;
    _ownerAccountId = buyerId;
    _ownerSessionEpoch = epoch;
    _attempt = null;
    _confirmedOrder = null;
    _confirmedBuyerId = null;
    _actionError = null;
    _attemptLoadError = buyerId == null
        ? const BuyerCheckoutException(
            BuyerCheckoutFailureCategory.noBuyerSession,
          )
        : null;
    _isSubmitting = false;
    _isRefreshingCart = false;
    _cartRefreshFailed = false;
    _attemptCheckComplete = buyerId == null;
    _cartController.synchronizeSession();
    notifyListeners();
    if (buyerId != null) await initialize(force: true);
  }

  bool _isCurrentSession(int buyerId, int epoch, int generation) =>
      generation == _sessionGeneration &&
      _activeBuyerId == buyerId &&
      _authService.sessionEpoch == epoch;

  static bool _isConflict(BuyerCheckoutAttempt? attempt) =>
      attempt != null &&
      (attempt.failureCategory == BuyerCheckoutFailureCategory.conflict.name ||
          attempt.serverErrorCode == 'checkout_request_conflict');

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
