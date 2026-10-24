import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_checkout_models.dart';
import '../models/buyer_shopping_models.dart';
import 'buyer_address_controller.dart';
import 'buyer_cart_controller.dart';
import 'buyer_checkout_repository.dart';

/// Coordinates the temporary, in-memory selection used by checkout review.
/// Laravel remains authoritative for the quote; no placement attempt is read,
/// created, changed, or cleared by this controller.
class BuyerCheckoutReviewController extends ChangeNotifier {
  BuyerCheckoutReviewController({
    required AuthService authService,
    required this.cartController,
    required this.addressController,
    required BuyerCheckoutRepository checkoutRepository,
    DateTime Function()? clock,
  }) : _authService = authService,
       _checkoutRepository = checkoutRepository,
       _clock = clock ?? DateTime.now {
    _observedSessionKey = _sessionKey;
    _lastContextFingerprint = _contextFingerprint;
    cartController.addListener(_onDependencyChanged);
    addressController.addListener(_onDependencyChanged);
  }

  final AuthService _authService;
  final BuyerCheckoutRepository _checkoutRepository;
  final DateTime Function() _clock;
  final BuyerCartController cartController;
  final BuyerAddressController addressController;

  int? _selectedAddressId;
  BuyerCheckoutQuote? _quote;
  String? _quoteContextFingerprint;
  Object? _quoteError;
  String? _localError;
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _isQuoting = false;
  bool _isQuoteExpired = false;
  bool _addressSelectionResolved = false;
  int _lastAddressCount = 0;
  int _quoteSequence = 0;
  String? _observedSessionKey;
  late String _lastContextFingerprint;
  Timer? _quoteExpiryTimer;

  BuyerCheckoutQuote? get quote =>
      _quoteContextFingerprint == _contextFingerprint ? _quote : null;
  Object? get quoteError => _quoteError;
  String? get localError => _localError;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get isQuoting => _isQuoting;
  bool get isQuoteExpired => _isQuoteExpired;
  bool get hasBuyerSession => _activeBuyerId != null;
  bool get quoteNeedsSignIn {
    final error = _quoteError;
    return error is BuyerCheckoutException &&
        (error.category == BuyerCheckoutFailureCategory.noBuyerSession ||
            error.category == BuyerCheckoutFailureCategory.sessionChanged);
  }

  int? get selectedAddressId => _selectedAddressId;
  List<BuyerAddress>? get addresses => addressController.addresses;
  Object? get addressLoadError => addressController.loadError;
  bool get isLoadingAddresses => addressController.isLoading;

  BuyerAddress? get selectedAddress {
    final id = _selectedAddressId;
    if (id == null) return null;
    for (final address
        in addressController.addresses ?? const <BuyerAddress>[]) {
      if (address.id == id) return address;
    }
    return null;
  }

  bool get canRequestQuote {
    final items = cartController.selectedItems;
    return !_isQuoting &&
        items.isNotEmpty &&
        items.length <= 100 &&
        items.every((item) => item.id > 0 && item.isAvailable) &&
        selectedAddress != null;
  }

