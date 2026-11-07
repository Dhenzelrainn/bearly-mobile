import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';

/// Submits or updates reviews through Laravel's existing Buyer review rules.
class BuyerReviewRepository {
  BuyerReviewRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Future<void> submitReview({
    required int orderItemId,
    required int rating,
    required String comment,
    List<int>? photoBytes,
    String? photoName,
  }) async {
    if (_authService.currentSession?.role != AccountRole.buyer) {
      throw const FormatException('Sign in with a Buyer account to review.');
    }
    if (orderItemId < 1) throw RangeError.value(orderItemId, 'orderItemId');
    if (rating < 1 || rating > 5) {
      throw RangeError.range(rating, 1, 5, 'rating');
    }
    final text = comment.trim();
    if (text.isEmpty || text.runes.length > 500) {
      throw ArgumentError.value(comment, 'comment', 'Use 1 to 500 characters.');
    }

    final fields = <String, String>{
      'order_item_id': '$orderItemId',
      'rating': '$rating',
      'comment': text,
    };
    final bytes = photoBytes;
    final name = photoName?.trim();
    if (bytes != null || name != null) {
      final extension = name?.split('.').last.toLowerCase();
      if (bytes == null ||
          name == null ||
          name.isEmpty ||
          !const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
          bytes.isEmpty ||
          bytes.length > 10 * 1024 * 1024) {
        throw ArgumentError.value(
          photoName,
          'photo',
          'Choose a JPG, PNG, or WebP image up to 10 MB.',
        );
      }
      await _authService.multipartRequestWithSession<void>(
        path: '/api/mobile/buyer/reviews',
        fields: fields,
        fileField: 'photo',
        fileBytes: bytes,
        fileName: name,
        parse: _validateResponse,
      );
      return;
    }

    await _authService.requestWithSession<void>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/reviews',
      body: fields,
      parse: _validateResponse,
    );
  }

  static void _validateResponse(Object? value) {
    if (value is! Map || value['data'] is! Map) {
      throw const FormatException(
        'Bearly returned an unreadable review response.',
      );
    }
  }
}
