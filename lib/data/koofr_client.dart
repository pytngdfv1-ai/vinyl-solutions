import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'album_builder.dart';
import 'flac_meta.dart';
import 'library_settings.dart';
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

  Future<ScanResult> scan({void Function(String)? onProgress}) async {
    _dirs = 0;
    _filesSeen = 0;
    _skipped = 0;
    final top = await _list(_musicDir());
    final topDirs = top.where((e) => e.isDir).length;
    final topFiles = top.where((e) => !e.isDir).length;
    final sample = top.take(4).map((e) => e.name).join(', ');

    final drafts = <AlbumDraft>[];
    await _walk(_musicDir(), top, <String>[], drafts, onProgress);

    final result = await buildAlbums(drafts, skippedBefore: _skipped, onProgress: onProgress);
    diagnostic = 'En "${settings.folder}" vi $topDirs carpetas y $topFiles archivos'
        '${sample.isEmpty ? '' : ' (ej.: $sample)'}. '
        'Revisé $_dirs carpetas y $_filesSeen archivos en total.';
    return result;
  }

  int _skipped = 0;

  /// Lector de rangos HTTP para leer solo el inicio de un FLAC.
  RangeReader _reader(Uri uri) => buffered((start, length) async {
        final req = http.Request('GET', uri)
          ..headers.addAll({
            ...settings.headers,
            'Range': 'bytes=$start-${start + length - 1}',
          });
        final res = await _http.send(req).timeout(const Duration(seconds: 25));
        if (res.statusCode != 206) {
          await res.stream.listen((_) {}).cancel();
          return null;
        }
        final Uint8List bytes = await res.stream.toBytes();
        return bytes;
      });

  Future<void> _walk(
    Uri dir,
    List<_Entry> entries,
    List<String> names,
    List<AlbumDraft> out,
    void Function(String)? onProgress,
  ) async {
    _dirs++;
    _filesSeen += entries.where((e) => !e.isDir).length;

    final audio = entries
        .where((e) => !e.isDir && _audioExt.any((x) => e.name.toLowerCase().endsWith(x)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (audio.isNotEmpty) {
      // Audio suelto en la carpeta elegida, o muy pocos temas: no es un álbum.
      if (names.isEmpty || audio.length < LibrarySettings.minTracks) {
        _skipped++;
      } else {
        final images = entries
            .where((e) => !e.isDir && _imageExt.any((x) => e.name.toLowerCase().endsWith(x)))
            .toList();
        final pref = RegExp(r'^(cover|folder|front|album|artwork)\.', caseSensitive: false);
        final art = images.where((e) => pref.hasMatch(e.name)).firstOrNull ?? images.firstOrNull;
        final first = audio.first;
        out.add(AlbumDraft(
          key: names.join('/'),
          idPrefix: 'dav_',
          folderArtist: names.length >= 2 ? names[names.length - 2] : null,
          folderAlbum: names.last,
          trackFiles: [for (final t in audio) t.name],
          trackUrls: [for (final t in audio) t.uri.toString()],
          folderImageUrl: art?.uri.toString(),
          readMeta: first.name.toLowerCase().endsWith('.flac')
              ? () => readFlacMeta(_reader(first.uri))
              : null,
        ));
      }
    }

    if (names.length >= _maxDepth) return;
    for (final d in entries.where((e) => e.isDir)) {
      if (_dirs >= _maxDirs) return;
      onProgress?.call(d.name);
      final sub = await _list(d.uri);
      await _walk(d.uri, sub, [...names, d.name], out, onProgress);
    }
  }
}
