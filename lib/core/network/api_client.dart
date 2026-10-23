import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

enum ApiErrorKind {
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  server,
  client,
  unknown,
}

abstract class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class ApiHttpException extends ApiException {
  ApiHttpException({
    required this.statusCode,
    required this.responseData,
    required this.responseWasJson,
  }) : kind = _kindForStatus(statusCode),
       validationErrors = _extractValidationErrors(statusCode, responseData),
       super(_messageForStatus(statusCode));

  final int statusCode;
  final ApiErrorKind kind;

  /// Parsed server data, when the response contained valid JSON.
  ///
  /// This value is deliberately omitted from [toString] because a server may
  /// include user supplied or otherwise sensitive values in an error body.
  final Object? responseData;
  final bool responseWasJson;
  final Map<String, List<String>> validationErrors;

  @override
  String toString() => 'ApiHttpException: $message (HTTP $statusCode)';
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException(this.timeout)
    : super('The request timed out.');

  final Duration timeout;
}

class ApiTransportException extends ApiException {
  const ApiTransportException()
    : super('The request could not reach the server.');
}

class ApiFormatException extends ApiException {
  const ApiFormatException({required this.statusCode})
    : super('The server returned an invalid JSON response.');

  final int statusCode;
}

/// Small JSON HTTP client shared by future Bearly mobile features.
///
/// Pass an injected [http.Client] for tests. The client does not make requests
/// during construction and does not log URLs, headers, request bodies, or
/// response bodies.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
    Uri? baseUri,
  }) : _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _baseUri = _validatedBaseUri(baseUri ?? ApiConfig.baseUri) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be greater than zero.');
    }
  }

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;
  final Duration timeout;

  Future<Object?> get(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
  }) => _request('GET', path, queryParameters: queryParameters, headers: headers);

  Future<Object?> post(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) => _request(
    'POST',
    path,
    queryParameters: queryParameters,
    headers: headers,
    body: body,
  );

  Future<Object?> put(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) => _request(
    'PUT',
    path,
    queryParameters: queryParameters,
    headers: headers,
    body: body,
  );

  Future<Object?> patch(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) => _request(
    'PATCH',
    path,
    queryParameters: queryParameters,
    headers: headers,
    body: body,
  );

  Future<Object?> delete(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) => _request(
    'DELETE',
    path,
    queryParameters: queryParameters,
    headers: headers,
    body: body,
  );

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final requestHeaders = _buildHeaders(headers, hasBody: body != null);
    final encodedBody = body == null ? null : jsonEncode(body);

    final http.Response response;
    try {
      response = await _send(
        method,
        uri,
        headers: requestHeaders,
        body: encodedBody,
      ).timeout(timeout);
    } on TimeoutException {
      throw ApiTimeoutException(timeout);
    } on http.ClientException {
      throw const ApiTransportException();
    }

    final responseText = response.body.trim();
    Object? responseData;
    var responseWasJson = false;
    if (responseText.isNotEmpty) {
      try {
        responseData = jsonDecode(responseText);
        responseWasJson = true;
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw ApiFormatException(statusCode: response.statusCode);
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(
        statusCode: response.statusCode,
        responseData: responseData,
        responseWasJson: responseWasJson,
      );
    }

    return responseData;
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    required String? body,
  }) {
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PUT':
        return _client.put(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: body);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method.');
    }
  }

  Uri _buildUri(String path, Map<String, Object?>? queryParameters) {
    final Uri endpoint;
    try {
      endpoint = Uri.parse(path);
    } on FormatException {
      throw ArgumentError('The API path must be a valid relative URI.');
    }
    if (endpoint.hasScheme || endpoint.hasAuthority || endpoint.hasFragment) {
      throw ArgumentError('The API path must be relative and cannot contain a fragment.');
    }

    final basePath = _baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final endpointPath = endpoint.path.replaceFirst(RegExp(r'^/+'), '');
    final joinedPath = endpointPath.isEmpty
        ? (basePath.isEmpty ? '/' : '$basePath/')
        : '${basePath.isEmpty ? '' : '$basePath/'}$endpointPath';

    final mergedQuery = <String, dynamic>{
      for (final entry in endpoint.queryParametersAll.entries)
        entry.key: entry.value,
    };
    queryParameters?.forEach((key, value) {
      if (value == null) {
        mergedQuery.remove(key);
      } else if (value is Iterable) {
        mergedQuery[key] = value.map((item) => item.toString()).toList();
      } else {
        mergedQuery[key] = value.toString();
      }
    });

    return _baseUri.replace(
      path: joinedPath,
      queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
    );
  }

  Map<String, String> _buildHeaders(
    Map<String, String>? supplied, {
    required bool hasBody,
  }) {
    final result = <String, String>{'Accept': 'application/json'};
    if (hasBody) {
      result['Content-Type'] = 'application/json; charset=utf-8';
    }

    supplied?.forEach((key, value) {
      String? previousKey;
      for (final existingKey in result.keys) {
        if (existingKey.toLowerCase() == key.toLowerCase()) {
          previousKey = existingKey;
          break;
        }
      }
      if (previousKey != null) result.remove(previousKey);
      result[key] = value;
    });
    return result;
  }

  static Uri _validatedBaseUri(Uri uri) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError(
        'The API base URL must be an absolute HTTP(S) URL without credentials, query, or fragment.',
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  /// Closes the internally-created client. An injected client remains owned by
  /// its caller so test fixtures can control its lifecycle.
  void close() {
    if (_ownsClient) _client.close();
  }
}

ApiErrorKind _kindForStatus(int statusCode) => switch (statusCode) {
  401 => ApiErrorKind.unauthenticated,
  403 => ApiErrorKind.forbidden,
  404 => ApiErrorKind.notFound,
  409 => ApiErrorKind.conflict,
  422 => ApiErrorKind.validation,
  429 => ApiErrorKind.rateLimited,
  >= 500 => ApiErrorKind.server,
  >= 400 => ApiErrorKind.client,
  _ => ApiErrorKind.unknown,
};

String _messageForStatus(int statusCode) => switch (statusCode) {
  401 => 'The request is unauthenticated.',
  403 => 'The operation is forbidden.',
  404 => 'The requested resource was not found.',
  409 => 'The request conflicts with the current server state.',
  422 => 'The request contains invalid data.',
  429 => 'Too many requests. Try again later.',
  >= 500 => 'The server could not complete the request.',
  >= 400 => 'The server rejected the request.',
  _ => 'The server returned an unexpected status code.',
};

Map<String, List<String>> _extractValidationErrors(
  int statusCode,
  Object? responseData,
) {
  if (statusCode != 422 || responseData is! Map) return const {};

  Object? errorData = responseData['errors'];
  if (errorData == null && responseData['data'] is Map) {
    errorData = (responseData['data'] as Map)['errors'];
  }
  if (errorData is! Map) return const {};

  final result = <String, List<String>>{};
  void collect(String key, Object? value) {
    if (value is String) {
      result.putIfAbsent(key, () => <String>[]).add(value);
    } else if (value is Iterable) {
      for (final item in value) {
        collect(key, item);
      }
    } else if (value is Map) {
      for (final entry in value.entries) {
        final nestedKey = key.isEmpty ? entry.key.toString() : '$key.${entry.key}';
        collect(nestedKey, entry.value);
      }
    }
  }

  for (final entry in errorData.entries) {
    collect(entry.key.toString(), entry.value);
  }

  return Map.unmodifiable({
    for (final entry in result.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  });
}
