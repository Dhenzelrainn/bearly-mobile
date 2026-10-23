import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../models/account_role.dart';

abstract interface class SessionTokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

class SecureSessionTokenStore implements SessionTokenStore {
  SecureSessionTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'bearly.mobile.sanctum_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _tokenKey);
}

class AuthSession {
  const AuthSession({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String email;
  final AccountRole role;

  factory AuthSession.fromJson(Object? value) {
    if (value is! Map) {
      throw const AuthException(
        'Bearly returned an unreadable account response.',
      );
    }

    final idValue = value['id'];
    final id = idValue is int ? idValue : int.tryParse('$idValue');
    final roleValue = value['role'];
    final status = value['status'];
    final email = value['email'];
    final name = value['name'];

    if (status != 'active' || (roleValue != 'buyer' && roleValue != 'rider')) {
      throw const AuthException(
        'This account is not eligible to use the Bearly mobile app.',
        clearSession: true,
      );
    }

    if (id == null ||
        id <= 0 ||
        email is! String ||
        email.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const AuthException(
        'Bearly returned an incomplete account response.',
      );
    }

    return AuthSession(
      id: id,
      name: name.trim(),
      email: email.trim(),
      role: roleValue == 'buyer' ? AccountRole.buyer : AccountRole.rider,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message, {this.clearSession = false});

  final String message;
  final bool clearSession;

  @override
  String toString() => message;
}

/// HTTP methods available to authenticated feature repositories.
enum AuthenticatedRequestMethod { get, post, put, patch, delete }

/// Laravel mobile authentication and secure local session lifecycle.
class AuthService {
  AuthService({ApiClient? apiClient, SessionTokenStore? tokenStore})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStore = tokenStore ?? SecureSessionTokenStore();

  final ApiClient _apiClient;
  final SessionTokenStore _tokenStore;

  AuthSession? currentSession;
  String? _ephemeralToken;

  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final Object? response;
    try {
      response = await _apiClient.post(
        '/api/mobile/login',
        body: {'email': email.trim(), 'password': password},
      );
    } on ApiException catch (error) {
      throw AuthException(_loginErrorMessage(error));
    }

    final payload = _asMap(response);
    final token = payload['token'];
    if (token is! String || token.trim().isEmpty) {
      throw const AuthException('Bearly did not return a sign-in token.');
    }

    late final AuthSession session;
    try {
      session = AuthSession.fromJson(payload['user']);
    } on AuthException {
      await _revokeUnstoredToken(token);
      rethrow;
    }

    try {
      if (rememberMe) {
        await _tokenStore.write(token);
        _ephemeralToken = null;
      } else {
        await _tokenStore.clear();
        _ephemeralToken = token;
      }
    } catch (_) {
      await _revokeUnstoredToken(token);
      throw const AuthException(
        'Bearly could not save this session securely. Try again.',
      );
    }

    currentSession = session;
    return session;
  }

  /// Validates any saved token against Laravel's current account state.
  ///
  /// An explicit 401/403 or ineligible account clears the saved token. Network,
  /// timeout, server, and malformed-response failures keep it so the user can
  /// retry verification when Bearly is reachable again.
  Future<AuthSession?> restoreSession() async {
    final token = await _tokenStore.read();
    if (token == null || token.trim().isEmpty) {
      currentSession = null;
      return null;
    }

    try {
      final response = await _apiClient.get(
        '/api/mobile/me',
        headers: _authorization(token),
      );
      final payload = _asMap(response);
      final session = AuthSession.fromJson(payload['user']);
      currentSession = session;
      return session;
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearLocalSession();
        return null;
      }
      rethrow;
    } on AuthException catch (error) {
      if (error.clearSession) await _clearLocalSession();
      rethrow;
    }
  }

  /// Sends a read-only authenticated request using the active local session.
  ///
  /// The credential remains inside this service. Explicit 401/403 responses
  /// follow the same local invalidation behavior as session restoration;
  /// transient API, timeout, and transport failures leave the session intact.
  Future<Object?> getWithSession(
    String path, {
    Map<String, Object?>? queryParameters,
  }) => requestWithSession<Object?>(
    method: AuthenticatedRequestMethod.get,
    path: path,
    queryParameters: queryParameters,
    parse: (response) => response,
  );

  /// Sends an authenticated request while keeping the Sanctum credential
  /// inside this service, then parses the decoded response into [T].
  ///
  /// Only explicit 401/403 responses invalidate the session. Transport,
  /// timeout, server, malformed JSON, and response-contract failures keep it.
  Future<T> requestWithSession<T>({
    required AuthenticatedRequestMethod method,
    required String path,
    Map<String, Object?>? queryParameters,
    Object? body,
    required T Function(Object? response) parse,
  }) async {
    final token = _ephemeralToken ?? await _tokenStore.read();
    if (token == null || token.trim().isEmpty) {
      throw const AuthException('Sign in to access this Bearly resource.');
    }

    try {
      final headers = _authorization(token);
      final Object? response = switch (method) {
        AuthenticatedRequestMethod.get => await _apiClient.get(
          path,
          queryParameters: queryParameters,
          headers: headers,
        ),
        AuthenticatedRequestMethod.post => await _apiClient.post(
          path,
          queryParameters: queryParameters,
          headers: headers,
          body: body,
        ),
        AuthenticatedRequestMethod.put => await _apiClient.put(
          path,
          queryParameters: queryParameters,
          headers: headers,
          body: body,
        ),
        AuthenticatedRequestMethod.patch => await _apiClient.patch(
          path,
          queryParameters: queryParameters,
          headers: headers,
          body: body,
        ),
        AuthenticatedRequestMethod.delete => await _apiClient.delete(
          path,
          queryParameters: queryParameters,
          headers: headers,
          body: body,
        ),
      };
      return parse(response);
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearLocalSession();
      }
      rethrow;
    }
  }

