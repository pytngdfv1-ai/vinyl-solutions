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
