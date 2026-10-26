import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Letra de un tema: texto plano y, si existe, sincronizada (LRC).
class Lyrics {
  const Lyrics(this.plain, this.synced);
  final String plain;
  final List<({Duration at, String text})> synced;
  bool get hasSynced => synced.isNotEmpty;
  bool get isEmpty => plain.trim().isEmpty && synced.isEmpty;

  Map<String, dynamic> toJson() => {
        'plain': plain,
        'synced': [
          for (final l in synced) [l.at.inMilliseconds, l.text],
        ],
      };

  static Lyrics fromJson(Map<String, dynamic> j) => Lyrics(
        j['plain'] as String? ?? '',
        [
          for (final e in (j['synced'] as List? ?? const []))
            (at: Duration(milliseconds: (e[0] as num).toInt()), text: e[1] as String),
        ],
      );
}

/// Letras desde LRCLIB (gratis, sin cuenta) con caché local para uso sin internet.
class LyricsService {
  static const _ua = {
    'User-Agent': 'VinylSolutions/1.0 (https://github.com/pytngdfv1-ai/vinyl-solutions)',
  };
  static const _missDays = 7;

  static Future<File> _file(String artist, String title) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/lyrics');
    await dir.create(recursive: true);
    return File('${dir.path}/${_hash('${artist.toLowerCase()}|${title.toLowerCase()}')}.json');
  }

  static String _hash(String s) {
    var a = 0x811c9dc5;
    var b = 0x811c9dc5;
    final u = s.codeUnits;
    for (var i = 0; i < u.length; i++) {
      a = ((a ^ u[i]) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ u[u.length - 1 - i]) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${a.toRadixString(16)}${b.toRadixString(16)}';
  }

  /// Letra del tema, de la caché o de LRCLIB. null si no hay (o sin internet).
  static Future<Lyrics?> get(String artist, String title, {String? album, int? seconds}) async {
    File? f;
    try {
      f = await _file(artist, title);
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        if (j['miss'] == true) {
          final t = DateTime.tryParse(j['at'] as String? ?? '');
          if (t != null && DateTime.now().difference(t).inDays < _missDays) return null;
        } else {
          return Lyrics.fromJson(j);
        }
      }
    } catch (_) {}

    Lyrics? found;
    var reached = false;
    try {
      final res = await http
          .get(
            Uri.https('lrclib.net', '/api/get', {
              'artist_name': artist,
              'track_name': title,
              if (album != null && album.isNotEmpty) 'album_name': album,
              if (seconds != null && seconds > 0) 'duration': '$seconds',
            }),
            headers: _ua,
          )
          .timeout(const Duration(seconds: 10));
      reached = true;
      if (res.statusCode == 200) {
        found = _parse(jsonDecode(utf8.decode(res.bodyBytes)));
      } else if (res.statusCode == 404) {
        final s = await http
            .get(
              Uri.https('lrclib.net', '/api/search', {'artist_name': artist, 'track_name': title}),
              headers: _ua,
            )
            .timeout(const Duration(seconds: 10));
        if (s.statusCode == 200) {
          final list = jsonDecode(utf8.decode(s.bodyBytes));
          if (list is List && list.isNotEmpty) found = _parse(list.first);
        }
      }
    } catch (_) {}

    try {
      if (f != null) {
        if (found != null && !found.isEmpty) {
          await f.writeAsString(jsonEncode(found.toJson()));
        } else if (reached) {
          await f.writeAsString(jsonEncode({'miss': true, 'at': DateTime.now().toIso8601String()}));
        }
      }
    } catch (_) {}
    return found == null || found.isEmpty ? null : found;
  }

  static Lyrics? _parse(dynamic j) {
    if (j is! Map) return null;
    final plain = (j['plainLyrics'] as String?) ?? '';
    final lrc = (j['syncedLyrics'] as String?) ?? '';
    final synced = <({Duration at, String text})>[];
    final re = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$');
    for (final line in const LineSplitter().convert(lrc)) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final ms = ((int.parse(m[1]!) * 60 + double.parse(m[2]!)) * 1000).round();
      synced.add((at: Duration(milliseconds: ms), text: m[3]!));
    }
    final text = plain.isNotEmpty ? plain : synced.map((e) => e.text).join('\n');
    return Lyrics(text, synced);
  }
}
