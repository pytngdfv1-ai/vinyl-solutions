import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path_provider/path_provider.dart';

import '../models/vinyl.dart';
import 'cover_lookup.dart';

class _Track {
  _Track({
    required this.path,
    required this.title,
    required this.artist,
    required this.albumArtist,
    required this.album,
    required this.number,
    required this.disc,
    required this.year,
  });

  final String path;
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? number;
  final int? disc;
  final int? year;

  String get file => path.split('/').last;
  String get folder => path.substring(0, path.lastIndexOf('/'));
}

/// Lee una carpeta del teléfono: agrupa por álbum usando las etiquetas
/// (artista, álbum, nº de pista) y, si faltan, los nombres de carpeta.
class LocalScanner {
  static const _audioExt = ['.flac', '.mp3', '.m4a', '.ogg', '.opus', '.wav', '.aac'];
  static const _imageExt = ['.jpg', '.jpeg', '.png', '.webp'];

  static Future<List<Vinyl>> scan(
    String dir, {
    void Function(String)? onProgress,
  }) async {
    final root = dir.replaceAll(RegExp(r'/+$'), '');
    final tracks = <_Track>[];
    final images = <String, List<String>>{};

    final stream = Directory(root)
        .list(recursive: true, followLinks: false)
        .handleError((Object _) {});
    var n = 0;
    await for (final e in stream) {
      if (e is! File) continue;
      final path = e.path;
      final lower = path.toLowerCase();
      if (_imageExt.any(lower.endsWith)) {
        images.putIfAbsent(path.substring(0, path.lastIndexOf('/')), () => []).add(path);
        continue;
      }
      if (!_audioExt.any(lower.endsWith)) continue;
      onProgress?.call(path.split('/').last);
      tracks.add(_readTrack(e));
      if (++n % 10 == 0) await Future<void>.delayed(Duration.zero); // deja respirar la UI
    }

    // Agrupar: una carpeta + nombre de álbum = un disco.
    final groups = <String, List<_Track>>{};
    for (final t in tracks) {
      final album = t.album ?? t.folder.split('/').last;
      groups.putIfAbsent('${t.folder}|$album', () => []).add(t);
    }

    final out = <Vinyl>[];
    final docs = await getApplicationDocumentsDirectory();
    for (final entry in groups.entries) {
      final list = entry.value
        ..sort((a, b) {
          final d = (a.disc ?? 1).compareTo(b.disc ?? 1);
          if (d != 0) return d;
          final t = (a.number ?? 9999).compareTo(b.number ?? 9999);
          return t != 0 ? t : a.file.compareTo(b.file);
        });
      final first = list.first;
      final album = first.album ?? first.folder.split('/').last;
      final artist = _artist(list, root);
      final key = entry.key;
      final id = 'loc_${base64Url.encode(utf8.encode(key))}';
      onProgress?.call(album);

      var cover = await _embeddedCover(first.path, docs.path, id);
      cover ??= _folderCover(images[first.folder]);
      cover ??= await CoverLookup.find(artist, album);

      final year = list.map((t) => t.year).whereType<int>().firstOrNull ?? _year(album);
      out.add(Vinyl(
        id: id,
        title: album,
        artist: artist,
        year: year,
        hue: (key.codeUnits.fold<int>(0, (s, c) => s + c) % 360).toDouble(),
        tracks: [for (final t in list) t.title ?? _title(t.file)],
        trackUrls: [for (final t in list) t.path],
        coverUrl: cover,
        owned: true,
      ));
    }
    out.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    return out;
  }

  static _Track _readTrack(File f) {
    try {
      final m = readMetadata(f, getImage: false);
      return _Track(
        path: f.path,
        title: _clean(m.title),
        artist: _clean(m.artist),
        albumArtist: _clean(m.albumArtist),
        album: _clean(m.album),
        number: m.trackNumber,
        disc: m.discNumber,
        year: m.year?.year,
      );
    } catch (_) {
      return _Track(
        path: f.path,
        title: null,
        artist: null,
        albumArtist: null,
        album: null,
        number: null,
        disc: null,
        year: null,
      );
    }
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _artist(List<_Track> list, String root) {
    final aa = list.map((t) => t.albumArtist).whereType<String>().firstOrNull;
    if (aa != null) return aa;
    final artists = list.map((t) => t.artist).whereType<String>().toSet();
    if (artists.length == 1) return artists.first;
    if (artists.length > 1) return 'Varios artistas';
    // Sin etiquetas: la carpeta padre de la carpeta del álbum.
    final folder = list.first.folder;
    final parent = folder.substring(0, folder.lastIndexOf('/'));
    if (parent.length > root.length) return parent.split('/').last;
    return 'Artista desconocido';
  }

  static Future<String?> _embeddedCover(String trackPath, String docsDir, String id) async {
    try {
      final m = readMetadata(File(trackPath), getImage: true);
      if (m.pictures.isEmpty) return null;
      final pic = m.pictures.first;
      final ext = pic.mimetype.contains('png') ? 'png' : 'jpg';
      final dir = Directory('$docsDir/covers');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/${id.hashCode.abs()}.$ext');
      await file.writeAsBytes(pic.bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String? _folderCover(List<String>? imgs) {
    if (imgs == null || imgs.isEmpty) return null;
    final pref = RegExp(r'^(cover|folder|front|album|artwork)\.', caseSensitive: false);
    for (final p in imgs) {
      if (pref.hasMatch(p.split('/').last)) return p;
    }
    return imgs.first;
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
