import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Datos de un lanzamiento en MusicBrainz.
class MbRelease {
  const MbRelease(this.id, this.title, this.year, this.lang);
  final String id;
  final String title;
  final int year;

  /// 'en', 'es' o null si MusicBrainz no lo indica.
  final String? lang;
}

/// MusicBrainz (gratis, sin cuenta). Respeta 1 petición por segundo y envía
/// un User-Agent propio. Cualquier error de red devuelve null.
class MusicBrainz {
  static const userAgent = 'VinylSolutions/1.0 (https://github.com/pytngdfv1-ai/vinyl-solutions)';
  static const headers = {'User-Agent': userAgent, 'Accept': 'application/json'};

  static final http.Client _client = http.Client();
  static Future<void> _gate = Future<void>.value();
  static final Map<String, MbRelease?> _cache = {};

  /// Una sola petición a la vez, separadas por ≥ 1,1 s.
  static Future<T> _throttled<T>(Future<T> Function() job) {
    final c = Completer<T>();
    _gate = _gate.then((_) async {
      try {
        c.complete(await job());
      } catch (e, st) {
        c.completeError(e, st);
      }
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    });
    return c.future;
  }

  /// GET JSON a MusicBrainz respetando el límite de 1 petición por segundo.
  static Future<dynamic> getJson(Uri uri) async {
    try {
      return await _throttled(() async {
        final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
        return res.statusCode == 200 ? jsonDecode(utf8.decode(res.bodyBytes)) : null;
      });
    } catch (_) {
      return null;
    }
  }

  static String _n(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _same(String a, String b) {
    final x = _n(a);
    final y = _n(b);
    return x.isNotEmpty && y.isNotEmpty && (x == y || x.contains(y) || y.contains(x));
  }

  static String? _lang(Object? code) {
    final c = '${code ?? ''}'.toLowerCase();
    if (c == 'eng') return 'en';
    if (c == 'spa') return 'es';
    return null;
  }

  /// Busca el lanzamiento del álbum de ese artista.
  static Future<MbRelease?> release(String artist, String album) async {
    final key = '${_n(artist)}|${_n(album)}';
    if (_cache.containsKey(key)) return _cache[key];
    MbRelease? out;
    try {
      final j = await _throttled(() async {
        final res = await _client
            .get(
              Uri.https('musicbrainz.org', '/ws/2/release/', {
                'query': 'release:"$album" AND artist:"$artist"',
                'fmt': 'json',
                'limit': '5',
              }),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));
        return res.statusCode == 200 ? jsonDecode(utf8.decode(res.bodyBytes)) : null;
      });
      if (j is Map) {
        for (final r in (j['releases'] as List? ?? const [])) {
          if (r is! Map) continue;
          final credits = (r['artist-credit'] as List? ?? const []);
          final okArtist =
              credits.any((c) => c is Map && _same(c['name'] as String? ?? '', artist));
          if (!okArtist || !_same(r['title'] as String? ?? '', album)) continue;
          final m = RegExp(r'(19|20)\d{2}').firstMatch('${r['date'] ?? ''}');
          final tr = r['text-representation'];
          out = MbRelease(
            r['id'] as String,
            r['title'] as String? ?? album,
            m == null ? 0 : int.parse(m.group(0)!),
            tr is Map ? _lang(tr['language']) : null,
          );
          break;
        }
      }
    } catch (_) {
      return null; // sin conexión: no se guarda en caché para reintentar luego
    }
    _cache[key] = out;
    return out;
  }

  /// URL de la portada (Cover Art Archive) si existe.
  static Future<String?> frontCover(MbRelease r) async {
    final url = 'https://coverartarchive.org/release/${r.id}/front-500';
    try {
      final res = await _client
          .send(http.Request('HEAD', Uri.parse(url))..headers.addAll(headers))
          .timeout(const Duration(seconds: 8));
      await res.stream.drain<void>();
      return res.statusCode == 200 ? url : null;
    } catch (_) {
      return null;
    }
  }
}
