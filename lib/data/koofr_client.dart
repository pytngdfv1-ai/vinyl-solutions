import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/vinyl.dart';
import 'koofr_settings.dart';

class KoofrException implements Exception {
  const KoofrException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Entry {
  _Entry(this.uri, this.isDir);
  final Uri uri;
  final bool isDir;

  String get name {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? '' : segs.last;
  }
}

/// Lee la biblioteca `Carpeta/Artista/Álbum/NN - Pista.flac` por WebDAV.
class KoofrClient {
  KoofrClient(this.settings);

  final KoofrSettings settings;
  final http.Client _http = http.Client();

  Uri get _root => Uri.parse(settings.baseUrl);

  Uri _musicDir() => _root.replace(pathSegments: [
        ..._root.pathSegments.where((s) => s.isNotEmpty),
        ...settings.folder.split('/').where((s) => s.isNotEmpty),
      ]);

  String _norm(Uri u) => u.path.replaceAll(RegExp(r'/+$'), '');

  Future<List<_Entry>> _list(Uri dir) async {
    final req = http.Request('PROPFIND', dir)
      ..headers.addAll({
        ...settings.headers,
        'Depth': '1',
        'Content-Type': 'application/xml',
      })
      ..body = '<?xml version="1.0"?>'
          '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const KoofrException('Correo o contraseña de aplicación incorrectos');
    }
    if (res.statusCode == 404) {
      throw KoofrException('No existe la carpeta "${settings.folder}" en Koofr');
    }
    if (res.statusCode != 207) {
      throw KoofrException('Error de Koofr (${res.statusCode})');
    }
    final doc = XmlDocument.parse(utf8.decode(res.bodyBytes));
    final out = <_Entry>[];
    for (final r in doc.findAllElements('response', namespace: '*')) {
      final hrefs = r.findElements('href', namespace: '*');
      if (hrefs.isEmpty) continue;
      final uri = _root.resolve(hrefs.first.innerText.trim());
      final isDir = r.findAllElements('collection', namespace: '*').isNotEmpty;
      if (_norm(uri) == _norm(dir)) continue;
      out.add(_Entry(uri, isDir));
    }
    return out;
  }

  Future<List<Vinyl>> scan({void Function(String)? onProgress}) async {
    final artists = (await _list(_musicDir())).where((e) => e.isDir).toList();
    final out = <Vinyl>[];
    final cover = RegExp(r'^(cover|folder|front)\.(jpe?g|png)$', caseSensitive: false);

    for (final a in artists) {
      onProgress?.call(a.name);
      final albums = (await _list(a.uri)).where((e) => e.isDir);
      for (final al in albums) {
        final files = await _list(al.uri);
        final tracks = files
            .where((f) => !f.isDir && f.name.toLowerCase().endsWith('.flac'))
            .toList()
          ..sort((x, y) => x.name.compareTo(y.name));
        if (tracks.isEmpty) continue;
        final art = files.where((f) => !f.isDir && cover.hasMatch(f.name)).firstOrNull;
        final key = '${a.name}/${al.name}';
        out.add(Vinyl(
          id: 'dav_${base64Url.encode(utf8.encode(key))}',
          title: al.name,
          artist: a.name,
          year: _year(al.name),
          hue: (key.codeUnits.fold<int>(0, (s, c) => s + c) % 360).toDouble(),
          tracks: [for (final t in tracks) _title(t.name)],
          trackUrls: [for (final t in tracks) t.uri.toString()],
          coverUrl: art?.uri.toString(),
          owned: true,
        ));
      }
    }
    return out;
  }

  static int _year(String s) {
    final m = RegExp(r'(19|20)\d{2}').firstMatch(s);
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  static String _title(String file) {
    var t = file.replaceFirst(RegExp(r'\.flac$', caseSensitive: false), '');
    t = t.replaceFirst(RegExp(r'^\d+\s*[-._)]*\s*'), '');
    return t.isEmpty ? file : t;
  }
}
