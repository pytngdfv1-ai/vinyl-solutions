import 'dart:convert';
import 'dart:io';

import '../models/vinyl.dart';
import 'cover_lookup.dart';
import 'library_utils.dart';

class LocalException implements Exception {
  const LocalException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lee una carpeta del teléfono: cada carpeta con audio es un álbum y su
/// carpeta padre es el artista.
class LocalScanner {
  static const _audioExt = ['.flac', '.mp3', '.m4a', '.ogg', '.opus', '.wav', '.aac'];
  static const _imageExt = ['.jpg', '.jpeg', '.png', '.webp'];

  /// Resumen de lo visto (para diagnóstico).
  String diagnostic = '';

  Future<List<Vinyl>> scan(String rootPath, {void Function(String)? onProgress}) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw const LocalException('No se puede abrir la carpeta');
    }

    final byDir = <String, List<File>>{};
    var files = 0;
    await for (final e in root
        .list(recursive: true, followLinks: false)
        .handleError((_) {}, test: (e) => e is FileSystemException)) {
      if (e is File) {
        files++;
        byDir.putIfAbsent(e.parent.path, () => []).add(e);
      }
    }

    final rootName = _base(rootPath);
    final out = <Vinyl>[];
    final dirs = byDir.keys.toList()..sort();
    for (final dir in dirs) {
      final list = byDir[dir]!;
      final audio = list.where((f) => _hasExt(f.path, _audioExt)).toList()
        ..sort((a, b) => _base(a.path).compareTo(_base(b.path)));
      if (audio.isEmpty) continue;

      final rel = dir.length > rootPath.length ? dir.substring(rootPath.length) : '';
      final names = rel.split('/').where((s) => s.isNotEmpty).toList();
      final album = names.isNotEmpty ? names.last : rootName;
      var artist = names.length >= 2 ? names[names.length - 2] : 'Artista desconocido';
      if (artist == 'Artista desconocido') {
        artist = guessArtist([for (final f in audio) _base(f.path)]) ?? artist;
      }
      onProgress?.call(album);

      final images = list.where((f) => _hasExt(f.path, _imageExt)).toList();
      final pref = RegExp(r'^(cover|folder|front|album|artwork)\.', caseSensitive: false);
      File? art;
      for (final f in images) {
        if (pref.hasMatch(_base(f.path))) {
          art = f;
          break;
        }
      }
      art ??= images.isEmpty ? null : images.first;

      final cover = art != null
          ? Uri.file(art.path).toString()
          : await CoverLookup.find(artist, album);

      out.add(Vinyl(
        id: 'loc_${base64Url.encode(utf8.encode(dir))}',
        title: album,
        artist: artist,
        year: _year(album),
        hue: (dir.codeUnits.fold<int>(0, (s, c) => s + c) % 360).toDouble(),
        tracks: [for (final f in audio) _title(_base(f.path))],
        trackUrls: [for (final f in audio) Uri.file(f.path).toString()],
        coverUrl: cover,
        owned: true,
      ));
    }

    diagnostic = 'Vi $files archivos en "$rootName" y ${out.length} álbumes con audio.';
    return out;
  }

  static String _base(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  static bool _hasExt(String path, List<String> exts) {
    final p = path.toLowerCase();
    return exts.any(p.endsWith);
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
