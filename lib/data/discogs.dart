import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Discogs es opcional: solo se usa si pegas tu propio token en Ajustes.
class Discogs {
  static const _key = 'discogs_token';
  static const _store = FlutterSecureStorage();
  static String token = '';

  static Future<void> load() async {
    try {
      token = (await _store.read(key: _key)) ?? '';
    } catch (_) {}
  }

  static Future<void> save(String t) async {
    token = t.trim();
    try {
      if (token.isEmpty) {
        await _store.delete(key: _key);
      } else {
        await _store.write(key: _key, value: token);
      }
    } catch (_) {}
  }

  static bool get enabled => token.isNotEmpty;

  /// Portada y año de un álbum; null si no hay token o no se encuentra.
  static Future<({String url, int year})?> album(String artist, String album) async {
    if (!enabled) return null;
    try {
      final res = await http.get(
        Uri.https('api.discogs.com', '/database/search', {
          'artist': artist,
          'release_title': album,
          'type': 'release',
          'per_page': '5',
          'token': token,
        }),
        headers: const {'User-Agent': 'VinylSolutions/1.0 (personal music library app)'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      for (final r in (j['results'] as List? ?? const [])) {
        if (r is! Map) continue;
        final img = r['cover_image'] as String?;
        if (img == null || img.isEmpty || img.contains('spacer.gif')) continue;
        final y = int.tryParse('${r['year'] ?? ''}') ?? 0;
        return (url: img, year: y);
      }
    } catch (_) {}
    return null;
  }
}
