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
  BuyerOrderDetail? _detail;
  BuyerOrderTracking? _tracking;

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  BuyerOrderDetail? get detail => _detail;
  BuyerOrderTracking? get tracking => _tracking;
  Object? get error => _error;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get hasBuyerSession => _activeBuyerId != null;
  bool get accountChanged => _accountChanged;

  Future<void> load() async {
    if (_isLoading || _accountChanged) return;
    final buyerId = _activeBuyerId;
    if (buyerId == null) {
      _detail = null;
      _tracking = null;
      _error = const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.noBuyerSession,
      );
      _hasLoaded = true;
      notifyListeners();
      return;
    }
    if (orderId < 1) {
      _error = const BuyerCheckoutException(
        BuyerCheckoutFailureCategory.invalidRequest,
      );
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    final epoch = _authService.sessionEpoch;
    final generation = ++_generation;
    _isLoading = true;
    _error = null;
    notifyListeners();

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
      _hasLoaded = true;
    } on Object catch (error) {
      if (_isCurrent(buyerId, epoch, generation)) {
        _detail = null;
        _tracking = null;
        _error = error;
        _hasLoaded = true;
      }
    } finally {
      if (_isCurrent(buyerId, epoch, generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

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
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
