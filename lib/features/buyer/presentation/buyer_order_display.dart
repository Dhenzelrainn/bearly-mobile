import 'package:flutter/material.dart';

import '../data/buyer_checkout_repository.dart';
import '../models/buyer_catalog_models.dart';

String buyerOrderStatusLabel(String value) {
  final words = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
  if (words.isEmpty) return 'Status unavailable';
  return words
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String buyerOrderDateTime(
  DateTime? value,
  MaterialLocalizations localizations,
) {
  if (value == null) return 'Date unavailable';
  final local = value.toLocal();
  final time = TimeOfDay.fromDateTime(local);
  return '${localizations.formatMediumDate(local)} · '
      '${localizations.formatTimeOfDay(time)} (local)';
}

String buyerOrderAmount(int amountMinor, {String currency = 'PHP'}) =>
    formatPriceMinorUnits(amountMinor, currency: currency);

String buyerOrderScalarOptions(Map<String, Object?> options) {
  final parts = <String>[];
  for (final entry in options.entries) {
    final value = entry.value;
    if (value is String || value is num || value is bool) {
      final label = buyerOrderStatusLabel(entry.key);
      parts.add('$label: $value');
    }
  }
  return parts.join(' · ');
}

String buyerOrderReadErrorMessage(Object? error) {
  if (error is BuyerCheckoutException) {
    return switch (error.category) {
      BuyerCheckoutFailureCategory.noBuyerSession =>
        'Sign in with a Buyer account to view orders.',
      BuyerCheckoutFailureCategory.notFound =>
        'This order information is unavailable for the signed-in Buyer.',
      BuyerCheckoutFailureCategory.timeout ||
      BuyerCheckoutFailureCategory.connectivity ||
      BuyerCheckoutFailureCategory.server =>
        'Bearly could not load this order information. Check your connection and retry.',
      BuyerCheckoutFailureCategory.malformedResponse =>
        'Bearly returned order information the app could not read. Please retry.',
      _ => 'Order information could not be loaded. Please retry.',
    };
  }
  return 'Order information could not be loaded. Please retry.';
}
