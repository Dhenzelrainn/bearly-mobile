import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RiderMapTileContent {
  const RiderMapTileContent({required this.bytes, this.isStale = false});

  final Uint8List bytes;
  final bool isStale;
}

abstract interface class RiderMapTileSource {
  Future<RiderMapTileContent> load(String tileUrl);
}

/// A bounded, persistent cache for tiles requested for the visible map.
/// Requests honor the tile server's freshness and validator headers and use a
/// seven-day fallback only when the server supplies no cache lifetime.
class RiderMapTileCache implements RiderMapTileSource {
  RiderMapTileCache({
    http.Client? client,
    Future<Directory> Function()? cacheDirectory,
    DateTime Function()? now,
    this.maxEntries = 300,
  }) : _client = client ?? http.Client(),
       _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory,
       _now = now ?? DateTime.now;

  static const userAgent = 'BearlyMobile/1.0 (+https://bearlymarket.com)';
  static const _fallbackTtl = Duration(days: 7);
  static const _cacheDirectoryName = 'bearly-rider-map-tiles';
  static final RiderMapTileCache instance = RiderMapTileCache();

  final http.Client _client;
  final Future<Directory> Function() _cacheDirectory;
  final DateTime Function() _now;
  final int maxEntries;
  final Map<String, Future<RiderMapTileContent>> _inFlight = {};

  void dispose() => _client.close();

  @override
  Future<RiderMapTileContent> load(String tileUrl) async {
    final existing = _inFlight[tileUrl];
    if (existing != null) return existing;

    final pending = _load(tileUrl);
    _inFlight[tileUrl] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_inFlight[tileUrl], pending)) _inFlight.remove(tileUrl);
    }
  }

  Future<RiderMapTileContent> _load(String tileUrl) async {
    final uri = Uri.tryParse(tileUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      throw const FormatException('Map tile URL must use a public HTTPS host.');
    }

    final directory = await _cacheDirectory();
    await directory.create(recursive: true);
    final key = sha256.convert(utf8.encode(tileUrl)).toString();
    final imageFile = File(_path(directory, '$key.png'));
    final metadataFile = File(_path(directory, '$key.json'));
    Uint8List? cachedBytes;
    _TileMetadata? metadata;

    if (await imageFile.exists()) {
      cachedBytes = await imageFile.readAsBytes();
      metadata = await _readMetadata(metadataFile);
      if (metadata == null) {
        final modified = (await imageFile.stat()).modified.toUtc();
        metadata = _TileMetadata(expiresAt: modified.add(_fallbackTtl));
      }
      if (cachedBytes.isNotEmpty &&
          _now().toUtc().isBefore(metadata.expiresAt)) {
        await imageFile.setLastModified(_now());
        return RiderMapTileContent(bytes: cachedBytes);
      }
    }

    final requestHeaders = <String, String>{'User-Agent': userAgent};
    if (metadata?.etag case final String etag when etag.isNotEmpty) {
      requestHeaders['If-None-Match'] = etag;
    }
    if (metadata?.lastModified case final String lastModified
        when lastModified.isNotEmpty) {
      requestHeaders['If-Modified-Since'] = lastModified;
    }

    try {
      final response = await _client.get(uri, headers: requestHeaders);
      if (response.statusCode == HttpStatus.notModified &&
          cachedBytes != null &&
          cachedBytes.isNotEmpty) {
        final updated = _metadataFromHeaders(
          response.headers,
          previous: metadata,
          now: _now().toUtc(),
        );
        if (updated == null) {
          await _removeCache(imageFile, metadataFile);
        } else {
          await _writeMetadata(metadataFile, updated);
        }
        await imageFile.setLastModified(_now());
        return RiderMapTileContent(bytes: cachedBytes);
      }
      if (response.statusCode != HttpStatus.ok || response.bodyBytes.isEmpty) {
        throw HttpException(
          'Map tile request failed (${response.statusCode}).',
        );
      }
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.isNotEmpty && !contentType.startsWith('image/')) {
        throw const FormatException(
          'Map tile server returned a non-image response.',
        );
      }

      final updated = _metadataFromHeaders(
        response.headers,
        now: _now().toUtc(),
      );
      if (updated == null) {
        await _removeCache(imageFile, metadataFile);
      } else {
        await imageFile.writeAsBytes(response.bodyBytes, flush: true);
        await _writeMetadata(metadataFile, updated);
        await _prune(directory);
      }
      return RiderMapTileContent(bytes: response.bodyBytes);
    } catch (_) {
      if (cachedBytes != null && cachedBytes.isNotEmpty) {
        return RiderMapTileContent(bytes: cachedBytes, isStale: true);
      }
      rethrow;
    }
  }

  Future<_TileMetadata?> _readMetadata(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final expiresAt = DateTime.tryParse(
        decoded['expires_at'] as String? ?? '',
      );
      if (expiresAt == null) return null;
      return _TileMetadata(
        expiresAt: expiresAt.toUtc(),
        etag: decoded['etag'] as String?,
        lastModified: decoded['last_modified'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  _TileMetadata? _metadataFromHeaders(
    Map<String, String> headers, {
    _TileMetadata? previous,
    required DateTime now,
  }) {
    final cacheControl = headers['cache-control']?.toLowerCase() ?? '';
    if (cacheControl
        .split(',')
        .any((directive) => directive.trim() == 'no-store')) {
      return null;
    }

    DateTime? expiresAt;
    if (cacheControl
        .split(',')
        .any((directive) => directive.trim() == 'no-cache')) {
      expiresAt = now;
    } else {
      final maxAge = RegExp(
        r'(?:^|,)\s*max-age\s*=\s*"?(\d+)"?',
      ).firstMatch(cacheControl)?.group(1);
      if (maxAge != null) {
        expiresAt = now.add(Duration(seconds: int.parse(maxAge)));
      } else {
        expiresAt = _parseHttpDate(headers['expires']);
      }
    }

    return _TileMetadata(
      expiresAt: expiresAt ?? now.add(_fallbackTtl),
      etag: headers['etag'] ?? previous?.etag,
      lastModified: headers['last-modified'] ?? previous?.lastModified,
    );
  }

  Future<void> _writeMetadata(File file, _TileMetadata metadata) async {
    await file.writeAsString(
      jsonEncode({
        'expires_at': metadata.expiresAt.toUtc().toIso8601String(),
        'etag': metadata.etag,
        'last_modified': metadata.lastModified,
      }),
      flush: true,
    );
  }

  Future<void> _removeCache(File imageFile, File metadataFile) async {
    if (await imageFile.exists()) await imageFile.delete();
    if (await metadataFile.exists()) await metadataFile.delete();
  }

  Future<void> _prune(Directory directory) async {
    final entries = <({File image, DateTime modified})>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        entries.add((image: entity, modified: (await entity.stat()).modified));
      }
    }
    if (entries.length <= maxEntries) return;
    entries.sort((a, b) => b.modified.compareTo(a.modified));
    for (final entry in entries.skip(maxEntries)) {
      await _removeCache(
        entry.image,
        File(
          '${entry.image.path.substring(0, entry.image.path.length - 4)}.json',
        ),
      );
    }
  }

  String _path(Directory directory, String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  DateTime? _parseHttpDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      return null;
    }
  }

  static Future<Directory> _defaultCacheDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}$_cacheDirectoryName',
    );
  }
}

class _TileMetadata {
  const _TileMetadata({required this.expiresAt, this.etag, this.lastModified});

  final DateTime expiresAt;
  final String? etag;
  final String? lastModified;
}
