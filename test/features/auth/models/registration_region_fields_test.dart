import 'package:bearly_mobile/features/auth/models/registration_region_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegistrationRegionFields', () {
    test('serializes a required region and selected 10-digit PSGC code', () {
      const fields = RegistrationRegionFields(
        region: '  Calabarzon  ',
        regionCode: '0400000000',
      );

      expect(fields.toJson(), {
        'region': 'Calabarzon',
        'region_code': '0400000000',
      });
    });

    test('omits the optional region code when it was not selected', () {
      const fields = RegistrationRegionFields(region: 'Bicol Region');

      expect(fields.toJson(), {'region': 'Bicol Region'});
    });

    test('requires a non-empty region', () {
      expect(RegistrationRegionFields.validateRegion('  '), isNotNull);
      expect(RegistrationRegionFields.validateRegion('Cordillera'), isNull);
      expect(
        () => const RegistrationRegionFields(region: ' ').toJson(),
        throwsArgumentError,
      );
    });

    test('rejects a supplied region code unless it has exactly ten digits', () {
      expect(RegistrationRegionFields.validateRegionCode(null), isNull);
      expect(RegistrationRegionFields.validateRegionCode(''), isNull);
      expect(
        RegistrationRegionFields.validateRegionCode('123456789'),
        isNotNull,
      );
      expect(
        RegistrationRegionFields.validateRegionCode('12345678901'),
        isNotNull,
      );
      expect(
        RegistrationRegionFields.validateRegionCode('12345A7890'),
        isNotNull,
      );
      expect(RegistrationRegionFields.validateRegionCode('0400000000'), isNull);
      expect(
        () => const RegistrationRegionFields(
          region: 'Calabarzon',
          regionCode: '040000000',
        ).toJson(),
        throwsArgumentError,
      );
    });
  });
}
