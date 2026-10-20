import '../models/vinyl.dart';

/// Biblioteca a la que pertenece un disco: id de cuenta, 'local' o 'manual'.
String libraryOf(Vinyl v) => v.source ?? 'manual';

String _alnum(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

bool _isLocal(Vinyl v) => v.source == 'local' || v.id.startsWith('loc_');

String _albumKey(Vinyl v) {
  var t = _alnum(v.title.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ''));
  if (t.isEmpty) t = _alnum(v.title);
  return '${_alnum(v.artist)}|$t';
}

String _sortKey(String artist) {
  var a = artist.toLowerCase().trim();
  if (a.startsWith('the ')) a = a.substring(4);
  return a;
}

/// Ordena la biblioteca A→Z por artista (y año), quita duplicados
/// (se prefiere la copia del teléfono) e inserta un separador negro con el
/// nombre del artista siguiente entre un grupo y otro.
List<Vinyl> arrange(List<Vinyl> all, {bool singles = false}) {
  final best = <String, Vinyl>{};
  final order = <String>[];
  for (final v in all.where((e) => e.single == singles)) {
    final k = _albumKey(v);
    final cur = best[k];
    if (cur == null) {
      best[k] = v;
      order.add(k);
    } else if (!_isLocal(cur) && _isLocal(v)) {
      best[k] = v;
    }
  }
  final list = [for (final k in order) best[k]!];
  list.sort((a, b) {
    final c = _sortKey(a.artist).compareTo(_sortKey(b.artist));
    if (c != 0) return c;
    final ya = a.year > 0 ? a.year : 9999;
    final yb = b.year > 0 ? b.year : 9999;
    if (ya != yb) return ya.compareTo(yb);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  final out = <Vinyl>[];
  String? prev;
  for (final v in list) {
    final g = _alnum(v.artist);
    if (prev != null && g != prev) {
      out.add(Vinyl(id: 'sep_$g', title: v.artist, artist: '', year: 0, hue: 0, tracks: const []));
    }
    prev = g;
    out.add(v);
  }
  return out;
}
