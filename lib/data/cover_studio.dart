import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'musicbrainz.dart';

/// Imagen de un álbum: portada, contraportada, disco, página de libreto u otra.
class StudioImage {
  StudioImage({
    required this.id,
    required this.type,
    required this.source,
    required this.thumb,
    required this.urls,
    this.edition = '',
  });
  final String id;

  /// front | back | medium | booklet | other
  final String type;
  final String source;
  final String edition;
  final String thumb;

  /// Candidatas de mayor a menor resolución.
  final List<String> urls;

  static const labels = {
    'front': 'Portada',
    'back': 'Contraportada',
    'medium': 'Disco',
    'booklet': 'Booklet',
    'other': 'Otra',
  };
  String get label => labels[type] ?? 'Otra';
}

class StudioRelease {
  StudioRelease(this.id, this.label);
  final String id;
  final String label;
}

class StudioAlbum {
  StudioAlbum(this.key, this.artist, this.title, this.year, this.thumb);
  final String key;
  final String artist;
  final String title;
  String year;
  String thumb;
  final List<StudioImage> images = [];
  final List<StudioRelease> releases = [];
  final Set<String> sources = {};
  final Set<String> _ids = {};
  int cursor = 0;
  bool mbTried = false;

  bool get hasMore => cursor < releases.length;
}

class StudioFile {
  StudioFile(this.name, this.size, this.url);
  final String name;
  final int size;
  final String url;
}

class StudioPdf {
  StudioPdf(this.id, this.title, this.creator, this.files);
  final String id;
  final String title;
  final String creator;
  final List<StudioFile> files;
}

/// Búsqueda de carátulas, contraportadas, discos, páginas de libreto y PDFs
/// (iTunes, Deezer, MusicBrainz + Cover Art Archive e Internet Archive).
class CoverStudio {
  static final http.Client _c = http.Client();
  static const _ua = {'User-Agent': MusicBrainz.userAgent};

