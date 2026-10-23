import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_catalog_models.dart';
import 'buyer_wishlist_repository.dart';

/// Account-scoped, in-memory presentation state for Laravel's Buyer wishlist.
/// Laravel remains the source of truth; no wishlist data is persisted locally.
class BuyerWishlistController extends ChangeNotifier {
  BuyerWishlistController({
    required AuthService authService,
    BuyerWishlistRepository? repository,
  }) : _authService = authService,
       _repository =
           repository ?? BuyerWishlistRepository(authService: authService) {
    _ownerAccountId = _activeBuyerId;
  }

  final AuthService _authService;
  final BuyerWishlistRepository _repository;

  Map<int, List<BuyerCatalogProduct>> _pages = {};
  Set<int> _savedProductIds = {};
  final Set<int> _pendingProductIds = {};
  BuyerCatalogPagination? _pagination;
  Object? _loadError;
  int? _ownerAccountId;
  int _visiblePage = 1;
  int _loadSequence = 0;
  int _mutationSequence = 0;
  bool _isLoading = false;
  bool _membershipLoaded = false;

  int? get _activeBuyerId {
    final session = _authService.currentSession;
    return session?.role == AccountRole.buyer ? session?.id : null;
  }

  bool get isLoading => _isLoading;
  bool get membershipLoaded => _membershipLoaded;
  Object? get loadError => _loadError;
  int get visiblePage => _visiblePage;
  int get totalPages => _pagination?.lastPage ?? 1;
  bool get hasMore => _visiblePage < totalPages;
  bool get isLoadingMore => false;
  Set<int> get pendingProductIds => UnmodifiableSetView(_pendingProductIds);

  /// Saved products visible through the current Load More position.
  List<BuyerCatalogProduct> get products {
    final seen = <int>{};
    final result = <BuyerCatalogProduct>[];
    for (var page = 1; page <= _visiblePage; page++) {
      for (final product in _pages[page] ?? const <BuyerCatalogProduct>[]) {
        if (_savedProductIds.contains(product.id) && seen.add(product.id)) {
          result.add(product);
        }
      }
    }
    return List.unmodifiable(result);
  }

  /// Null means Laravel membership is not fully synchronized yet.
  bool? isSaved(int productId) {
    if (!_membershipLoaded) return null;
    return _savedProductIds.contains(productId);
  }

  bool isPending(int productId) => _pendingProductIds.contains(productId);

  /// Drops all account-scoped state when the active Buyer changes or logs out.
  bool synchronizeSession() {
    final nextOwner = _activeBuyerId;
    if (nextOwner == _ownerAccountId) return false;
    _ownerAccountId = nextOwner;
    _resetState();
    notifyListeners();
    return true;
  }

  void clear() {
    _ownerAccountId = null;
    _resetState();
    notifyListeners();
  }

  void _resetState() {
    _pages = {};
    _savedProductIds = {};
    _pendingProductIds.clear();
    _pagination = null;
    _loadError = null;
    _visiblePage = 1;
    _isLoading = false;
    _membershipLoaded = false;
    _loadSequence++;
    _mutationSequence++;
  }

