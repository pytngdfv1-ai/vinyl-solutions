import 'dart:convert';

import '../models/vinyl.dart';
import 'cover_cache.dart';
import 'cover_lookup.dart';
import 'flac_meta.dart';
import 'library_utils.dart';

/// Álbum detectado en una carpeta, antes de resolver artista y portada.
class AlbumDraft {
  AlbumDraft({
    required this.key,
    required this.idPrefix,
    required this.folderArtist,
    required this.folderAlbum,
    required this.trackFiles,
    required this.trackUrls,
    this.folderImageUrl,
    this.bookletImages = const [],
    this.pdfs = const [],
    this.single = false,
    this.fallbackArtist,
    this.source,
    this.path = const [],
    this.readMeta,
  });

  final String key;
  final String idPrefix; // 'dav_' o 'loc_'
  final String? folderArtist;
  final String folderAlbum;
  final List<String> trackFiles;
  final List<String> trackUrls;
  final String? folderImageUrl;
  final List<String> bookletImages;
  final List<String> pdfs;

  /// Tema suelto (va al baúl de sueltos). [fallbackArtist] se usa si no hay etiquetas.
  final bool single;
  final String? fallbackArtist;

  /// Biblioteca de origen y ruta completa de carpetas (para detectar categorías).
  final String? source;
  final List<String> path;
  final Future<FlacMeta?> Function()? readMeta;

  String get id => '$idPrefix${base64Url.encode(utf8.encode(key))}';
}

class ScanResult {
  ScanResult(this.albums, this.skipped, this.noCover);
  final List<Vinyl> albums;

  /// Carpetas ignoradas (temas sueltos o con pocos temas).
  final int skipped;

  /// Álbumes para los que no se encontró portada.
  final List<String> noCover;

  String summary(int minTracks) {
    final singles = albums.where((a) => a.single).length;
    final full = albums.length - singles;
    final b = StringBuffer('$full álbumes');
    if (singles > 0) b.write(' y $singles temas sueltos');
    b.write(' agregados.');
    if (skipped > 0) {
      b.write(' Ignoré $skipped elementos sin artista identificable.');
    }
    if (noCover.isNotEmpty) {
      b.write(
        '\nSin portada (${noCover.length}): ${noCover.take(5).join(', ')}'
        '${noCover.length > 5 ? '…' : ''}. Agrega un cover.jpg en esa carpeta.',
      );
    }
    return b.toString();
  }
}

/// Resuelve artista, año y portada de cada álbum (4 a la vez).
Future<ScanResult> buildAlbums(
  List<AlbumDraft> drafts, {
  int skippedBefore = 0,
  void Function(String)? onProgress,
  Map<String, Vinyl> reuse = const {},
}) async {
  final built = List<Vinyl?>.filled(drafts.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= drafts.length) return;
      final d = drafts[i];
      onProgress?.call(d.folderAlbum);
      final old = reuse[d.id];
      if (old != null && old.coverUrl != null && old.year > 0 && old.trackUrls.length == d.trackUrls.length) {
        // Ya estaba en la biblioteca: se conserva portada y datos, se refrescan archivos.
        built[i] = old.copyWith(
          tracks: [for (final t in d.trackFiles) trackTitle(t, artist: old.artist)],
          trackUrls: d.trackUrls,
          coverUrl: d.folderImageUrl,
          booklet: d.bookletImages,
          pdfs: d.pdfs,
        );
        continue;
      }
      try {
        built[i] = await _build(d);
      } catch (_) {
        built[i] = null;
      }
    }
  }

  await Future.wait([for (var w = 0; w < 4; w++) worker()]);

  final albums = <Vinyl>[];
  final noCover = <String>[];
  var skipped = skippedBefore;
  for (final v in built) {
    if (v == null) {
      skipped++;
      continue;
    }
    albums.add(v);
    if (v.coverUrl == null) noCover.add('${v.artist} - ${v.title}');
  }
  return ScanResult(albums, skipped, noCover);
}

Future<Vinyl?> _build(AlbumDraft d) async {
  FlacMeta? m;
  try {
    m = await d.readMeta?.call();
  } catch (_) {}

  final artist = d.folderArtist ??
      m?.albumArtist ??
      m?.artist ??
      guessArtist(d.trackFiles) ??
      d.fallbackArtist;
  if (artist == null || artist.trim().isEmpty) return null; // sin artista

  final tracks = [for (final t in d.trackFiles) trackTitle(t, artist: artist)];
  final title = d.single ? tracks.first : d.folderAlbum;

  var cover = d.folderImageUrl;
  final pic = m?.picture;
  if (cover == null && pic != null) {
    try {
      cover = await CoverCache.save(d.key, pic, m?.pictureMime);
    } catch (_) {}
  }
  var year = yearOf(m?.date);
  if (year == 0 && !d.single) year = yearOf(d.folderAlbum);

  // Portada en internet y/o año de lanzamiento si faltan.
  if (cover == null || year == 0) {
    final tagAlbum = m?.album;
    final hit = await CoverLookup.find(
      artist: artist,
      albums: [
        if (tagAlbum != null) tagAlbum,
        if (d.folderAlbum.isNotEmpty) d.folderAlbum,
      ],
      tracks: tracks,
      trackFirst: d.single,
    );
    cover ??= hit?.url;
    if (year == 0) year = hit?.year ?? 0;
  }

  return Vinyl(
    id: d.id,
    title: title,
    artist: artist,
    year: year,
    hue: (d.key.codeUnits.fold<int>(0, (s, c) => s + c) % 360).toDouble(),
    tracks: tracks,
    trackUrls: d.trackUrls,
    coverUrl: cover,
    booklet: d.bookletImages,
    pdfs: d.pdfs,
    single: d.single,
    source: d.source,
    owned: true,
  );
}
