import 'package:bearly_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig', () {
    test('uses the compile-time URL or the emulator-safe default', () {
      const override = String.fromEnvironment('BEARLY_API_BASE_URL');
      final expected = override.isEmpty ? ApiConfig.defaultBaseUrl : override;

      expect(ApiConfig.configuredBaseUrl, expected);
      expect(ApiConfig.baseUrl, ApiConfig.normalizeBaseUrl(expected));
      expect(ApiConfig.psgcBase, '${ApiConfig.baseUrl}/api/psgc');
    });

    test('normalizes trailing slashes and validates the base URI', () {
      expect(ApiConfig.normalizeBaseUrl(' https://example.test/api/// '),
          'https://example.test/api');
      expect(ApiConfig.uriFrom('https://example.test/api///').path, '/api');
      expect(
        () => ApiConfig.uriFrom('https://user:password@example.test'),
        throwsFormatException,
      );
    });
  });
}
