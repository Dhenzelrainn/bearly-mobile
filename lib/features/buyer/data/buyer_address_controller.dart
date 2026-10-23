import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_shopping_models.dart';
import 'buyer_address_repository.dart';

/// In-memory address state for the currently authenticated Buyer.
/// Laravel remains the source of truth for address and default status.
class BuyerAddressController extends ChangeNotifier {
  BuyerAddressController({
    required AuthService authService,
    BuyerAddressRepository? repository,
  }) : _authService = authService,
       _repository =
           repository ?? BuyerAddressRepository(authService: authService) {
    _ownerAccountId = _activeBuyerId;
  }

  final AuthService _authService;
  final BuyerAddressRepository _repository;

  List<BuyerAddress>? _addresses;
  Object? _loadError;
  int? _ownerAccountId;
  int? _pendingAddressId;
  int _loadSequence = 0;
  int _mutationSequence = 0;
  int? _activeMutation;
  bool _isLoading = false;
  bool _disposed = false;

  List<BuyerAddress>? get addresses => _addresses;
  Object? get loadError => _loadError;
  int? get pendingAddressId => _pendingAddressId;
  bool get isLoading => _isLoading;
  bool get isMutating => _activeMutation != null;

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  bool synchronizeSession() {
    final nextOwner = _activeBuyerId;
    if (nextOwner == _ownerAccountId) return false;
    _ownerAccountId = nextOwner;
    _resetState();
    _notify();
    return true;
  }

  void clear() {
    _ownerAccountId = null;
    _resetState();
    _notify();
  }

  void _resetState() {
    _addresses = null;
    _loadError = null;
    _isLoading = false;
    _pendingAddressId = null;
    _activeMutation = null;
    _loadSequence++;
    _mutationSequence++;
  }

  Future<void> refresh({bool force = false}) async {
    synchronizeSession();
    final owner = _ownerAccountId;
    if (owner == null) {
      _addresses = null;
      _loadError = const AuthException(
        'Sign in with a Buyer account to manage delivery addresses.',
      );
      _isLoading = false;
      _notify();
      return;
    }
    if (_isLoading || isMutating || (!force && _addresses != null)) return;
    await _loadForOwner(owner);
  }

  Future<BuyerAddress> createAddress(BuyerAddressCreate address) => _mutate(
    pendingAddressId: null,
    request: () => _repository.createAddress(address),
  );

  Future<BuyerAddress> updateAddress({
    required int addressId,
    required BuyerAddressPatch changes,
  }) => _mutate(
    pendingAddressId: addressId,
    request: () =>
        _repository.updateAddress(addressId: addressId, changes: changes),
  );

  Future<void> setDefaultAddress(int addressId) async {
    if (addressId < 1) throw RangeError.value(addressId, 'addressId');
    final current = _addresses;
    if (current?.any(
          (address) => address.id == addressId && address.isDefault,
        ) ==
        true) {
      return;
    }
    await _mutate(
      pendingAddressId: addressId,
      request: () => _repository.setDefaultAddress(addressId),
    );
  }

  Future<void> deleteAddress(int addressId) async {
    if (addressId < 1) throw RangeError.value(addressId, 'addressId');
    await _mutate<void>(
      pendingAddressId: addressId,
      request: () async {
        await _repository.deleteAddress(addressId);
      },
    );
  }

  Future<T> _mutate<T>({
    required int? pendingAddressId,
    required Future<T> Function() request,
  }) async {
    synchronizeSession();
    final owner = _ownerAccountId;
    if (owner == null) {
      throw const AuthException(
        'Sign in with a Buyer account to update delivery addresses.',
      );
    }
    if (isMutating || _isLoading) {
      throw StateError('An address request is already in progress.');
    }

    final operation = ++_mutationSequence;
    _activeMutation = operation;
    _pendingAddressId = pendingAddressId;
    _loadError = null;
    _loadSequence++;
    _notify();

    try {
      final result = await request();
      if (_isCurrent(owner) && _activeMutation == operation) {
        // The server has changed data; discard the prior snapshot before
        // refreshing so the UI can never present competing default badges.
        _addresses = null;
        _loadError = null;
        _notify();
        await _loadForOwner(owner);
      }
      return result;
    } catch (_) {
      if (!_isCurrent(owner)) synchronizeSession();
      rethrow;
    } finally {
      if (_activeMutation == operation) {
        _activeMutation = null;
        _pendingAddressId = null;
        _notify();
      }
    }
  }

  Future<void> _loadForOwner(int owner) async {
    final sequence = ++_loadSequence;
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      final result = await _repository.fetchAddresses();
      if (_isCurrent(owner) && sequence == _loadSequence) {
        _addresses = List.unmodifiable(result);
        _loadError = null;
      }
    } catch (error) {
      if (sequence != _loadSequence) return;
      if (!_isCurrent(owner)) {
        synchronizeSession();
        return;
      }
      _addresses = null;
      _loadError = error;
    } finally {
      if (sequence == _loadSequence) {
        _isLoading = false;
        _notify();
      }
    }
  }

  bool _isCurrent(int owner) =>
      !_disposed && _ownerAccountId == owner && _activeBuyerId == owner;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String buyerAddressErrorMessage(Object error) {
  if (error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403))) {
    return 'Your session needs attention. Sign in again to manage addresses.';
  }
  if (error is ApiTimeoutException) {
    return 'The address request timed out. Refresh to confirm the latest data.';
  }
  if (error is ApiTransportException) {
    return 'We could not reach Bearly. Check your connection and try again.';
  }
  if (error is ApiHttpException) {
    return switch (error.statusCode) {
      404 => 'This address is no longer available. Refresh the list.',
      409 => 'Your addresses changed on the server. Refresh and try again.',
      422 => 'Review the address details and try again.',
      429 => 'Too many address requests. Wait a moment and try again.',
      >= 500 => 'Bearly could not update addresses. Try again shortly.',
      _ => 'Bearly rejected this address request. Please try again.',
    };
  }
  return 'We could not manage delivery addresses. Please try again.';
}
