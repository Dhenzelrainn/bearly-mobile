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

String buyerOrderPhilippineDateTime(
  DateTime? value,
  MaterialLocalizations localizations,
) {
  if (value == null) return 'Date unavailable';
  final philippines = value.toUtc().add(const Duration(hours: 8));
  final time = TimeOfDay.fromDateTime(philippines);
  return '${localizations.formatMediumDate(philippines)} · '
      '${localizations.formatTimeOfDay(time)} (Philippine Time, UTC+8)';
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

String buyerOrderReceiptErrorMessage(Object? error) {
  if (error is! BuyerCheckoutException) {
    return 'Bearly could not confirm receipt. Refresh the order status before trying again.';
  }
  return switch (error.category) {
    BuyerCheckoutFailureCategory.noBuyerSession =>
      'Your session is no longer active. Sign in again before confirming receipt.',
    BuyerCheckoutFailureCategory.sessionChanged =>
      'Your account changed. This order view has been cleared.',
    BuyerCheckoutFailureCategory.notFound =>
      'This order is unavailable for the signed-in Buyer. No confirmation was applied.',
    BuyerCheckoutFailureCategory.conflict => switch (error.serverErrorCode) {
      'order_cancelled' =>
        'Bearly reports that this order was cancelled, so receipt cannot be confirmed.',
      'no_active_seller_orders' =>
        'Bearly reports that this order has no active Seller orders to confirm.',
      'order_not_fully_delivered' =>
        'Bearly reports that not every applicable parcel has been delivered. The order was not confirmed.',
      'cod_cash_collection_incomplete' =>
        'Bearly reports that required COD Rider collection records are incomplete. Receipt was not confirmed.',
      _ =>
        'Bearly reports that this order is not eligible for receipt confirmation yet.',
    },
    BuyerCheckoutFailureCategory.client =>
      error.statusCode == 403
          ? 'This Buyer account is not allowed to confirm receipt for this order.'
          : 'Bearly rejected the receipt confirmation. Refresh the order and try again later.',
    BuyerCheckoutFailureCategory.validation =>
      'Bearly could not validate the receipt confirmation. Refresh the order before trying again.',
    BuyerCheckoutFailureCategory.rateLimited =>
      'Too many requests were made. Wait a little before checking this order again.',
    BuyerCheckoutFailureCategory.timeout ||
    BuyerCheckoutFailureCategory.connectivity ||
    BuyerCheckoutFailureCategory.malformedResponse ||
    BuyerCheckoutFailureCategory.server =>
      'The request may have reached Bearly. Check the order status before deciding whether to retry.',
    _ =>
      'Bearly could not confirm receipt. Refresh the order status before trying again.',
  };
}
