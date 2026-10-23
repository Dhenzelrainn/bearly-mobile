import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_shopping_models.dart';
import 'buyer_cart_repository.dart';

/// In-memory presentation state shared by Buyer screens for the active account.
/// Laravel remains the only source of cart contents, quantities, and totals.
class BuyerCartController extends ChangeNotifier {
  BuyerCartController({
    required AuthService authService,
    BuyerCartRepository? repository,
  }) : _authService = authService,
       _repository =
           repository ?? BuyerCartRepository(authService: authService) {
    _ownerAccountId = _activeBuyerId;
  }

  final AuthService _authService;
  final BuyerCartRepository _repository;

  BuyerCart? _cart;
  Object? _loadError;
  Object? _mutationError;
  int? _ownerAccountId;
  int? _pendingCartItemId;
  int _loadSequence = 0;
  int _mutationSequence = 0;
  int? _activeMutation;
  bool _isLoading = false;

  BuyerCart? get cart => _cart;
  Object? get loadError => _loadError;
  Object? get mutationError => _mutationError;
  int? get pendingCartItemId => _pendingCartItemId;
  bool get isLoading => _isLoading;
  bool get isMutating => _activeMutation != null;

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  /// Clears cached presentation data when the signed-in Buyer changes or logs
  /// out. The cache is never persisted on the device.
  bool synchronizeSession() {
    final nextOwner = _activeBuyerId;
    if (nextOwner == _ownerAccountId) return false;

    _ownerAccountId = nextOwner;
    _cart = null;
    _loadError = null;
    _mutationError = null;
    _isLoading = false;
    _pendingCartItemId = null;
    _activeMutation = null;
    _loadSequence++;
    _mutationSequence++;
    notifyListeners();
    return true;
  }

  void clear() {
    _ownerAccountId = null;
    _cart = null;
    _loadError = null;
    _mutationError = null;
    _isLoading = false;
    _pendingCartItemId = null;
    _activeMutation = null;
    _loadSequence++;
    _mutationSequence++;
    notifyListeners();
  }

  Future<void> refresh({bool force = false}) async {
    synchronizeSession();
    final owner = _ownerAccountId;
    if (owner == null) {
      _loadError = const AuthException(
        'Sign in with a Buyer account to view your cart.',
      );
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (_isLoading || isMutating || (!force && _cart != null)) return;

    final sequence = ++_loadSequence;
    final mutationSequence = _mutationSequence;
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final result = await _repository.fetchCart();
      if (!_isCurrent(owner) ||
          sequence != _loadSequence ||
          mutationSequence != _mutationSequence) {
        return;
      }
      _cart = result;
      _loadError = null;
    } catch (error) {
      if (sequence != _loadSequence) return;
      if (!_isCurrent(owner)) synchronizeSession();
      _loadError = error;
      notifyListeners();
    } finally {
      if (sequence == _loadSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<BuyerCart> addItem({
    required int productVariantId,
    required int quantity,
  }) => _mutate(
    pendingItemId: null,
    request: () => _repository.addItem(
      productVariantId: productVariantId,
      quantity: quantity,
    ),
  );

  Future<BuyerCart> updateQuantity({
    required int cartItemId,
    required int quantity,
  }) => _mutate(
    pendingItemId: cartItemId,
    request: () =>
        _repository.updateQuantity(cartItemId: cartItemId, quantity: quantity),
  );

  Future<BuyerCart> removeItem(int cartItemId) => _mutate(
    pendingItemId: cartItemId,
    request: () => _repository.removeItem(cartItemId),
  );

  Future<BuyerCart> _mutate({
    required int? pendingItemId,
    required Future<BuyerCart> Function() request,
  }) async {
    synchronizeSession();
    final owner = _ownerAccountId;
    if (owner == null) {
      throw const AuthException(
        'Sign in with a Buyer account to update your cart.',
      );
    }
    if (isMutating) {
      throw StateError('A cart request is already in progress.');
    }

    final operation = ++_mutationSequence;
    _activeMutation = operation;
    _pendingCartItemId = pendingItemId;
    _mutationError = null;
    _loadSequence++;
    notifyListeners();

    try {
      final result = await request();
      if (_isCurrent(owner) && _activeMutation == operation) {
        _cart = result;
        _loadError = null;
        _mutationError = null;
      }
      return result;
    } catch (error) {
      final ownerIsCurrent = _isCurrent(owner);
      if (!ownerIsCurrent) synchronizeSession();
      if (_activeBuyerId == null) {
        _loadError = error;
        _mutationError = error;
      } else if (ownerIsCurrent) {
        _mutationError = error;
      }
      rethrow;
    } finally {
      if (_activeMutation == operation) {
        _activeMutation = null;
        _pendingCartItemId = null;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int owner) =>
      _ownerAccountId == owner && _activeBuyerId == owner;
}

/// Maps transport and API errors to safe, short Buyer-facing messages.
String buyerCartErrorMessage(Object error) {
  if (error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403))) {
    return 'Your session needs attention. Sign in again to use your cart.';
  }
  if (error is ApiTimeoutException) {
    return 'The request timed out. Refresh your cart to confirm its latest state.';
  }
  if (error is ApiTransportException) {
    return 'We could not reach Bearly. Check your connection and try again.';
  }
  if (error is ApiHttpException) {
    return switch (error.statusCode) {
      404 =>
        'This product or cart item is no longer available. Refresh your cart.',
      409 => 'Your cart changed on the server. Refresh and try again.',
      422 => _validationMessage(error),
      429 => 'Too many requests. Please wait a moment and try again.',
      >= 500 => 'Bearly could not update your cart. Try again shortly.',
      _ => 'Bearly rejected this cart request. Review it and try again.',
    };
  }
  return 'We could not update your cart. Please try again.';
}

String _validationMessage(ApiHttpException error) {
  final messages = error.validationErrors.values.expand((items) => items);
  for (final message in messages) {
    if (RegExp(
      r'^Only \d+ item\(s\) are currently available\.$',
    ).hasMatch(message)) {
      return message;
    }
  }
  return 'The selected variant or quantity is no longer available. Review it and try again.';
}