  static Future<dynamic> _json(Uri u, {int secs = 12}) async {
    try {
      final r = await _c.get(u, headers: _ua).timeout(Duration(seconds: secs));
      if (r.statusCode != 200) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ')
      .replaceAll(RegExp(r'\b(deluxe|remastered|remaster|edition|expanded|anniversary|version|bonus|special|the)\b'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  static String _key(String s) {
    final n = _norm(s);
    return n.isEmpty ? s.toLowerCase() : n;
  }

  static void _add(Map<String, StudioAlbum> m, String artist, String title, String year, String src, String thumb,
      {StudioImage? img, StudioRelease? rel}) {
    final k = '${_key(artist)}|${_key(title)}';
    final a = m.putIfAbsent(k, () => StudioAlbum(k, artist, title, year, thumb));
    if (a.thumb.isEmpty) a.thumb = thumb;
    if (a.year.isEmpty) a.year = year;
    a.sources.add(src);
    if (img != null && a._ids.add(img.id)) a.images.add(img);
    if (rel != null && !a.releases.any((r) => r.id == rel.id)) a.releases.add(rel);
  }

  static String _it(String art, String size) => art.replaceFirstMapped(RegExp(r'\d+x\d+bb(\.\w+)$'), (m) => '$size${m[1]}');

  /// Busca álbumes; si [artist] tiene texto, solo deja los de ese artista.
  static Future<List<StudioAlbum>> search(String artist, String album) async {
    final q = '$artist $album'.trim();
    final out = <String, StudioAlbum>{};
    final res = await Future.wait([_itunes(q), _deezer(q), _mb(artist, album)]);
    for (final f in res) {
      for (final e in f) {
        _add(out, e.$1, e.$2, e.$3, e.$4, e.$5, img: e.$6, rel: e.$7);
      }
    }
    var list = out.values.toList();
    final na = _norm(artist);
    if (na.isNotEmpty) {
      final f = list.where((a) {
        final x = _norm(a.artist);
        return x.isNotEmpty && (x.contains(na) || na.contains(x));
      }).toList();
      if (f.isNotEmpty) list = f;
    }
    final nt = _norm(album);
    int score(StudioAlbum a) => (nt.isNotEmpty && _norm(a.title).contains(nt) ? 10 : 0) + a.sources.length * 3;
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list.take(48).toList();
  }

  // (artista, título, año, fuente, miniatura, imagen?, edición?)
  static Future<List<(String, String, String, String, String, StudioImage?, StudioRelease?)>> _itunes(String q) async {
    final j = await _json(Uri.https('itunes.apple.com', '/search', {'term': q, 'entity': 'album', 'limit': '25'}));
    final out = <(String, String, String, String, String, StudioImage?, StudioRelease?)>[];
    if (j is! Map) return out;
    for (final x in (j['results'] as List? ?? const [])) {
      if (x is! Map) continue;
      final art = x['artworkUrl100'] as String?;
      if (art == null) continue;
      final thumb = _it(art, '600x600bb');
      out.add((
        '${x['artistName'] ?? ''}',
        '${x['collectionName'] ?? ''}',
        '${x['releaseDate'] ?? ''}'.padRight(4).substring(0, 4).trim(),
        'iTunes',
        thumb,
        StudioImage(
          id: 'it-${x['collectionId']}',
          type: 'front',
          source: 'iTunes',
          thumb: thumb,
          urls: [for (final s in const ['100000x100000-999', '3000x3000bb', '1400x1400bb', '600x600bb']) _it(art, s)],
        ),
        null,
      ));
    }
    return out;
  }

  static Future<List<(String, String, String, String, String, StudioImage?, StudioRelease?)>> _deezer(String q) async {
    final j = await _json(Uri.https('api.deezer.com', '/search/album', {'q': q, 'limit': '25'}));
    final out = <(String, String, String, String, String, StudioImage?, StudioRelease?)>[];
    if (j is! Map) return out;
    for (final x in (j['data'] as List? ?? const [])) {
      if (x is! Map) continue;
      final md5 = x['md5_image'] as String?;
      final xl = x['cover_xl'] as String?;
      if ((md5 == null || md5.isEmpty) && (xl == null || xl.isEmpty)) continue;
      final urls = <String>[
        if (md5 != null && md5.isNotEmpty) 'https://cdn-images.dzcdn.net/images/cover/$md5/1900x1900-000000-80-0-0.jpg',
        if (xl != null && xl.isNotEmpty) xl,
      ];
      final thumb = (x['cover_big'] ?? x['cover_medium'] ?? xl ?? '') as String;
      final ar = x['artist'];
      out.add((
        ar is Map ? '${ar['name'] ?? ''}' : '',
        '${x['title'] ?? ''}',
        '',
        'Deezer',
        thumb,
        StudioImage(id: 'dz-${x['id']}', type: 'front', source: 'Deezer', thumb: thumb, urls: urls),
        null,
      ));
    }
    return out;
  }

  static StudioRelease _rel(Map r) {
    final media = r['media'];
    final fmt = media is List && media.isNotEmpty && media.first is Map ? '${(media.first as Map)['format'] ?? ''}' : '';
    final label = [fmt, '${r['date'] ?? ''}', '${r['country'] ?? ''}'].where((e) => e.isNotEmpty).join(' · ');
    return StudioRelease('${r['id']}', label.isEmpty ? 'edición' : label);
  }

  static Future<List<Map>> _mbReleases(String artist, String album, {int limit = 40}) async {
    final parts = <String>[
      if (album.isNotEmpty) 'release:"${album.replaceAll(RegExp(r'["\\]'), ' ')}"',
      if (artist.isNotEmpty) 'artist:"${artist.replaceAll(RegExp(r'["\\]'), ' ')}"',
    ];
    if (parts.isEmpty) return const [];
    final j = await MusicBrainz.getJson(Uri.https('musicbrainz.org', '/ws/2/release/', {
      'query': parts.join(' AND '),
      'fmt': 'json',
      'limit': '$limit',
    }));
    if (j is! Map) return const [];
    return [for (final r in (j['releases'] as List? ?? const [])) if (r is Map) r];
  }

  static Future<List<(String, String, String, String, String, StudioImage?, StudioRelease?)>> _mb(
      String artist, String album) async {
    final out = <(String, String, String, String, String, StudioImage?, StudioRelease?)>[];
    for (final r in await _mbReleases(artist, album)) {
      final cr = r['artist-credit'];
      final name = cr is List && cr.isNotEmpty && cr.first is Map ? '${(cr.first as Map)['name'] ?? ''}' : '';
      final date = '${r['date'] ?? ''}';
      out.add((
        name,
        '${r['title'] ?? ''}',
        date.length >= 4 ? date.substring(0, 4) : '',
        'MusicBrainz',
        'https://coverartarchive.org/release/${r['id']}/front-250',
        null,
        _rel(r),
      ));
    }
    return out;
  }

  static String _capType(Object? t) {
    final l = t is List ? t.map((e) => '$e').toList() : const <String>[];
    if (l.contains('Front')) return 'front';
    if (l.contains('Booklet')) return 'booklet';
    if (l.contains('Back')) return 'back';
    if (l.contains('Medium')) return 'medium';
    return 'other';
  }

  static String _https(String u) => u.replaceFirst(RegExp(r'^http:'), 'https:');

  /// Carga hasta 10 ediciones más del álbum desde Cover Art Archive (portada, contra, disco, libreto…).
  /// Devuelve las imágenes nuevas.
  static Future<List<StudioImage>> loadEditions(StudioAlbum a) async {
    if (a.releases.isEmpty && !a.mbTried) {
      a.mbTried = true;
      for (final r in await _mbReleases(a.artist, a.title)) {
        if (_key('${r['title']}') != _key(a.title)) continue;
        final o = _rel(r);
        if (!a.releases.any((x) => x.id == o.id)) a.releases.add(o);
      }
    }
    final batch = a.releases.skip(a.cursor).take(10).toList();
    a.cursor += batch.length;
    final fresh = <StudioImage>[];
    await Future.wait(batch.map((r) async {
      final d = await _json(Uri.parse('https://coverartarchive.org/release/${r.id}'));
      if (d is! Map) return;
      for (final im in (d['images'] as List? ?? const [])) {
        if (im is! Map) continue;
        final id = 'caa-${im['id']}';
        if (!a._ids.add(id)) continue;
        final th = im['thumbnails'];
        final t = th is Map ? '${th['500'] ?? th['large'] ?? th['250'] ?? th['small'] ?? im['image']}' : '${im['image']}';
        final img = StudioImage(
          id: id,
          type: _capType(im['types']),
          source: 'Cover Art Archive',
          edition: r.label,
          thumb: _https(t),
          urls: [_https('${im['image']}')],
        );
        a.images.add(img);
        fresh.add(img);
      }
    }));
    return fresh;
  }

  /// Descarga la imagen con la mayor resolución disponible.
  static Future<Uint8List?> imageBytes(StudioImage img) async {
    for (final u in img.urls) {
      try {
        final r = await _c.get(Uri.parse(u), headers: _ua).timeout(const Duration(seconds: 45));
        if (r.statusCode == 200 && r.bodyBytes.length > 500) return r.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  static Future<Uint8List?> fileBytes(String url) async {
    try {
      final r = await _c.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 120));
      return r.statusCode == 200 && r.bodyBytes.length > 500 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  // ---------- PDFs / libretos (Internet Archive) ----------
  static Future<List<Map>> _archive(String q) async {
    final u = Uri.https('archive.org', '/advancedsearch.php', {
      'q': q,
      'fl[]': ['identifier', 'title', 'creator'],
      'rows': '10',
      'output': 'json',
      'sort[]': 'downloads desc',
    });
    final j = await _json(u);
    if (j is! Map || j['response'] is! Map) return const [];
    return [for (final d in ((j['response'] as Map)['docs'] as List? ?? const [])) if (d is Map) d];
  }

  static String _s1(Object? x) => x is List ? x.join(', ') : '${x ?? ''}';

  static Future<List<StudioPdf>> searchPdfs(String artist, String album) async {
    final terms = [artist, album].where((e) => e.trim().isNotEmpty).map((e) => e.replaceAll('"', '')).toList();
    if (terms.isEmpty) return const [];
    final quoted = terms.map((t) => '"$t"').join(' AND ');
    const kw = '(booklet OR scans OR "liner notes" OR artwork OR "cd cover" OR digipak)';
    final lists = await Future.wait([
      _archive('$quoted AND $kw'),
      _archive('$quoted AND mediatype:texts'),
      _archive('${terms.join(' ')} AND $kw'),
    ]);
    final map = <String, Map>{};
    for (final d in lists.expand((e) => e)) {
      map.putIfAbsent('${d['identifier']}', () => d);
    }
    final docs = map.values.take(14).toList();
    final items = await Future.wait(docs.map((d) async {
      final id = '${d['identifier']}';
      final m = await _json(Uri.https('archive.org', '/metadata/${Uri.encodeComponent(id)}'));
      final files = <StudioFile>[];
      if (m is Map) {
        for (final f in (m['files'] as List? ?? const [])) {
          if (f is! Map) continue;
          final n = '${f['name']}';
          if (!n.toLowerCase().endsWith('.pdf')) continue;
          files.add(StudioFile(
            n.split('/').last,
            int.tryParse('${f['size']}') ?? 0,
            'https://archive.org/download/${Uri.encodeComponent(id)}/${n.split('/').map(Uri.encodeComponent).join('/')}',
          ));
          if (files.length >= 6) break;
        }
      }
      final t = _s1(d['title']);
      return StudioPdf(id, t.isEmpty ? id : t, _s1(d['creator']), files);
    }));
    return items.where((e) => e.files.isNotEmpty).toList();
  }
}
