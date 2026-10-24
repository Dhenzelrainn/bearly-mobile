import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/buyer_checkout_attempt.dart';

abstract interface class BuyerCheckoutAttemptStore {
  Future<BuyerCheckoutAttempt?> read(int buyerAccountId);

  Future<void> write(BuyerCheckoutAttempt attempt);

  Future<void> clear(int buyerAccountId);
}

/// Stores the immutable placement payload in encrypted platform storage,
/// partitioned by Buyer account. No quote token is written to ordinary prefs.
class SecureBuyerCheckoutAttemptStore implements BuyerCheckoutAttemptStore {
  SecureBuyerCheckoutAttemptStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'bearly.mobile.pending_checkout_attempt.';
  final FlutterSecureStorage _storage;

  String _key(int buyerAccountId) {
    if (buyerAccountId < 1) {
      throw ArgumentError.value(buyerAccountId, 'buyerAccountId');
    }
    return '$_keyPrefix$buyerAccountId';
  }

  @override
  Future<BuyerCheckoutAttempt?> read(int buyerAccountId) async {
    try {
      final stored = await _storage.read(key: _key(buyerAccountId));
      if (stored == null) return null;
      final attempt = BuyerCheckoutAttempt.fromJson(jsonDecode(stored));
      if (attempt.buyerAccountId != buyerAccountId) {
        throw const FormatException('Account mismatch');
      }
      return attempt;
    } on Object {
      // Surface a field-only error; never expose secure-storage text or payload.
      throw const BuyerCheckoutAttemptStorageException();
    }
  }

  @override
  Future<void> write(BuyerCheckoutAttempt attempt) async {
    try {
      await _storage.write(
        key: _key(attempt.buyerAccountId),
        value: jsonEncode(attempt.toJson()),
      );
    } on Object {
      throw const BuyerCheckoutAttemptStorageException();
    }
  }

  @override
  Future<void> clear(int buyerAccountId) async {
    try {
      await _storage.delete(key: _key(buyerAccountId));
    } on Object {
      throw const BuyerCheckoutAttemptStorageException();
    }
  }
}

class BuyerCheckoutAttemptStorageException implements Exception {
  const BuyerCheckoutAttemptStorageException();

  @override
  String toString() => 'Secure checkout attempt storage is unavailable.';
}
