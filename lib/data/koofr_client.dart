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

/// Lee la biblioteca por WebDAV. Busca audio en cualquier subcarpeta:
/// cada carpeta con audio es un álbum y su carpeta padre es el artista.
class KoofrClient {
  KoofrClient(this.settings);

  final KoofrSettings settings;
  final http.Client _http = http.Client();

  /// Resumen de lo que se vio en la carpeta (para diagnóstico).
  String diagnostic = '';

  static const _audioExt = ['.flac', '.mp3', '.m4a', '.ogg', '.opus', '.wav', '.aac'];
  static const _imageExt = ['.jpg', '.jpeg', '.png', '.webp'];
  static const _maxDepth = 5;
  static const _maxDirs = 600;

  int _dirs = 0;
  int _filesSeen = 0;

  Uri get _root => Uri.parse(settings.baseUrl);

  Uri _musicDir() => _root.replace(pathSegments: [
        ..._root.pathSegments.where((s) => s.isNotEmpty),
        ...settings.folder.split('/').where((s) => s.isNotEmpty),
      ]);

  String _norm(Uri u) {
    var p = u.path;
    try {
      p = Uri.decodeFull(p);
    } catch (_) {}
    return p.replaceAll(RegExp(r'/+$'), '');
  }

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
    if (res.statusCode != 207 && res.statusCode != 200) {
      throw KoofrException('Error de Koofr (${res.statusCode})');
    }
    final doc = XmlDocument.parse(utf8.decode(res.bodyBytes));
    final self = _norm(dir);
    final out = <_Entry>[];
    for (final r in doc.findAllElements('response', namespace: '*')) {
      final hrefs = r.findElements('href', namespace: '*');
      if (hrefs.isEmpty) continue;
      final uri = _root.resolve(hrefs.first.innerText.trim());
      final isDir = r.findAllElements('collection', namespace: '*').isNotEmpty;
      if (_norm(uri) == self) continue;
      out.add(_Entry(uri, isDir));
    }
    return out;
  }

  Future<List<Vinyl>> scan({void Function(String)? onProgress}) async {
    _dirs = 0;
    _filesSeen = 0;
    final top = await _list(_musicDir());
    final topDirs = top.where((e) => e.isDir).length;
    final topFiles = top.where((e) => !e.isDir).length;
    final sample = top.take(4).map((e) => e.name).join(', ');

    final out = <Vinyl>[];
    await _walk(_musicDir(), top, <String>[], out, onProgress);

    diagnostic = 'En "${settings.folder}" vi $topDirs carpetas y $topFiles archivos'
        '${sample.isEmpty ? '' : ' (ej.: $sample)'}. '
        'Revisé $_dirs carpetas y $_filesSeen archivos en total.';
    return out;
  }

  Future<void> _walk(
    Uri dir,
    List<_Entry> entries,
    List<String> names,
    List<Vinyl> out,
    void Function(String)? onProgress,
  ) async {
    _dirs++;
    _filesSeen += entries.where((e) => !e.isDir).length;

    final audio = entries
        .where((e) => !e.isDir && _audioExt.any((x) => e.name.toLowerCase().endsWith(x)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (audio.isNotEmpty) {
      final images = entries
          .where((e) => !e.isDir && _imageExt.any((x) => e.name.toLowerCase().endsWith(x)))
          .toList();
      final pref = RegExp(r'^(cover|folder|front|album|artwork)\.', caseSensitive: false);
      final art = images.where((e) => pref.hasMatch(e.name)).firstOrNull ??
          images.firstOrNull;

      final rootName = settings.folder.split('/').where((s) => s.isNotEmpty).lastOrNull ??
          'Música';
      final album = names.isNotEmpty ? names.last : rootName;
      final artist = names.length >= 2 ? names[names.length - 2] : 'Artista desconocido';
      final key = names.isEmpty ? rootName : names.join('/');
      out.add(Vinyl(
        id: 'dav_${base64Url.encode(utf8.encode(key))}',
        title: album,
        artist: artist,
        year: _year(album),
        hue: (key.codeUnits.fold<int>(0, (s, c) => s + c) % 360).toDouble(),
        tracks: [for (final t in audio) _title(t.name)],
        trackUrls: [for (final t in audio) t.uri.toString()],
        coverUrl: art?.uri.toString(),
        owned: true,
      ));
    }

    if (names.length >= _maxDepth) return;
    for (final d in entries.where((e) => e.isDir)) {
      if (_dirs >= _maxDirs) return;
      onProgress?.call(d.name);
      final sub = await _list(d.uri);
      await _walk(d.uri, sub, [...names, d.name], out, onProgress);
    }
  }

  static int _year(String s) {
    final m = RegExp(r'(19|20)\d{2}').firstMatch(s);
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  static String _title(String file) {
    var t = file.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), '');
    t = t.replaceFirst(RegExp(r'^\d+\s*[-._)]*\s*'), '');
    return t.isEmpty ? file : t;
  }
}
