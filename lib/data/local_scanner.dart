import 'dart:io';

import 'album_builder.dart';
import 'flac_meta.dart';
import 'library_settings.dart';

class LocalException implements Exception {
  const LocalException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lee una carpeta del teléfono. Solo toma álbumes completos:
/// Artista/Álbum/temas (con al menos [LibrarySettings.minTracks] temas).
class LocalScanner {
  static const _audioExt = ['.flac', '.mp3', '.m4a', '.ogg', '.opus', '.wav', '.aac'];
  static const _imageExt = ['.jpg', '.jpeg', '.png', '.webp'];

  String diagnostic = '';

  Future<ScanResult> scan(String rootPath, {void Function(String)? onProgress}) async {
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
    final min = LibrarySettings.minTracks;
    final drafts = <AlbumDraft>[];
    var skipped = 0;

    final dirs = byDir.keys.toList()..sort();
    for (final dir in dirs) {
      final list = byDir[dir]!;
      final audio = list.where((f) => _hasExt(f.path, _audioExt)).toList()
        ..sort((a, b) => _base(a.path).compareTo(_base(b.path)));
      if (audio.isEmpty) continue;

      final rel = dir.length > rootPath.length ? dir.substring(rootPath.length) : '';
      final names = rel.split('/').where((s) => s.isNotEmpty).toList();
      // Audio suelto en la carpeta elegida, o muy pocos temas: no es un álbum.
      if (names.isEmpty || audio.length < min) {
        skipped++;
        continue;
      }

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

      final first = audio.first.path;
      drafts.add(AlbumDraft(
        key: dir,
        idPrefix: 'loc_',
        folderArtist: names.length >= 2 ? names[names.length - 2] : null,
        folderAlbum: names.last,
        trackFiles: [for (final f in audio) _base(f.path)],
        trackUrls: [for (final f in audio) Uri.file(f.path).toString()],
        folderImageUrl: art == null ? null : Uri.file(art.path).toString(),
        readMeta: first.toLowerCase().endsWith('.flac') ? () => _meta(first) : null,
      ));
    }

    final result = await buildAlbums(drafts, skippedBefore: skipped, onProgress: onProgress);
    diagnostic = 'Vi $files archivos en "$rootName". '
        'Álbumes completos: ${result.albums.length}.';
    return result;
  }

  Future<FlacMeta?> _meta(String path) async {
    final raf = await File(path).open();
    try {
      return await readFlacMeta(buffered((s, l) async {
        await raf.setPosition(s);
        return await raf.read(l);
      }));
    } finally {
      await raf.close();
    }
  }

  static String _base(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  static bool _hasExt(String path, List<String> exts) {
    final p = path.toLowerCase();
    return exts.any(p.endsWith);
  }
}
