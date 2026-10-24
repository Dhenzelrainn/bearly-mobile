import 'buyer_checkout_models.dart';
import 'buyer_order_models.dart';

enum BuyerCheckoutAttemptStatus {
  ready,
  submitting,
  indeterminate,
  rejected,
  succeeded,
}

class BuyerCheckoutAttempt {
  const BuyerCheckoutAttempt({
    required this.buyerAccountId,
    required this.request,
    required this.status,
    required this.updatedAt,
    this.result,
    this.failureCategory,
    this.serverErrorCode,
    this.validationErrors = const {},
  });

  final int buyerAccountId;
  final BuyerCheckoutPlacementRequest request;
  final BuyerCheckoutAttemptStatus status;
  final DateTime updatedAt;
  final BuyerPlacedOrder? result;
  final String? failureCategory;
  final String? serverErrorCode;
  final Map<String, List<String>> validationErrors;

  BuyerCheckoutAttempt copyWith({
    BuyerCheckoutAttemptStatus? status,
    DateTime? updatedAt,
    BuyerPlacedOrder? result,
    String? failureCategory,
    String? serverErrorCode,
    Map<String, List<String>>? validationErrors,
    bool clearFailureDetails = false,
  }) => BuyerCheckoutAttempt(
    buyerAccountId: buyerAccountId,
    request: request,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
    result: result ?? this.result,
    failureCategory: clearFailureDetails
        ? failureCategory
        : failureCategory ?? this.failureCategory,
    serverErrorCode: clearFailureDetails
        ? serverErrorCode
        : serverErrorCode ?? this.serverErrorCode,
    validationErrors: clearFailureDetails
        ? validationErrors ?? const {}
        : validationErrors ?? this.validationErrors,
  );

  Map<String, Object?> toJson() => {
    'buyer_account_id': buyerAccountId,
    'request': request.toJson(),
    'status': status.name,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (result != null) 'result': result!.toJson(),
    if (failureCategory != null) 'failure_category': failureCategory,
    if (serverErrorCode != null) 'server_error_code': serverErrorCode,
    if (validationErrors.isNotEmpty)
      'validation_errors': {
        for (final entry in validationErrors.entries) entry.key: entry.value,
      },
  };

  factory BuyerCheckoutAttempt.fromJson(Object? value) {
    final json = buyerCheckoutMap(value, 'attempt');
    final statusName = buyerCheckoutString(json, 'status', 'attempt');
    final status = BuyerCheckoutAttemptStatus.values
        .where((candidate) => candidate.name == statusName)
        .firstOrNull;
    if (status == null) {
      throw const BuyerCheckoutFormatException('attempt.status');
    }

    final rawErrors = json['validation_errors'];
    final errors = <String, List<String>>{};
    if (rawErrors != null) {
      final errorMap = buyerCheckoutMap(rawErrors, 'attempt.validation_errors');
      for (final entry in errorMap.entries) {
        if (entry.value is! List ||
            (entry.value as List).any((item) => item is! String)) {
          throw const BuyerCheckoutFormatException('attempt.validation_errors');
        }
        errors[entry.key] = List.unmodifiable(
          (entry.value as List).cast<String>(),
        );
      }
    }
    final buyerId = buyerCheckoutInt(json, 'buyer_account_id', 'attempt');
    if (buyerId < 1) {
      throw const BuyerCheckoutFormatException('attempt.buyer_account_id');
    }

    return BuyerCheckoutAttempt(
      buyerAccountId: buyerId,
      request: BuyerCheckoutPlacementRequest.fromJson(json['request']),
      status: status,
      updatedAt: buyerCheckoutDate(json, 'updated_at', 'attempt'),
      result: json['result'] == null
          ? null
          : BuyerPlacedOrder.fromJson(json['result']),
      failureCategory: buyerCheckoutOptionalString(
        json,
        'failure_category',
        'attempt',
      ),
      serverErrorCode: buyerCheckoutOptionalString(
        json,
        'server_error_code',
        'attempt',
      ),
      validationErrors: Map.unmodifiable(errors),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