  /// Loads every Laravel page so an absent product is only called unsaved once
  /// membership is known across the complete Wishlist. The Saved page reveals
  /// those fetched pages incrementally through its Load More control.
  Future<void> refresh({bool force = false}) async {
    synchronizeSession();
    final owner = _ownerAccountId;
    if (owner == null) {
      _loadError = const AuthException(
        'Sign in with a Buyer account to view saved products.',
      );
      _membershipLoaded = false;
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (_isLoading || _pendingProductIds.isNotEmpty) return;
    if (!force && _membershipLoaded) return;

    final sequence = ++_loadSequence;
    final mutationSequence = _mutationSequence;
    _isLoading = true;
    _membershipLoaded = false;
    _loadError = null;
    _visiblePage = 1;
    notifyListeners();

    final pages = <int, List<BuyerCatalogProduct>>{};
    final savedIds = <int>{};
    BuyerCatalogPagination? pagination;
    try {
      var pageNumber = 1;
      while (true) {
        final page = await _repository.fetchSavedProducts(page: pageNumber);
        if (!_isCurrent(owner)) {
          synchronizeSession();
          if (_activeBuyerId == null) {
            _loadError = const AuthException(
              'Your session needs attention. Sign in again to view saved products.',
            );
            notifyListeners();
          }
          return;
        }
        if (sequence != _loadSequence ||
            mutationSequence != _mutationSequence) {
          return;
        }
        pages[pageNumber] = page.entries.map((entry) => entry.product).toList();
        savedIds.addAll(page.entries.map((entry) => entry.product.id));
        pagination = page.pagination;
        if (!page.pagination.hasMore ||
            pageNumber >= page.pagination.lastPage) {
          break;
        }
        pageNumber++;
      }

      if (!_isCurrent(owner) || sequence != _loadSequence) return;
      _pages = pages;
      _savedProductIds = savedIds;
      _pagination = pagination;
      _membershipLoaded = true;
      _loadError = null;
    } catch (error) {
      if (!_isCurrent(owner)) {
        synchronizeSession();
        if (_activeBuyerId == null) {
          _loadError = error;
          notifyListeners();
        }
        return;
      }
      if (sequence != _loadSequence) return;
      _loadError = error;
      _membershipLoaded = false;
    } finally {
      if (sequence == _loadSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void loadMore() {
    if (!_membershipLoaded || _isLoading || !hasMore) return;
    _visiblePage++;
    notifyListeners();
  }

  Future<bool> toggleProduct(BuyerCatalogProduct product) {
    final current = isSaved(product.id);
    if (current == null) {
      throw StateError('Saved products are still synchronizing.');
    }
    return setSaved(product.id, !current, product: product);
  }

  Future<bool> setSaved(
    int productId,
    bool shouldBeSaved, {
    BuyerCatalogProduct? product,
  }) async {
    synchronizeSession();
    final owner = _ownerAccountId;
    if (owner == null) {
      throw const AuthException(
        'Sign in with a Buyer account to update saved products.',
      );
    }
    if (!_membershipLoaded) {
      throw StateError('Saved products are still synchronizing.');
    }
    if (_pendingProductIds.contains(productId)) return false;
    if (_savedProductIds.contains(productId) == shouldBeSaved) return true;

    _pendingProductIds.add(productId);
    _loadSequence++;
    _isLoading = false;
    _loadError = null;
    notifyListeners();

    var succeeded = false;
    try {
      final result = shouldBeSaved
          ? await _repository.saveProduct(productId)
          : await _repository.removeProduct(productId);
      if (_isCurrent(owner)) {
        if (result.isSaved) {
          _savedProductIds.add(productId);
          if (product != null) {
            final firstPage = [...?_pages[1]];
            firstPage.removeWhere((item) => item.id == productId);
            firstPage.insert(0, product);
            _pages[1] = firstPage;
          }
        } else {
          _savedProductIds.remove(productId);
          for (final page in _pages.values) {
            page.removeWhere((item) => item.id == productId);
          }
        }
        _mutationSequence++;
        succeeded = true;
      } else {
        synchronizeSession();
      }
      return succeeded;
    } catch (error) {
      if (!_isCurrent(owner)) synchronizeSession();
      rethrow;
    } finally {
      if (_isCurrent(owner)) {
        _pendingProductIds.remove(productId);
        notifyListeners();
        if (succeeded && _pendingProductIds.isEmpty) {
          // Reconcile page boundaries and current prices with Laravel after
          // applying the successful mutation response to shared state.
          unawaited(refresh(force: true));
        }
      }
    }
  }

  bool _isCurrent(int owner) =>
      _ownerAccountId == owner && _activeBuyerId == owner;
}

/// Short Buyer-facing Wishlist errors; API bodies and private data are omitted.
String buyerWishlistErrorMessage(Object error) {
  if (error is AuthException ||
      (error is ApiHttpException &&
          (error.statusCode == 401 || error.statusCode == 403))) {
    return 'Your session needs attention. Sign in again to use saved products.';
  }
  if (error is ApiTimeoutException) {
    return 'The request timed out. Refresh saved products to confirm their latest state.';
  }
  if (error is ApiTransportException) {
    return 'We could not reach Bearly. Check your connection and try again.';
  }
  if (error is ApiHttpException) {
    return switch (error.statusCode) {
      404 => 'This product is no longer available to save or view.',
      422 =>
        'Bearly could not save this product. Review its availability and try again.',
      429 => 'Too many requests. Please wait a moment and try again.',
      >= 500 => 'Bearly could not update saved products. Try again shortly.',
      _ => 'Bearly rejected this saved products request. Please try again.',
    };
  }
  return 'We could not update saved products. Please try again.';
}
