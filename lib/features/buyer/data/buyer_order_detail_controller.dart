import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_order_models.dart';
import '../models/buyer_tracking_models.dart';
import 'buyer_checkout_repository.dart';

/// Loads historical order snapshots and persisted shipment history for one
/// authenticated Buyer. A session change immediately erases the view state.
class BuyerOrderDetailController extends ChangeNotifier {
  BuyerOrderDetailController({
    required AuthService authService,
    required BuyerCheckoutRepository checkoutRepository,
    required this.orderId,
  }) : _authService = authService,
       _checkoutRepository = checkoutRepository {
    _ownerBuyerId = _activeBuyerId;
    _ownerSessionEpoch = authService.sessionEpoch;
    _authService.addListener(_onAuthChanged);
  }

  final AuthService _authService;
  final BuyerCheckoutRepository _checkoutRepository;
  final int orderId;

  int? _ownerBuyerId;
  late int _ownerSessionEpoch;
  int _generation = 0;
  bool _accountChanged = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;
  Object? _refreshError;
  BuyerOrderDetail? _detail;
  BuyerOrderTracking? _tracking;
  BuyerReceiptConfirmation? _receiptConfirmation;
  Object? _receiptError;
  bool _isCheckingReceiptEligibility = false;
  bool _isConfirmingReceipt = false;
  bool _confirmationOutcomeUnknown = false;
  bool _disposed = false;

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  BuyerOrderDetail? get detail => _detail;
  BuyerOrderTracking? get tracking => _tracking;
  Object? get error => _error;
  Object? get refreshError => _refreshError;
  Object? get receiptError => _receiptError;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get hasBuyerSession => _activeBuyerId != null;
  bool get accountChanged => _accountChanged;
  bool get isCheckingReceiptEligibility => _isCheckingReceiptEligibility;
  bool get isConfirmingReceipt => _isConfirmingReceipt;
  bool get confirmationOutcomeUnknown => _confirmationOutcomeUnknown;
  BuyerReceiptConfirmation? get receiptConfirmation => _receiptConfirmation;
  bool get receiptConfirmed =>
      _receiptConfirmation?.receiptConfirmed == true ||
      _detail?.buyerActions.receiptConfirmed == true;
  DateTime? get receiptCompletedAt =>
      _receiptConfirmation?.completedAt ??
      _detail?.buyerActions.receiptConfirmedAt;

