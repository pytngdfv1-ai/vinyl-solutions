/// Intenta deducir el artista desde nombres tipo "Título - Artista.flac".
String? guessArtist(List<String> fileNames) {
  final counts = <String, int>{};
  for (final f in fileNames) {
    final base = f.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), '');
    final parts = base.split(' - ').map((e) => e.trim()).toList();
    if (parts.length < 2) continue;
    if (parts.length == 2 && RegExp(r'^\d+$').hasMatch(parts.first)) continue;
    final a = parts.last;
    if (a.isEmpty) continue;
    counts[a] = (counts[a] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  final need = fileNames.length <= 2 ? 1 : (fileNames.length * 0.6).ceil();
  return best.value >= need ? best.key : null;
}

/// Título legible desde el nombre de archivo (sin número, extensión ni
/// " - Artista" final).
String trackTitle(String file, {String? artist}) {
  var t = file.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), '');
  t = t.replaceFirst(RegExp(r'^\d+\s*[-._)]*\s*'), '');
  if (artist != null) {
    final suffix = ' - $artist';
    if (t.toLowerCase().endsWith(suffix.toLowerCase())) {
      t = t.substring(0, t.length - suffix.length);
    }
  }
  t = t.trim();
  return t.isEmpty ? file : t;
}

int yearOf(String? s) {
  if (s == null) return 0;
  final m = RegExp(r'(19|20)\d{2}').firstMatch(s);
  return m == null ? 0 : int.parse(m.group(0)!);
}

/// Orden "natural": 2 antes que 10.
int naturalCompare(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final x = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final y = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final nx = int.tryParse(x[i]);
    final ny = int.tryParse(y[i]);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

/// ¿Es una subcarpeta de libreto/extras de un álbum?
bool isBookletDir(String name) => RegExp(
      r'libreto|booklet|scans?|artwork|extras?|inlay|insert|book',
      caseSensitive: false,
    ).hasMatch(name);

/// ¿La carpeta raíz está organizada en categorías (ej.: Inglés / Español)?
/// Estructura Categoría/Artista/Álbum con pocas categorías de primer nivel.
bool detectSplit(List<List<String>> paths) {
  if (paths.length < 4) return false;
  if (paths.any((p) => p.length < 3)) return false;
  final firsts = <String, Set<String>>{};
  for (final p in paths) {
    firsts.putIfAbsent(p[0], () => {}).add(p[1]);
  }
  if (firsts.length < 2 || firsts.length > 8) return false;
  return firsts.values.where((s) => s.length >= 2).length >= 2;
}
