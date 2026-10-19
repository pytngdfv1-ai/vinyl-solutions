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
