import 'dart:convert';

import 'package:flutter/services.dart';

class PostalCodeResult {
  const PostalCodeResult._({
    this.code,
    this.requiresManualEntry = false,
  });

  const PostalCodeResult.found(String code)
      : this._(code: code, requiresManualEntry: false);

  const PostalCodeResult.manual()
      : this._(code: null, requiresManualEntry: true);

  const PostalCodeResult.unavailable()
      : this._(code: null, requiresManualEntry: false);

  final String? code;
  final bool requiresManualEntry;

  bool get found => code != null && code!.isNotEmpty;
}

class PostalCodeService {
  Map<String, dynamic>? _postalData;

  Future<void> _loadData() async {
    if (_postalData != null) return;

    final raw = await rootBundle.loadString(
      'assets/data/ph-postal-codes.json',
    );

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Philippine postal-code data.');
    }

    _postalData = decoded;
  }

  Future<PostalCodeResult> lookup({
    required String province,
    required String city,
  }) async {
    await _loadData();

    final provinceKey = _findProvinceKey(province);
    if (provinceKey == null) {
      return const PostalCodeResult.unavailable();
    }

    final rawCities = _postalData![provinceKey];
    if (rawCities is! Map) {
      return const PostalCodeResult.unavailable();
    }

    final cities = rawCities.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final cityKey = _findCityKey(cities.keys, city);
    if (cityKey == null) {
      return const PostalCodeResult.unavailable();
    }

    final zip = cities[cityKey];

    if (zip is List) {
      return const PostalCodeResult.manual();
    }

    final code = zip?.toString().trim() ?? '';
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      return const PostalCodeResult.unavailable();
    }

    return PostalCodeResult.found(code);
  }

  String? _findProvinceKey(String provinceName) {
    final target = _normalizeProvince(provinceName);

    for (final key in _postalData!.keys) {
      if (_normalizeProvince(key) == target) {
        return key;
      }
    }

    return null;
  }

  String? _findCityKey(Iterable<String> keys, String cityName) {
    final target = _normalize(cityName);

    for (final key in keys) {
      if (_normalize(key) == target) {
        return key;
      }
    }

    for (final key in keys) {
      final normalizedKey = _normalize(key);
      if (normalizedKey.startsWith('$target ') ||
          target.startsWith('$normalizedKey ')) {
        return key;
      }
    }

    return null;
  }

  String _normalizeProvince(String value) {
    final cleaned = _normalize(value);

    const aliases = <String, String>{
      'metropolitan manila': 'metro manila',
      'national capital region': 'metro manila',
      'ncr': 'metro manila',
      'davao de oro': 'davao de oro formerly compostela valley',
      'compostela valley': 'davao de oro formerly compostela valley',
      'north cotabato': 'cotabato north',
      'cotabato': 'cotabato north',
      'camarines sur': 'camarines sur camsur',
    };

    return aliases[cleaned] ?? cleaned;
  }

  String _normalize(String value) {
    var text = value.toLowerCase().trim();

    const accents = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ñ': 'n',
    };

    accents.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    text = text
        .replaceAll('sta.', 'santa')
        .replaceAll('sto.', 'santo')
        .replaceAll('gen.', 'general')
        .replaceAll(RegExp(r'\bcity of\b'), '')
        .replaceAll(RegExp(r'\bcity\b'), '')
        .replaceAll(RegExp(r'\bmunicipality of\b'), '')
        .replaceAll(RegExp(r'\bmunicipality\b'), '')
        .replaceAll(RegExp(r'\bprovince of\b'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return text;
  }
}