  /// Attempts server revocation, then always removes the local credential.
  Future<void> logout() async {
    String? token;
    try {
      token = _ephemeralToken ?? await _tokenStore.read();
      if (token != null && token.trim().isNotEmpty) {
        await _apiClient.post(
          '/api/mobile/logout',
          headers: _authorization(token),
        );
      }
    } catch (_) {
      // Local sign-out must still complete when Laravel cannot be reached.
    } finally {
      await _clearLocalSession();
    }
  }

  Future<void> _revokeUnstoredToken(String token) async {
    try {
      await _apiClient.post(
        '/api/mobile/logout',
        headers: _authorization(token),
      );
    } catch (_) {
      // The token was never saved on this device; discard any failed revoke.
    }
  }

  Future<void> _clearLocalSession() async {
    await _tokenStore.clear();
    _ephemeralToken = null;
    currentSession = null;
  }

  static Map<String, String> _authorization(String token) => {
    'Authorization': 'Bearer $token',
  };

  static Map _asMap(Object? value) {
    if (value is Map) return value;
    throw const AuthException('Bearly returned an unreadable response.');
  }

  static String _loginErrorMessage(ApiException error) {
    if (error is ApiTransportException || error is ApiTimeoutException) {
      return 'Could not reach Bearly. Check your connection and try again.';
    }
    if (error is ApiHttpException) {
      if (error.statusCode == 401) return 'Invalid email or password.';
      if (error.statusCode == 403) {
        return _serverMessage(error.responseData) ??
            'This account is not eligible to use the Bearly mobile app.';
      }
      if (error.statusCode == 429) {
        return _serverMessage(error.responseData) ??
            'Too many sign-in attempts. Try again later.';
      }
    }
    return 'Bearly could not complete sign-in. Try again.';
  }

  static String? _serverMessage(Object? responseData) {
    if (responseData is! Map) return null;
    final message = responseData['message'];
    if (message is! String || message.trim().isEmpty || message.length > 200) {
      return null;
    }
    return message.trim();
  }
}
