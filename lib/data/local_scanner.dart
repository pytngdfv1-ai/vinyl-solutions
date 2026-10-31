import 'dart:io';

import '../models/vinyl.dart';
import 'album_builder.dart';
import 'flac_meta.dart';
import 'library_settings.dart';
import 'library_utils.dart';

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

  Future<ScanResult> scan(String rootPath,
      {void Function(String)? onProgress, Map<String, Vinyl> reuse = const {}}) async {
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

    List<String> namesOf(String dir) {
      final rel = dir.length > rootPath.length ? dir.substring(rootPath.length) : '';
      return rel.split('/').where((s) => s.isNotEmpty).toList();
    }

    // ¿La carpeta está organizada en categorías (Inglés / Español…)?
    final split = detectSplit([
      for (final d in dirs)
        if (byDir[d]!.where((f) => _hasExt(f.path, _audioExt)).length >= min) namesOf(d),
    ]);

    for (final dir in dirs) {
      final list = byDir[dir]!;
      final audio = list.where((f) => _hasExt(f.path, _audioExt)).toList()
        ..sort((a, b) => _base(a.path).compareTo(_base(b.path)));
      if (audio.isEmpty) continue;

      final fullNames = namesOf(dir);
      String? group;
      var names = fullNames;
      if (split && names.isNotEmpty) {
        group = names.first;
        names = names.sublist(1);
      }
      final src = group == null ? 'local' : 'local:$group';
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

      // Audio suelto en la carpeta elegida o carpeta con pocos temas:
      // cada tema va al baúl de temas sueltos.
      if (names.isEmpty || audio.length < min) {
        for (final f in audio) {
          final p = f.path;
          drafts.add(AlbumDraft(
            key: p,
            source: src,
            idPrefix: 'locs_',
            single: true,
            folderArtist: names.length >= 2 ? names[names.length - 2] : null,
            fallbackArtist: names.length == 1 ? names.first : null,
            folderAlbum: names.isEmpty ? '' : names.last,
            trackFiles: [_base(p)],
            trackUrls: [Uri.file(p).toString()],
            folderImageUrl: names.isEmpty || art == null ? null : Uri.file(art.path).toString(),
            readMeta: p.toLowerCase().endsWith('.flac') ? () => _meta(p) : null,
          ));
        }
        continue;
      }

      // Libreto: el resto de imágenes y PDFs de la carpeta y de sus subcarpetas
      // "Libreto", "Booklet", "Scans", "Artwork"…
      final imgs = <File>[...images.where((f) => f != art)];
      final pdfs = <File>[...list.where((f) => _hasExt(f.path, const ['.pdf']))];
      imgs.sort((a, b) => naturalCompare(_base(a.path), _base(b.path)));
      pdfs.sort((a, b) => naturalCompare(_base(a.path), _base(b.path)));
      for (final sub in dirs.where((d) => d.startsWith('$dir/') && isBookletDir(_base(d)))) {
        if (sub.substring(dir.length + 1).contains('/')) continue; // solo hijas directas
        final sl = byDir[sub]!;
        imgs.addAll(sl.where((f) => _hasExt(f.path, _imageExt))
            .toList()..sort((a, b) => naturalCompare(_base(a.path), _base(b.path))));
        pdfs.addAll(sl.where((f) => _hasExt(f.path, const ['.pdf']))
            .toList()..sort((a, b) => naturalCompare(_base(a.path), _base(b.path))));
      }
      final booklet = (
        [for (final f in imgs) Uri.file(f.path).toString()],
        [for (final f in pdfs) Uri.file(f.path).toString()],
      );

      final first = audio.first.path;
      drafts.add(AlbumDraft(
        key: dir,
        source: src,
        path: fullNames,
        idPrefix: 'loc_',
        folderArtist: names.length >= 2 ? names[names.length - 2] : null,
        folderAlbum: names.last,
        trackFiles: [for (final f in audio) _base(f.path)],
        trackUrls: [for (final f in audio) Uri.file(f.path).toString()],
        folderImageUrl: art == null ? null : Uri.file(art.path).toString(),
        bookletImages: booklet.$1,
        pdfs: booklet.$2,
        readMeta: first.toLowerCase().endsWith('.flac') ? () => _meta(first) : null,
      ));
    }

    final result = await buildAlbums(drafts, skippedBefore: skipped, onProgress: onProgress, reuse: reuse);
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
