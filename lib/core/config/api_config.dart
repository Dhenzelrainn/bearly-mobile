class ApiConfig {
  const ApiConfig._();

  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  static const String configuredBaseUrl = String.fromEnvironment(
    'BEARLY_API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  /// The configured API origin with trailing slashes removed.
  static String get baseUrl => normalizeBaseUrl(configuredBaseUrl);

  /// Existing PSGC API reference, now derived from the selected API origin.
  static String get psgcBase => '$baseUrl/api/psgc';

  static Uri get baseUri => uriFrom(baseUrl);

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('The API base URL must not be empty.');
    }

    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  /// Parses and validates an absolute HTTP(S) API URL without embedded
  /// credentials, a query string, or a fragment.
  static Uri uriFrom(String value) {
    final normalized = normalizeBaseUrl(value);
    final Uri uri;
    try {
      uri = Uri.parse(normalized);
    } on FormatException {
      throw const FormatException('The API base URL must be a valid HTTP(S) URL.');
    }

    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'The API base URL must be an absolute HTTP(S) URL without credentials, query, or fragment.',
      );
    }

    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }
}
