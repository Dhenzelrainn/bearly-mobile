import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/buyer/data/buyer_review_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BuyerReviewRepository', () {
    test('submits a text review to the authenticated Buyer endpoint', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _json({
          'data': {'order_item_id': 81, 'rating': 5},
        }, 201);
      });

      await repository.submitReview(
        orderItemId: 81,
        rating: 5,
        comment: '  Lovely quality.  ',
      );

      expect(request.method, 'POST');
      expect(request.url.path, '/api/mobile/buyer/reviews');
      expect(request.headers['authorization'], 'Bearer mobile-review-token');
      expect(jsonDecode(request.body), {
        'order_item_id': '81',
        'rating': '5',
        'comment': 'Lovely quality.',
      });
    });

    test('uploads an optional photo as multipart form data', () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return _json({
          'data': {'order_item_id': 82, 'rating': 4},
        }, 201);
      });

      await repository.submitReview(
        orderItemId: 82,
        rating: 4,
        comment: 'Nice finish.',
        photoBytes: [1, 2, 3, 4],
        photoName: 'review.png',
      );

      expect(request.url.path, '/api/mobile/buyer/reviews');
      expect(request.headers['authorization'], 'Bearer mobile-review-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(request.body, contains('name="order_item_id"'));
      expect(request.body, contains('name="rating"'));
      expect(request.body, contains('name="comment"'));
      expect(request.body, contains('filename="review.png"'));
      expect(request.body, contains('name="photo"'));
    });

    test(
      'rejects invalid review inputs before making an API request',
      () async {
        var requests = 0;
        final repository = _repository((_) async {
          requests++;
          return _json({'data': {}}, 201);
        });

        await expectLater(
          repository.submitReview(orderItemId: 81, rating: 0, comment: 'Text'),
          throwsRangeError,
        );
        await expectLater(
          repository.submitReview(orderItemId: 81, rating: 5, comment: '  '),
          throwsArgumentError,
        );
        await expectLater(
          repository.submitReview(
            orderItemId: 81,
            rating: 5,
            comment: 'Text',
            photoBytes: [1],
            photoName: 'review.gif',
          ),
          throwsArgumentError,
        );
        expect(requests, 0);
      },
    );

    test('requires the active account to be a Buyer', () async {
      final auth = _auth(MockClient((_) async => _json({'data': {}})))
        ..currentSession = const AuthSession(
          id: 9,
          name: 'Rider Rae',
          email: 'rider@example.test',
          role: AccountRole.rider,
        );
      final repository = BuyerReviewRepository(authService: auth);

      await expectLater(
        repository.submitReview(orderItemId: 81, rating: 5, comment: 'Text'),
        throwsFormatException,
      );
    });
  });
}

BuyerReviewRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => BuyerReviewRepository(authService: _auth(MockClient(handler)));

AuthService _auth(http.Client client) {
  final auth = AuthService(
    apiClient: ApiClient(
      httpClient: client,
      baseUri: Uri.parse('https://api.example.test'),
    ),
    tokenStore: _MemoryTokenStore()..token = 'mobile-review-token',
  );
  auth.currentSession = const AuthSession(
    id: 8,
    name: 'Bea Buyer',
    email: 'bea@example.test',
    role: AccountRole.buyer,
  );
  return auth;
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

class _MemoryTokenStore implements SessionTokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> clear() async => token = null;
}
