import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationOption {
  const LocationOption({required this.name, required this.code});

  final String name;
  final String code;

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    return LocationOption(
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
    );
  }
}

class PsgcException implements Exception {
  const PsgcException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PsgcService {
  const PsgcService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const String _baseUrl = 'https://psgc.cloud/api/v2';

  Future<List<LocationOption>> regions() async {
    final items = await _get('/regions');
    return items
        .where((item) => RegExp(r'^\d{10}$').hasMatch(item.code))
        .toList();
  }

  Future<List<LocationOption>> provinces() {
    return _get('/provinces');
  }

  Future<List<LocationOption>> provincesForRegion(String regionCode) {
    if (!RegExp(r'^\d{10}$').hasMatch(regionCode)) {
      throw const PsgcException('Select a valid PSGC region first.');
    }

    return _get('/regions/$regionCode/provinces');
  }

  Future<List<LocationOption>> cities(String provinceCode) {
    return _get('/provinces/$provinceCode/cities-municipalities');
  }

  Future<List<LocationOption>> barangays(String cityCode) {
    return _get('/cities-municipalities/$cityCode/barangays');
  }

  Future<List<LocationOption>> _get(String path) async {
    final client = _client ?? http.Client();

    try {
      final uri = Uri.parse('$_baseUrl$path');

      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PsgcException(
          'Address service returned HTTP ${response.statusCode}.',
        );
      }

      final dynamic payload = jsonDecode(response.body);

      final dynamic raw = payload is List ? payload : payload['data'];

      if (raw is! List) {
        throw const PsgcException('Unexpected address service response.');
      }

      final items =
          raw
              .whereType<Map<String, dynamic>>()
              .map(LocationOption.fromJson)
              .where((item) => item.name.isNotEmpty && item.code.isNotEmpty)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      return items;
    } catch (error) {
      if (error is PsgcException) {
        rethrow;
      }

      throw PsgcException('Address service is unavailable: $error');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}
