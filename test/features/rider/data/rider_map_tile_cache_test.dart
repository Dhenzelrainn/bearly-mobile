import 'dart:io';

import 'package:bearly_mobile/features/rider/data/rider_map_tile_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory cacheDirectory;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'bearly-tile-cache-',
    );
  });

  tearDown(() async {
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  test('sends the Bearly User-Agent and reuses a fresh disk tile', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.headers['user-agent'], RiderMapTileCache.userAgent);
      expect(request.headers.containsKey('cache-control'), isFalse);
      return http.Response.bytes(
        [1, 2, 3],
        200,
        headers: {
          'cache-control': 'public, max-age=3600',
          'content-type': 'image/png',
          'etag': 'tile-v1',
        },
      );
    });
    final cache = RiderMapTileCache(
      client: client,
      cacheDirectory: () async => cacheDirectory,
      now: () => DateTime.utc(2026, 11, 8),
    );

    final first = await cache.load('https://tile.openstreetmap.org/10/4/7.png');
    final second = await cache.load(
      'https://tile.openstreetmap.org/10/4/7.png',
    );

    expect(first.bytes, [1, 2, 3]);
    expect(second.bytes, [1, 2, 3]);
    expect(second.isStale, isFalse);
    expect(requests, 1);
    expect(cacheDirectory.listSync(), hasLength(2));
    client.close();
  });

  test(
    'revalidates expired tiles with ETag and honors 304 freshness',
    () async {
      var now = DateTime.utc(2026, 11, 8);
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.headers['user-agent'], RiderMapTileCache.userAgent);
        if (requests == 1) {
          return http.Response.bytes(
            [7, 8, 9],
            200,
            headers: {
              'cache-control': 'max-age=0',
              'content-type': 'image/png',
              'etag': 'tile-v2',
            },
          );
        }
        expect(request.headers['if-none-match'], 'tile-v2');
        return http.Response(
          '',
          304,
          headers: {'cache-control': 'max-age=3600'},
        );
      });
      final cache = RiderMapTileCache(
        client: client,
        cacheDirectory: () async => cacheDirectory,
        now: () => now,
      );

      final first = await cache.load(
        'https://tile.openstreetmap.org/10/5/7.png',
      );
      now = now.add(const Duration(seconds: 1));
      final refreshed = await cache.load(
        'https://tile.openstreetmap.org/10/5/7.png',
      );
      final cached = await cache.load(
        'https://tile.openstreetmap.org/10/5/7.png',
      );

      expect(first.bytes, [7, 8, 9]);
      expect(refreshed.bytes, [7, 8, 9]);
      expect(cached.bytes, [7, 8, 9]);
      expect(requests, 2);
      client.close();
    },
  );

  test(
    'uses the seven-day fallback only when cache lifetime is absent',
    () async {
      var now = DateTime.utc(2026, 11, 8);
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response.bytes(
          [4],
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      final cache = RiderMapTileCache(
        client: client,
        cacheDirectory: () async => cacheDirectory,
        now: () => now,
      );

      await cache.load('https://tiles.example.test/10/5/8.png');
      now = now.add(const Duration(days: 6));
      await cache.load('https://tiles.example.test/10/5/8.png');
      now = now.add(const Duration(days: 2));
      await cache.load('https://tiles.example.test/10/5/8.png');

      expect(requests, 2);
      client.close();
    },
  );
}
