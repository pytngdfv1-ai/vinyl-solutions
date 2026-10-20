import 'dart:convert';

import 'package:http/http.dart' as http;

/// Portada encontrada y año de lanzamiento (0 = desconocido).
class CoverHit {
  const CoverHit(this.url, this.year);
  final String url;
  final int year;
}

int _yr(Object? s) {
  final m = RegExp(r'(19|20)\d{2}').firstMatch('${s ?? ''}');
  return m == null ? 0 : int.parse(m.group(0)!);
}

/// Busca la portada del álbum (o del lanzamiento del cover) en internet.
/// Orden: iTunes (álbum) → Deezer (álbum) → Cover Art Archive → iTunes (tema)
/// → Deezer (tema). Siempre exige que el artista sea quien interpreta el
/// disco, para no traer la portada del tema original de otro artista.
class CoverLookup {
  static final http.Client _client = http.Client();
  static const _ua = {'User-Agent': 'VinylSolutions/1.0 (personal music library app)'};

  static Future<CoverHit?> find({
    required String artist,
    required List<String> albums,
    List<String> tracks = const [],
    bool trackFirst = false,
  }) async {
    if (artist.trim().isEmpty) return null;
    final names = <String>{};
    for (final a in albums) {
      if (a.trim().isEmpty) continue;
      names.add(a.trim());
      final c = a.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '').trim();
      if (c.isNotEmpty) names.add(c);
    }
    Future<CoverHit?> byAlbums() async {
      for (final n in names) {
        final r = await _itunesAlbum(artist, n);
        if (r != null) return r;
      }
      for (final n in names) {
        final r = await _deezerAlbum(artist, n);
        if (r != null) return r;
      }
      for (final n in names) {
        final r = await _coverArtArchive(artist, n);
        if (r != null) return r;
      }
      return null;
    }

    Future<CoverHit?> byTracks() async {
      final ts = tracks.take(4).toList();
      for (final t in ts) {
        final r = await _itunesSong(artist, t);
        if (r != null) return r;
      }
      for (final t in ts) {
        final r = await _deezerTrack(artist, t);
        if (r != null) return r;
      }
      return null;
    }

    if (trackFirst) return await byTracks() ?? await byAlbums();
    return await byAlbums() ?? await byTracks();
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

  static Future<dynamic> _json(Uri uri, {Map<String, String>? headers}) async {
    try {
      final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  static String? _itunesArt(Map r) {
    final art = r['artworkUrl100'] as String?;
    return art?.replaceFirst('100x100bb', '600x600bb');
  }

  static Future<CoverHit?> _itunesAlbum(String artist, String album) async {
    final j = await _json(Uri.https('itunes.apple.com', '/search', {
      'term': '$artist $album',
      'media': 'music',
      'entity': 'album',
      'limit': '10',
    }));
    if (j is! Map) return null;
    for (final r in (j['results'] as List? ?? const [])) {
      if (r is! Map) continue;
      if (_same(r['artistName'] as String? ?? '', artist) &&
          _same(r['collectionName'] as String? ?? '', album)) {
        final a = _itunesArt(r);
        if (a != null) return CoverHit(a, _yr(r['releaseDate']));
      }
    }
    return null;
  }

  static Future<CoverHit?> _itunesSong(String artist, String title) async {
    final j = await _json(Uri.https('itunes.apple.com', '/search', {
      'term': '$artist $title',
      'media': 'music',
      'entity': 'song',
      'limit': '10',
    }));
    if (j is! Map) return null;
    for (final r in (j['results'] as List? ?? const [])) {
      if (r is! Map) continue;
      if (_same(r['artistName'] as String? ?? '', artist) &&
          _same(r['trackName'] as String? ?? '', title)) {
        final a = _itunesArt(r);
        if (a != null) return CoverHit(a, _yr(r['releaseDate']));
      }
    }
    return null;
  }

  static Future<CoverHit?> _deezerAlbum(String artist, String album) async {
    final j = await _json(Uri.https('api.deezer.com', '/search/album', {
      'q': 'artist:"$artist" album:"$album"',
      'limit': '10',
    }));
    if (j is! Map) return null;
    for (final r in (j['data'] as List? ?? const [])) {
      if (r is! Map) continue;
      final ar = r['artist'];
      if (ar is Map &&
          _same(ar['name'] as String? ?? '', artist) &&
          _same(r['title'] as String? ?? '', album)) {
        final c = r['cover_xl'] as String? ?? r['cover_big'] as String?;
        if (c != null && c.isNotEmpty) return CoverHit(c, 0);
      }
    }
    return null;
  }

  static Future<CoverHit?> _deezerTrack(String artist, String title) async {
    final j = await _json(Uri.https('api.deezer.com', '/search/track', {
      'q': 'artist:"$artist" track:"$title"',
      'limit': '10',
    }));
    if (j is! Map) return null;
    for (final r in (j['data'] as List? ?? const [])) {
      if (r is! Map) continue;
      final ar = r['artist'];
      final al = r['album'];
      if (ar is Map &&
          al is Map &&
          _same(ar['name'] as String? ?? '', artist) &&
          _same(r['title'] as String? ?? '', title)) {
        final c = al['cover_xl'] as String? ?? al['cover_big'] as String?;
        if (c != null && c.isNotEmpty) return CoverHit(c, 0);
      }
    }
    return null;
  }

  static Future<CoverHit?> _coverArtArchive(String artist, String album) async {
    final j = await _json(
      Uri.https('musicbrainz.org', '/ws/2/release/', {
        'query': 'release:"$album" AND artist:"$artist"',
        'fmt': 'json',
        'limit': '5',
      }),
      headers: _ua,
    );
    if (j is! Map) return null;
    for (final r in (j['releases'] as List? ?? const [])) {
      if (r is! Map) continue;
      final credits = (r['artist-credit'] as List? ?? const []);
      final okArtist = credits.any((c) => c is Map && _same(c['name'] as String? ?? '', artist));
      if (!okArtist || !_same(r['title'] as String? ?? '', album)) continue;
      final url = 'https://coverartarchive.org/release/${r['id']}/front-500';
      try {
        final res = await _client
            .send(http.Request('HEAD', Uri.parse(url))..headers.addAll(_ua))
            .timeout(const Duration(seconds: 8));
        await res.stream.drain<void>();
        if (res.statusCode == 200) return CoverHit(url, _yr(r['date']));
      } catch (_) {}
    }
    return null;
  }
}