  /// Refreshes the server Cart and saved addresses in sequence, then obtains
  /// an initial quote only when the current selection and address are valid.
  Future<void> initialize() async {
    if (_isInitializing) return;
    if (_isInitialized) {
      await refreshInputs();
      return;
    }
    _isInitializing = true;
    _localError = null;
    notifyListeners();
    final sessionKey = _sessionKey;
    try {
      cartController.synchronizeSession();
      addressController.synchronizeSession();
      await cartController.refresh(force: true);
      if (_sessionKey != sessionKey) {
        _onDependencyChanged();
        return;
      }
      await addressController.refresh(force: true);
      if (_sessionKey != sessionKey) {
        _onDependencyChanged();
        return;
      }
      _isInitialized = true;
      _onDependencyChanged();
      if (canRequestQuote) await requestQuote();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshInputs() async {
    _localError = null;
    notifyListeners();
    await cartController.refresh(force: true);
    await addressController.refresh(force: true);
    if (canRequestQuote && quote == null) await requestQuote();
  }

  bool selectAddress(int addressId) {
    final exists = (addressController.addresses ?? const <BuyerAddress>[]).any(
      (address) => address.id == addressId,
    );
    if (!exists || addressId < 1) {
      _selectedAddressId = null;
      _localError =
          'That delivery address is no longer available. Choose a saved address.';
      _onDependencyChanged();
      return false;
    }
    if (_selectedAddressId == addressId) return true;
    _selectedAddressId = addressId;
    _localError = null;
    _onDependencyChanged();
    return true;
  }

  Future<void> refreshAddresses() async {
    await addressController.refresh(force: true);
  }

  /// Makes one authenticated quote request for the current selection. Repeated
  /// taps while the same request is active are ignored.
  Future<void> requestQuote() async {
    if (_isQuoting) return;
    final address = selectedAddress;
    final items = cartController.selectedItems;
    if (address == null) {
      _localError = 'Choose a saved delivery address to continue.';
      _clearQuote();
      notifyListeners();
      return;
    }
    if (items.isEmpty) {
      _localError = 'Select at least one available Cart item to continue.';
      _clearQuote();
      notifyListeners();
      return;
    }
    if (items.length > 100 || items.any((item) => !item.isAvailable)) {
      _localError = 'Choose up to 100 available Cart items and try again.';
      _clearQuote();
      notifyListeners();
      return;
    }

    final request = BuyerCheckoutQuoteRequest(
      addressId: address.id,
      cartItemIds: items.map((item) => item.id).toList(growable: false),
    );
    final fingerprint = _contextFingerprint;
    final sessionKey = _sessionKey;
    final sequence = ++_quoteSequence;
    _quoteExpiryTimer?.cancel();
    _quote = null;
    _quoteContextFingerprint = null;
    _quoteError = null;
    _localError = null;
    _isQuoteExpired = false;
    _isQuoting = true;
    notifyListeners();

    try {
      final result = await _checkoutRepository.requestQuote(request);
      if (_sessionKey != sessionKey) {
        _onDependencyChanged();
        return;
      }
      if (sequence != _quoteSequence ||
          _contextFingerprint != fingerprint ||
          result.buyerAccountId != _activeBuyerId) {
        return;
      }
      if (!result.quoteExpiresAt.isAfter(_clock())) {
        _isQuoteExpired = true;
        _localError =
            'This checkout quote has expired. Refresh the quote to continue.';
        return;
      }
      _quote = result;
      _quoteContextFingerprint = fingerprint;
      _scheduleExpiry(result, sequence);
    } catch (error) {
      if (_sessionKey != sessionKey) {
        _onDependencyChanged();
      } else if (sequence == _quoteSequence &&
          _contextFingerprint == fingerprint) {
        _quoteError = error;
      }
    } finally {
      if (sequence == _quoteSequence) {
        _isQuoting = false;
        notifyListeners();
      }
    }
  }

  String quoteErrorMessage(Object error) {
    if (error is! BuyerCheckoutException) {
      return 'We could not calculate checkout. Check your connection and try again.';
    }
    return switch (error.category) {
      BuyerCheckoutFailureCategory.noBuyerSession ||
      BuyerCheckoutFailureCategory.sessionChanged =>
        'Your Buyer session changed. Sign in again and review your Cart.',
      BuyerCheckoutFailureCategory.invalidRequest =>
        'Select available Cart items and a saved address before requesting a quote.',
      BuyerCheckoutFailureCategory.notFound =>
        'A selected Cart item or delivery address is no longer available. Refresh and review your selection.',
      BuyerCheckoutFailureCategory.conflict =>
        'Your Cart or checkout details changed on the server. Refresh your Cart and request a new quote.',
      BuyerCheckoutFailureCategory.validation =>
        _firstValidationMessage(error) ??
            'Bearly could not apply this checkout selection. Review the Cart and address.',
      BuyerCheckoutFailureCategory.rateLimited =>
        'Too many quote requests. Wait a moment, then try again.',
      BuyerCheckoutFailureCategory.server =>
        'Bearly could not calculate checkout right now. Try again shortly.',
      BuyerCheckoutFailureCategory.timeout =>
        'The checkout request timed out. Check your connection and retry.',
      BuyerCheckoutFailureCategory.connectivity =>
        'We could not reach Bearly. Check your connection and retry.',
      BuyerCheckoutFailureCategory.malformedResponse =>
        'Bearly returned an incomplete quote. No total is available; retry the request.',
      BuyerCheckoutFailureCategory.expiredQuote =>
        'This checkout quote has expired. Request a fresh quote.',
      BuyerCheckoutFailureCategory.secureStorage ||
      BuyerCheckoutFailureCategory.unresolvedAttempt ||
      BuyerCheckoutFailureCategory.rejectedAttempt =>
        'Checkout review is unavailable right now. Your existing checkout state was left untouched.',
      BuyerCheckoutFailureCategory.client =>
        'Bearly rejected this checkout request. Refresh your Cart and try again.',
    };
  }

  static String? _firstValidationMessage(BuyerCheckoutException error) {
    for (final messages in error.validationErrors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return null;
  }

  void _onDependencyChanged() {
    _synchronizeSession();
    _resolveInitialAddress();
    final nextFingerprint = _contextFingerprint;
    if (nextFingerprint != _lastContextFingerprint) {
      _lastContextFingerprint = nextFingerprint;
      final hadExpiredQuote = _isQuoteExpired;
      _clearQuote();
      if (hadExpiredQuote) _localError = null;
    }
    notifyListeners();
  }

  void _synchronizeSession() {
    final currentKey = _sessionKey;
    if (currentKey == _observedSessionKey) return;
    _observedSessionKey = currentKey;
    _selectedAddressId = null;
    _addressSelectionResolved = false;
    _lastAddressCount = 0;
    _quoteError = null;
    _localError = null;
    _isQuoteExpired = false;
    _clearQuote();
    cartController.synchronizeSession();
    addressController.synchronizeSession();
    _lastContextFingerprint = _contextFingerprint;
  }

  void _resolveInitialAddress() {
    final currentAddresses = addressController.addresses;
    if (currentAddresses == null) return;
    final currentIds = currentAddresses.map((address) => address.id).toSet();
    if (_selectedAddressId != null &&
        !currentIds.contains(_selectedAddressId)) {
      _selectedAddressId = null;
      _addressSelectionResolved = true;
      _localError =
          'Your selected delivery address is no longer available. Choose another address.';
    } else if (_selectedAddressId != null) {
      _addressSelectionResolved = true;
    }

    final addressWasAddedToEmptyList =
        _selectedAddressId == null &&
        _lastAddressCount == 0 &&
        currentAddresses.isNotEmpty &&
        _addressSelectionResolved;
    if (_selectedAddressId == null &&
        (!_addressSelectionResolved || addressWasAddedToEmptyList)) {
      final preferred = currentAddresses.where((address) => address.isDefault);
      _selectedAddressId = preferred.isNotEmpty
          ? preferred.first.id
          : currentAddresses.isEmpty
          ? null
          : currentAddresses.first.id;
      _addressSelectionResolved = true;
    }
    _lastAddressCount = currentAddresses.length;
  }

  String get _sessionKey {
    final session = _authService.currentSession;
    if (session == null || session.role != AccountRole.buyer) return 'none';
    return 'buyer:${session.id}:${_authService.sessionEpoch}';
  }

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  String get _contextFingerprint {
    final session = _authService.currentSession;
    final address = selectedAddress;
    return jsonEncode([
      session?.role == AccountRole.buyer ? session?.id : null,
      _authService.sessionEpoch,
      for (final item in cartController.selectedItems)
        [
          item.id,
          item.productId,
          item.productVariantId,
          item.quantity,
          item.unitPriceMinor,
          item.lineSubtotalMinor,
          item.regularPriceMinor,
          item.discountPercent,
          item.campaignName,
          item.availableStock,
          item.isAvailable,
          item.name,
          item.variantName,
          jsonEncode(item.options),
          item.storeName,
        ],
      address == null
          ? null
          : [
              address.id,
              address.name,
              address.phone,
              address.province,
              address.city,
              address.barangay,
              address.postal,
              address.street,
            ],
    ]);
  }

  void _clearQuote() {
    _quoteSequence++;
    _quoteExpiryTimer?.cancel();
    _quoteExpiryTimer = null;
    _quote = null;
    _quoteContextFingerprint = null;
    _quoteError = null;
    _isQuoteExpired = false;
    _isQuoting = false;
  }

  void _scheduleExpiry(BuyerCheckoutQuote quote, int sequence) {
    final delay = quote.quoteExpiresAt.difference(_clock());
    if (delay <= Duration.zero) {
      _expireQuote(sequence);
      return;
    }
    _quoteExpiryTimer = Timer(delay, () => _expireQuote(sequence));
  }

  void _expireQuote(int sequence) {
    if (sequence != _quoteSequence || _quote == null) return;
    _quote = null;
    _quoteContextFingerprint = null;
    _quoteExpiryTimer = null;
    _isQuoteExpired = true;
    _localError =
        'This checkout quote has expired. Refresh the quote to continue.';
    notifyListeners();
  }

  @override
  void dispose() {
    _quoteExpiryTimer?.cancel();
    cartController.removeListener(_onDependencyChanged);
    addressController.removeListener(_onDependencyChanged);
    super.dispose();
  }
}
