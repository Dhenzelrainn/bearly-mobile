import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/registration_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

final _verificationId = List.filled(64, 'v').join();

void main() {
  late _RecordingClient client;
  late RegistrationRepository repository;

  setUp(() {
    client = _RecordingClient();
    repository = RegistrationRepository(
      apiClient: ApiClient(
        httpClient: client,
        baseUri: Uri.parse('https://registration.test'),
      ),
    );
  });

  test(
    'email verification challenge normalizes email and does not include a code',
    () async {
      final challenge = await repository.sendEmailCode('  BUYER@Example.Test ');

      expect(challenge.verificationId, _verificationId);
      expect(challenge.retryAfter, 60);
      final request = client.requests.single as http.Request;
      expect(request.url.path, '/api/mobile/register/email/send');
      expect(jsonDecode(request.body), {'email': 'buyer@example.test'});
      expect(request.body, isNot(contains('code')));
    },
  );

  test(
    'email verification posts only the submitted code and verification id',
    () async {
      await repository.verifyEmailCode(
        email: 'Buyer@example.test',
        code: '123456',
        verificationId: _verificationId,
      );

      final request = client.requests.single as http.Request;
      expect(request.url.path, '/api/mobile/register/email/verify');
      expect(jsonDecode(request.body), {
        'email': 'buyer@example.test',
        'code': '123456',
        'verification_id': _verificationId,
      });
    },
  );

  test(
    'Logistics directory query is scoped to the selected PSGC city',
    () async {
      final partners = await repository.logisticsPartners('0403424000');

      expect(partners.map((partner) => partner.id), [12]);
      expect(partners.single.name, 'Laguna Logistics');
      final request = client.requests.single as http.Request;
      expect(request.url.path, '/api/mobile/register/logistics-partners');
      expect(request.url.queryParameters, {'city_code': '0403424000'});
    },
  );

  test(
    'Buyer payload preserves selected region and omits an absent optional region code',
    () async {
      final outcome = await repository.registerBuyer({
        'first_name': 'Bianca',
        'email': 'buyer@example.test',
        'region': 'Region IV-A (CALABARZON)',
        'city': 'City of San Pablo',
        'terms': '1',
      });

      expect(outcome.role, 'buyer');
      expect(outcome.status, 'active');
      final request = client.requests.single as http.Request;
      expect(request.url.path, '/api/mobile/register/buyer');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['region'], 'Region IV-A (CALABARZON)');
      expect(body['city'], 'City of San Pablo');
      expect(body.containsKey('region_code'), isFalse);
      expect(body['terms'], '1');
    },
  );

  test(
    'Courier application uploads Rider fields and both required files',
    () async {
      final outcome = await repository.registerRider(
        fields: const {
          'work_type': 'courier',
          'vehicle_type': 'Van',
          'logistics_partner': '12',
          'region': 'Region IV-A (CALABARZON)',
          'region_code': '0400000000',
          'terms': '1',
        },
        documents: const [
          ApiMultipartFile(
            field: 'or_cr',
            bytes: [1, 2],
            fileName: 'or-cr.pdf',
          ),
          ApiMultipartFile(
            field: 'driver_license',
            bytes: [3, 4],
            fileName: 'license.pdf',
          ),
        ],
      );

      expect(outcome.role, 'rider');
      expect(outcome.workType, 'courier');
      final request = client.requests.single as http.MultipartRequest;
      expect(request.url.path, '/api/mobile/register/rider');
      expect(request.fields['work_type'], 'courier');
      expect(request.fields['vehicle_type'], 'Van');
      expect(request.fields['region_code'], '0400000000');
      expect(request.fields['logistics_partner'], '12');
      expect(request.files.map((file) => file.field).toSet(), {
        'or_cr',
        'driver_license',
      });
    },
  );

  test(
    'Logistics application uploads its separate ID and business permit requirements',
    () async {
      await repository.registerLogistics(
        fields: const {
          'business_name': 'Bearly Logistics',
          'region': 'Region IV-A (CALABARZON)',
          'region_code': '0400000000',
          'city_code': '0403424000',
          'terms': '1',
        },
        documents: const [
          ApiMultipartFile(field: 'valid_id', bytes: [5], fileName: 'id.png'),
          ApiMultipartFile(
            field: 'business_permit',
            bytes: [6],
            fileName: 'permit.pdf',
          ),
        ],
      );

      final request = client.requests.single as http.MultipartRequest;
      expect(request.url.path, '/api/mobile/register/logistics');
      expect(request.fields['business_name'], 'Bearly Logistics');
      expect(request.files.map((file) => file.field).toSet(), {
        'valid_id',
        'business_permit',
      });
    },
  );

  test(
    'registration API validation errors remain available to the form',
    () async {
      client.statusCode = 422;
      client.response = {
        'message': 'The given data was invalid.',
        'errors': {
          'region': ['Select a valid PSGC region.'],
        },
      };

      try {
        await repository.registerBuyer({'region': ''});
        fail('Expected validation response.');
      } on ApiHttpException catch (error) {
        expect(error.validationErrors['region'], [
          'Select a valid PSGC region.',
        ]);
      }
    },
  );
}

class _RecordingClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  int statusCode = 201;
  Object response = {
    'message': 'Application submitted.',
    'data': {
      'user_id': 42,
      'name': 'Bearly Applicant',
      'email': 'applicant@example.test',
      'role': 'rider',
      'status': 'pending',
      'work_type': 'courier',
      'review_authority': 'Laguna Logistics',
    },
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    Object body = response;
    var code = statusCode;
    if (request.url.path.endsWith('/email/send')) {
      body = {
        'verification_id': _verificationId,
        'retry_after': 60,
        'expires_in': 300,
      };
      code = 200;
    } else if (request.url.path.endsWith('/email/verify')) {
      body = {'message': 'Email address verified.'};
      code = 200;
    } else if (request.url.path.endsWith('/logistics-partners')) {
      body = {
        'data': [
          {'id': 12, 'name': 'Laguna Logistics'},
        ],
      };
      code = 200;
    } else if (request.url.path.endsWith('/register/buyer') && code == 201) {
      body = {
        'message': 'Buyer account activated.',
        'data': {
          'user_id': 45,
          'name': 'Buyer Applicant',
          'email': 'buyer@example.test',
          'role': 'buyer',
          'status': 'active',
        },
      };
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      code,
      headers: const {'content-type': 'application/json'},
    );
  }
}