  Future<void> load() async {
    if (_disposed || _isLoading || _accountChanged) return;
    final buyerId = _activeBuyerId;
    if (buyerId == null) {
      _detail = null;
      _tracking = null;
      _receiptConfirmation = null;
      _error = const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.noBuyerSession,
      );
      _hasLoaded = true;
      _notifyListeners();
      return;
    }
    if (orderId < 1) {
      _error = const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.invalidRequest,
      );
      _hasLoaded = true;
      _notifyListeners();
      return;
    }

    final epoch = _authService.sessionEpoch;
    final generation = ++_generation;
    final hadData = _detail != null && _tracking != null;
    _isLoading = true;
    _error = null;
    _refreshError = null;
    _notifyListeners();

    try {
      final values = await Future.wait<Object>([
        _checkoutRepository.fetchOrderDetail(orderId),
        _checkoutRepository.fetchTracking(orderId),
      ]);
      if (!_isCurrent(buyerId, epoch, generation)) return;
      final detail = values[0] as BuyerOrderDetail;
      final tracking = values[1] as BuyerOrderTracking;
      if (detail.id != orderId || tracking.orderId != orderId) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.malformedResponse,
        );
      }
      _detail = detail;
      _tracking = tracking;
      if (detail.buyerActions.receiptConfirmed) {
        _confirmationOutcomeUnknown = false;
      }
      _hasLoaded = true;
    } on Object catch (error) {
      if (_isCurrent(buyerId, epoch, generation)) {
        final mustDiscardPrivateData =
            error is BuyerCheckoutException &&
            (error.category == BuyerCheckoutFailureCategory.noBuyerSession ||
                error.category == BuyerCheckoutFailureCategory.sessionChanged ||
                error.category == BuyerCheckoutFailureCategory.notFound ||
                (error.category == BuyerCheckoutFailureCategory.client &&
                    error.statusCode == 403));
        if (mustDiscardPrivateData || !hadData) {
          _detail = null;
          _tracking = null;
          _error = error;
          _refreshError = null;
        } else {
          // Keep the last server snapshot visible on a transient refresh
          // failure. No order state is changed optimistically in this client.
          _refreshError = error;
        }
        _hasLoaded = true;
      }
    } finally {
      if (_isCurrent(buyerId, epoch, generation)) {
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  /// Re-fetches Buyer-owned order and tracking data immediately before the
  /// confirmation dialog. A stale or failed read can never enable the POST.
  Future<bool> refreshReceiptEligibility() async {
    if (_disposed ||
        _accountChanged ||
        _isLoading ||
        _isCheckingReceiptEligibility ||
        _isConfirmingReceipt ||
        !hasBuyerSession) {
      return false;
    }

    _isCheckingReceiptEligibility = true;
    _receiptError = null;
    _refreshError = null;
    _notifyListeners();
    try {
      await load();
      return !_disposed &&
          !_accountChanged &&
          !_isLoading &&
          _refreshError == null &&
          !receiptConfirmed &&
          _detail?.buyerActions.canConfirmReceipt == true;
    } finally {
      if (!_disposed) {
        _isCheckingReceiptEligibility = false;
        _notifyListeners();
      }
    }
  }

  /// Sends exactly one bodyless receipt-confirmation request for this order.
  /// On an ambiguous result, it performs only a read-only refresh.
  Future<BuyerReceiptConfirmation?> confirmReceipt() async {
    final buyerId = _activeBuyerId;
    if (_disposed ||
        buyerId == null ||
        _accountChanged ||
        _isLoading ||
        _isCheckingReceiptEligibility ||
        _isConfirmingReceipt ||
        receiptConfirmed ||
        _detail?.buyerActions.canConfirmReceipt != true) {
      return null;
    }

    final epoch = _authService.sessionEpoch;
    _isConfirmingReceipt = true;
    _receiptError = null;
    _confirmationOutcomeUnknown = false;
    _notifyListeners();

    BuyerReceiptConfirmation? result;
    var refreshAfterRequest = false;
    try {
      final response = await _checkoutRepository.confirmReceipt(orderId);
      if (!_isSessionCurrent(buyerId, epoch)) return null;
      if (!response.receiptConfirmed) {
        throw const BuyerCheckoutException(
          BuyerCheckoutFailureCategory.malformedResponse,
          requestMayHaveReachedServer: true,
        );
      }
      // The POST response is authoritative. Keep its statuses and original
      // completed_at visible even if the follow-up GET is temporarily stale.
      _receiptConfirmation = response;
      _receiptError = null;
      _confirmationOutcomeUnknown = false;
      result = response;
      refreshAfterRequest = true;
    } on BuyerCheckoutException catch (error) {
      if (!_isSessionCurrent(buyerId, epoch)) return null;
      _receiptError = error;
      if (_mayHaveReachedServer(error)) {
        _confirmationOutcomeUnknown = true;
        refreshAfterRequest = true;
      } else {
        refreshAfterRequest =
            error.category != BuyerCheckoutFailureCategory.rateLimited;
      }
    } on Object catch (_) {
      if (!_isSessionCurrent(buyerId, epoch)) return null;
      _receiptError = const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.malformedResponse,
        requestMayHaveReachedServer: true,
      );
      _confirmationOutcomeUnknown = true;
      refreshAfterRequest = true;
    } finally {
      if (_isSessionCurrent(buyerId, epoch)) {
        _isConfirmingReceipt = false;
        _notifyListeners();
        if (refreshAfterRequest) await load();
      }
    }
    return result;
  }

  bool _mayHaveReachedServer(BuyerCheckoutException error) =>
      error.requestMayHaveReachedServer ||
      error.category == BuyerCheckoutFailureCategory.timeout ||
      error.category == BuyerCheckoutFailureCategory.connectivity ||
      error.category == BuyerCheckoutFailureCategory.malformedResponse;

  bool _isSessionCurrent(int buyerId, int epoch) =>
      !_disposed &&
      !_accountChanged &&
      _activeBuyerId == buyerId &&
      _authService.sessionEpoch == epoch;

  bool _isCurrent(int buyerId, int epoch, int generation) =>
      generation == _generation &&
      _activeBuyerId == buyerId &&
      _authService.sessionEpoch == epoch;

  void _onAuthChanged() {
    final buyerId = _activeBuyerId;
    final epoch = _authService.sessionEpoch;
    if (buyerId == _ownerBuyerId && epoch == _ownerSessionEpoch) return;

    _generation++;
    _ownerBuyerId = buyerId;
    _ownerSessionEpoch = epoch;
    _accountChanged = true;
    _detail = null;
    _tracking = null;
    _error = null;
    _refreshError = null;
    _receiptConfirmation = null;
    _receiptError = null;
    _isCheckingReceiptEligibility = false;
    _isConfirmingReceipt = false;
    _confirmationOutcomeUnknown = false;
    _isLoading = false;
    _hasLoaded = true;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
