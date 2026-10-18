import 'dart:convert';

import 'package:http/http.dart' as http;

/// Busca la portada oficial del álbum (API pública de iTunes, sin clave).
class CoverLookup {
  static Future<String?> find(String artist, String album) async {
    if (artist.isEmpty || artist == 'Artista desconocido') return null;
    final clean = album.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '').trim();
    final a = artist.toLowerCase();
    for (final q in <String>{album, clean}) {
      if (q.isEmpty) continue;
      try {
        final uri = Uri.https('itunes.apple.com', '/search', {
          'term': '$artist $q',
          'media': 'music',
          'entity': 'album',
          'limit': '8',
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final results = (jsonDecode(res.body) as Map)['results'] as List;
        for (final r in results) {
          final name = ((r as Map)['artistName'] as String? ?? '').toLowerCase();
          final art = r['artworkUrl100'] as String?;
          if (art != null && name.isNotEmpty && (name.contains(a) || a.contains(name))) {
            return art.replaceFirst('100x100bb', '600x600bb');
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
