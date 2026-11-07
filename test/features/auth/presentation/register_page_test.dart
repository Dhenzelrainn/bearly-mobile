import 'package:bearly_mobile/features/auth/data/registration_repository.dart';
import 'package:bearly_mobile/features/auth/presentation/pending_page.dart';
import 'package:bearly_mobile/features/auth/presentation/register_page.dart';
import 'package:bearly_mobile/features/auth/data/psgc_service.dart';
import 'package:bearly_mobile/features/auth/data/postal_code_service.dart';
import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _verificationId = List.filled(64, 'v').join();

void main() {
  testWidgets(
    'registration offers Buyer, Rider, Courier work type, and Logistics',
    (tester) async {
      final registration = _FakeRegistrationDataSource();
      await tester.pumpWidget(_registrationApp(registration));
      await tester.pumpAndSettle();

      expect(find.text('Buyer'), findsNWidgets(2));
      expect(find.text('Rider'), findsOneWidget);
      expect(find.text('Logistics'), findsOneWidget);
      expect(find.text('Courier'), findsNothing);

      await tester.tap(find.text('Rider'));
      await tester.pumpAndSettle();
      expect(find.text('Rider work type'), findsOneWidget);
      expect(find.text('Local Rider'), findsOneWidget);
      expect(find.text('Courier'), findsOneWidget);
    },
  );

  testWidgets('email code send and verification use the shared API flow', (
    tester,
  ) async {
    final registration = _FakeRegistrationDataSource();
    await tester.pumpWidget(_registrationApp(registration));
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextFormField, 'Email address');
    await tester.ensureVisible(emailField);
    await tester.enterText(emailField, '  Buyer@Example.Test ');
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(registration.sentEmails, ['buyer@example.test']);
    expect(
      find.text('Code sent. It expires in about 5 min 00 sec.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Verify email'), findsOneWidget);

    final codeField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.maxLength == 6,
    );
    await tester.ensureVisible(codeField);
    await tester.enterText(codeField, '123456');
    await tester.tap(find.byTooltip('Verify email'));
    await tester.pumpAndSettle();

    expect(registration.verifiedCodes, ['123456']);
    expect(find.text('Email address verified.'), findsOneWidget);
  });

  testWidgets(
    'verified Buyer submits selected address and region through API',
    (tester) async {
      final registration = _FakeRegistrationDataSource();
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('registration-result')),
          ),
          home: RegisterPage(
            registrationDataSource: registration,
            psgcService: _FakeAddressService(),
            postalCodeService: _FakePostalCodeService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _enterField(tester, 'First name', 'Bianca');
      await _enterField(tester, 'Last name', 'Santos');
      final sexField = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(sexField);
      await tester.tap(sexField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();
      await _enterField(tester, 'Email address', 'buyer@example.test');
      await tester.ensureVisible(find.text('Send code'));
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      final code = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.maxLength == 6,
      );
      await tester.ensureVisible(code);
      await tester.enterText(code, '123456');
      await tester.tap(find.byTooltip('Verify email'));
      await tester.pumpAndSettle();
      await _enterField(tester, 'Mobile number', '9171234567');

      await tester.ensureVisible(find.text('Select birthday'));
      await tester.tap(find.text('Select birthday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _enterField(tester, 'Password', 'Password123');
      await _enterField(tester, 'Confirm password', 'Password123');
      final terms = find.text(
        'I agree to the Terms of Service and acknowledge the Privacy Policy.',
      );
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue →'));
      await tester.tap(find.text('Continue →'));
      await tester.pumpAndSettle();

      await _selectLocation(
        tester,
        'Select Region',
        'Region IV-A (CALABARZON)',
      );
      await _selectLocation(tester, 'Select Province', 'Laguna');
      await _selectLocation(
        tester,
        'Select City / Municipality',
        'City of San Pablo',
      );
      await _selectLocation(tester, 'Select Barangay', 'San Rafael');
      await _enterField(tester, 'Street name', 'Bearly Street');
      await _enterField(tester, 'House / Unit no.', '12');
      await tester.ensureVisible(find.text('Continue →'));
      await tester.tap(find.text('Continue →'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit application →'));
      await tester.tap(find.text('Submit application →'));
      await tester.pumpAndSettle();

      final payload = registration.buyerFields!;
      expect(payload['region'], 'Region IV-A (CALABARZON)');
      expect(payload['region_code'], '0400000000');
      expect(payload['province'], 'Laguna');
      expect(payload['city'], 'City of San Pablo');
      expect(payload['city_code'], '0403424000');
      expect(payload['barangay'], 'San Rafael');
      expect(payload['street_name'], 'Bearly Street');
      expect(payload['house_number'], '12');
      expect(payload['postal_code'], '4000');
      expect(payload['sex'], 'female');
      expect(payload['terms'], '1');
      expect(find.text('registration-result'), findsOneWidget);
    },
  );

  testWidgets(
    'Buyer success result reflects immediate activation rather than review',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const PendingPage(
            outcome: RegistrationOutcome(
              userId: 15,
              name: 'Buyer Applicant',
              email: 'buyer@example.test',
              role: 'buyer',
              status: 'active',
              message: 'Buyer account active.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buyer account activated'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Pending review'), findsNothing);
      expect(find.text('Valid government ID'), findsNothing);
    },
  );

  testWidgets(
    'Courier pending result remains a Rider account and shows the actual sponsor',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const PendingPage(
            outcome: RegistrationOutcome(
              userId: 16,
              name: 'Courier Applicant',
              email: 'courier@example.test',
              role: 'rider',
              status: 'pending',
              message: 'Application received.',
              workType: 'courier',
              reviewAuthority: 'Laguna Logistics Center',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Courier (Rider account)'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Laguna Logistics Center'), findsWidgets);
      expect(find.text('Admin review'), findsNothing);
    },
  );

  testWidgets('rejected applications show the server decision and reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const PendingPage(
          outcome: RegistrationOutcome(
            userId: 45,
            name: 'Logistics Applicant',
            email: 'logistics@example.test',
            role: 'logistics',
            status: 'rejected',
            message: 'The submitted business permit was not accepted.',
            reviewAuthority: 'Bearly Administrator',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Application not approved'), findsNWidgets(2));
    expect(find.text('Rejected'), findsOneWidget);
    expect(
      find.text('The submitted business permit was not accepted.'),
      findsWidgets,
    );
    expect(find.text('Pending review'), findsNothing);
  });
}

Widget _registrationApp(_FakeRegistrationDataSource registration) =>
    MaterialApp(
      home: RegisterPage(
        registrationDataSource: registration,
        psgcService: _FakePsgcService(),
      ),
    );

class _FakePsgcService extends PsgcService {
  @override
  Future<List<LocationOption>> regions() async => const [
    LocationOption(name: 'Region IV-A (CALABARZON)', code: '0400000000'),
  ];
}

class _FakeAddressService extends PsgcService {
  @override
  Future<List<LocationOption>> regions() async => const [
    LocationOption(name: 'Region IV-A (CALABARZON)', code: '0400000000'),
  ];

  @override
  Future<List<LocationOption>> provincesForRegion(String regionCode) async =>
      const [LocationOption(name: 'Laguna', code: '04034')];

  @override
  Future<List<LocationOption>> cities(String provinceCode) async => const [
    LocationOption(name: 'City of San Pablo', code: '0403424000'),
  ];

  @override
  Future<List<LocationOption>> barangays(String cityCode) async => const [
    LocationOption(name: 'San Rafael', code: '0403424001'),
  ];
}

class _FakePostalCodeService extends PostalCodeService {
  @override
  Future<PostalCodeResult> lookup({
    required String province,
    required String city,
  }) async => const PostalCodeResult.found('4000');
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> _selectLocation(
  WidgetTester tester,
  String prompt,
  String option,
) async {
  final field = find.text(prompt);
  await tester.dragUntilVisible(
    field,
    find.byType(ListView).first,
    const Offset(0, 240),
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

class _FakeRegistrationDataSource implements RegistrationDataSource {
  final sentEmails = <String>[];
  final verifiedCodes = <String>[];
  Map<String, Object?>? buyerFields;

  @override
  Future<RegistrationVerificationChallenge> sendEmailCode(String email) async {
    sentEmails.add(email);
    return RegistrationVerificationChallenge(
      verificationId: _verificationId,
      retryAfter: 0,
      expiresIn: 300,
    );
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
    required String verificationId,
  }) async {
    verifiedCodes.add(code);
  }

  @override
  Future<List<RegistrationPartner>> logisticsPartners(String cityCode) async =>
      const [];

  @override
  Future<RegistrationOutcome> registerBuyer(Map<String, Object?> fields) async {
    buyerFields = fields;
    return const RegistrationOutcome(
      userId: 42,
      name: 'Buyer Applicant',
      email: 'buyer@example.test',
      role: 'buyer',
      status: 'active',
      message: 'Buyer account active.',
    );
  }

  @override
  Future<RegistrationOutcome> registerRider({
    required Map<String, String> fields,
    required List<ApiMultipartFile> documents,
  }) async => const RegistrationOutcome(
    userId: 43,
    name: 'Rider Applicant',
    email: 'rider@example.test',
    role: 'rider',
    status: 'pending',
    message: 'Rider application pending.',
  );

  @override
  Future<RegistrationOutcome> registerLogistics({
    required Map<String, String> fields,
    required List<ApiMultipartFile> documents,
  }) async => const RegistrationOutcome(
    userId: 44,
    name: 'Logistics Applicant',
    email: 'logistics@example.test',
    role: 'logistics',
    status: 'pending',
    message: 'Logistics application pending.',
  );
}
