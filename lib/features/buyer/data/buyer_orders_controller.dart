import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_order_models.dart';
import 'buyer_checkout_repository.dart';

/// Owns only the read-only, paginated Buyer order-history state.
class BuyerOrdersController extends ChangeNotifier {
  BuyerOrdersController({
    required AuthService authService,
    required BuyerCheckoutRepository checkoutRepository,
  }) : _authService = authService,
       _checkoutRepository = checkoutRepository {
    _ownerBuyerId = _activeBuyerId;
    _ownerSessionEpoch = authService.sessionEpoch;
    _authService.addListener(_onAuthChanged);
  }

  static const int pageSize = 20;

  final AuthService _authService;
  final BuyerCheckoutRepository _checkoutRepository;

  int? _ownerBuyerId;
  late int _ownerSessionEpoch;
  int _sessionGeneration = 0;
  int _requestGeneration = 0;
  List<BuyerOrderSummary> _orders = const [];
  BuyerOrderPagination? _pagination;
  Object? _error;
  Object? _loadMoreError;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _isActive = false;

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  List<BuyerOrderSummary> get orders => List.unmodifiable(_orders);
  BuyerOrderPagination? get pagination => _pagination;
  Object? get error => _error;
  Object? get loadMoreError => _loadMoreError;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoaded => _hasLoaded;
  bool get hasBuyerSession => _activeBuyerId != null;
  bool get hasMore => _pagination?.hasMore ?? false;

  void setActive(bool value) {
    if (_isActive == value) return;
    _isActive = value;
    if (value && !_hasLoaded) unawaited(refresh());
  }

  Future<void> refresh() async {
    final buyerId = _activeBuyerId;
    if (buyerId == null) {
      _orders = const [];
      _pagination = null;
      _error = null;
      _loadMoreError = null;
      _hasLoaded = true;
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
      return;
    }

    final epoch = _authService.sessionEpoch;
    final sessionGeneration = _sessionGeneration;
    final requestGeneration = ++_requestGeneration;
    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    _loadMoreError = null;
    notifyListeners();

    try {
      final result = await _checkoutRepository.fetchOrderHistory(
        page: 1,
        perPage: pageSize,
      );
      if (!_isCurrent(buyerId, epoch, sessionGeneration, requestGeneration)) {
        return;
      }
      _orders = result.orders;
      _pagination = result.pagination;
      _hasLoaded = true;
    } on Object catch (error) {
      if (_isCurrent(buyerId, epoch, sessionGeneration, requestGeneration)) {
        _error = error;
        _hasLoaded = true;
      }
    } finally {
      if (_isCurrent(buyerId, epoch, sessionGeneration, requestGeneration)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadNextPage() async {
    final buyerId = _activeBuyerId;
    final currentPagination = _pagination;
    if (buyerId == null ||
        currentPagination == null ||
        !currentPagination.hasMore ||
        _isLoading ||
        _isLoadingMore) {
      return;
    }

    final epoch = _authService.sessionEpoch;
    final sessionGeneration = _sessionGeneration;
    final requestGeneration = ++_requestGeneration;
    final nextPage = currentPagination.currentPage + 1;
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final result = await _checkoutRepository.fetchOrderHistory(
        page: nextPage,
        perPage: pageSize,
      );
      if (!_isCurrent(buyerId, epoch, sessionGeneration, requestGeneration)) {
        return;
      }
      final ids = _orders.map((order) => order.id).toSet();
      _orders = List.unmodifiable([
        ..._orders,
        ...result.orders.where((order) => ids.add(order.id)),
      ]);
      _pagination = result.pagination;
    } on Object catch (error) {
      if (_isCurrent(buyerId, epoch, sessionGeneration, requestGeneration)) {
        _loadMoreError = error;
      }
    } finally {
      if (_isCurrent(buyerId, epoch, sessionGeneration, requestGeneration)) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(
    int buyerId,
    int epoch,
    int sessionGeneration,
    int requestGeneration,
  ) =>
      sessionGeneration == _sessionGeneration &&
      requestGeneration == _requestGeneration &&
      _activeBuyerId == buyerId &&
      _authService.sessionEpoch == epoch;

  void _onAuthChanged() {
    final buyerId = _activeBuyerId;
    final epoch = _authService.sessionEpoch;
    if (buyerId == _ownerBuyerId && epoch == _ownerSessionEpoch) return;

    _sessionGeneration++;
    _requestGeneration++;
    _ownerBuyerId = buyerId;
    _ownerSessionEpoch = epoch;
    _orders = const [];
    _pagination = null;
    _error = null;
    _loadMoreError = null;
    _isLoading = false;
    _isLoadingMore = false;
    _hasLoaded = buyerId == null;
    notifyListeners();

    if (_isActive && buyerId != null) unawaited(refresh());
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
