import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/vinyl.dart';
import 'album_builder.dart';
import 'flac_meta.dart';
import 'library_settings.dart';
import 'library_utils.dart';
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

  String _u(Uri u) => KoofrSettings.tag(u.toString(), settings.id);

  Map<String, Vinyl> _reuse = const {};

  /// true si se detectó que la carpeta raíz está dividida en categorías.
  bool? detectedSplit;

  Future<ScanResult> scan({
    void Function(String)? onProgress,
    Map<String, Vinyl> reuse = const {},
  }) async {
    _reuse = reuse;
    _dirs = 0;
    _filesSeen = 0;
    _skipped = 0;
    final top = await _list(_musicDir());
    final topDirs = top.where((e) => e.isDir).length;
    final topFiles = top.where((e) => !e.isDir).length;
    final sample = top.take(4).map((e) => e.name).join(', ');

    final drafts = <AlbumDraft>[];
    await _walk(_musicDir(), top, <String>[], drafts, onProgress, split: settings.split == 'yes');
    if (settings.split == 'auto' &&
        detectSplit([for (final d in drafts) if (!d.single) d.path])) {
      // Categoría/Artista/Álbum: cada categoría es su propia biblioteca.
      drafts.clear();
      _dirs = 0;
      _filesSeen = 0;
      await _walk(_musicDir(), top, <String>[], drafts, onProgress, split: true);
      detectedSplit = true;
    }

    final result = await buildAlbums(drafts, skippedBefore: _skipped, onProgress: onProgress, reuse: _reuse);
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
    void Function(String)? onProgress, {
    String? group,
    bool split = false,
  }) async {
    final full = [if (group != null) group, ...names];
    final src = group == null ? settings.id : '${settings.id}:$group';
    _dirs++;
    _filesSeen += entries.where((e) => !e.isDir).length;

    final audio = entries
        .where((e) => !e.isDir && _audioExt.any((x) => e.name.toLowerCase().endsWith(x)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (audio.isNotEmpty) {
      // Audio suelto en la carpeta elegida, o muy pocos temas: no es un álbum.
      if (names.isEmpty || audio.length < LibrarySettings.minTracks) {
        // Cada tema va al baúl de temas sueltos.
        final imgs0 = entries
            .where((e) => !e.isDir && _imageExt.any((x) => e.name.toLowerCase().endsWith(x)))
            .toList();
        final pref0 = RegExp(r'^(cover|folder|front|album|artwork)\.', caseSensitive: false);
        final art0 = imgs0.where((e) => pref0.hasMatch(e.name)).firstOrNull ?? imgs0.firstOrNull;
        for (final e in audio) {
          out.add(AlbumDraft(
            key: '${full.join('/')}/${e.name}',
            source: src,
            idPrefix: 'dav_${settings.id}_s_',
            single: true,
            folderArtist: names.length >= 2 ? names[names.length - 2] : null,
            fallbackArtist: names.length == 1 ? names.first : null,
            folderAlbum: names.isEmpty ? '' : names.last,
            trackFiles: [e.name],
            trackUrls: [_u(e.uri)],
            folderImageUrl: names.isEmpty || art0 == null ? null : _u(art0.uri),
            readMeta: e.name.toLowerCase().endsWith('.flac')
                ? () => readFlacMeta(_reader(e.uri))
                : null,
          ));
        }
      } else {
        final images = entries
            .where((e) => !e.isDir && _imageExt.any((x) => e.name.toLowerCase().endsWith(x)))
            .toList();
        final pref = RegExp(r'^(cover|folder|front|album|artwork)\.', caseSensitive: false);
        final art = images.where((e) => pref.hasMatch(e.name)).firstOrNull ?? images.firstOrNull;
        // Libreto: resto de imágenes y PDFs, más los de subcarpetas "Libreto", "Booklet"…
        final imgs = images.where((e) => e != art).toList()
          ..sort((a, b) => naturalCompare(a.name, b.name));
        final pdfs = entries.where((e) => !e.isDir && e.name.toLowerCase().endsWith('.pdf')).toList()
          ..sort((a, b) => naturalCompare(a.name, b.name));
        for (final d in entries.where((e) => e.isDir && isBookletDir(e.name))) {
          try {
            final sub = await _list(d.uri);
            imgs.addAll(sub
                .where((e) => !e.isDir && _imageExt.any((x) => e.name.toLowerCase().endsWith(x)))
                .toList()
              ..sort((a, b) => naturalCompare(a.name, b.name)));
            pdfs.addAll(sub
                .where((e) => !e.isDir && e.name.toLowerCase().endsWith('.pdf'))
                .toList()
              ..sort((a, b) => naturalCompare(a.name, b.name)));
          } catch (_) {}
        }
        final first = audio.first;
        out.add(AlbumDraft(
          key: full.join('/'),
          source: src,
          path: full,
          idPrefix: 'dav_${settings.id}_',
          folderArtist: names.length >= 2 ? names[names.length - 2] : null,
          folderAlbum: names.last,
          trackFiles: [for (final t in audio) t.name],
          trackUrls: [for (final t in audio) _u(t.uri)],
          folderImageUrl: art == null ? null : _u(art.uri),
          bookletImages: [for (final e in imgs) _u(e.uri)],
          pdfs: [for (final e in pdfs) _u(e.uri)],
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
      if (split && names.isEmpty && group == null) {
        // Cada subcarpeta de la raíz es una biblioteca; sus rutas cuentan desde ahí.
        await _walk(d.uri, sub, const <String>[], out, onProgress, group: d.name);
      } else {
        await _walk(d.uri, sub, [...names, d.name], out, onProgress, group: group);
      }
    }
  }
}
