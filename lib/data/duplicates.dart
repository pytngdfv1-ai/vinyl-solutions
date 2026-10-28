import 'dart:io';

import '../models/vinyl.dart';
import 'cloud_upload.dart';
import 'koofr_client.dart';
import 'koofr_settings.dart';
import 'library_order.dart';

/// Copias de un mismo álbum o tema suelto.
class DupGroup {
  DupGroup(this.key, this.copies, this.exact);
  final String key;
  final List<Vinyl> copies;

  /// Mismo artista, título y exactamente las mismas pistas.
  final bool exact;
  Vinyl get first => copies.first;
}

class Duplicates {
  static String _a(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  static String _title(String s) {
    final t = _a(s.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ''));
    return t.isEmpty ? _a(s) : t;
  }

  static String _tracks(Vinyl v) => [for (final t in v.tracks) _title(t)].join('|');

  /// Datos que se perderían al borrar una copia: la que más tiene se conserva.
  static int score(Vinyl v) =>
      (v.coverUrl != null ? 2 : 0) +
      v.pdfs.length +
      (v.booklet.isNotEmpty ? 1 : 0) +
      (v.langManual ? 1 : 0) +
      (v.coverManual ? 1 : 0);

  /// Copia sugerida para conservar.
  static Vinyl keep(DupGroup g) {
    var best = g.copies.first;
    for (final v in g.copies.skip(1)) {
      if (score(v) > score(best)) best = v;
    }
    return best;
  }

  static List<DupGroup> find(Iterable<Vinyl> items) {
    final map = <String, List<Vinyl>>{};
    for (final v in items) {
      if (v.isDivider || !v.hasAudio) continue;
      map.putIfAbsent('${v.single ? 's' : 'a'}|${_a(v.artist)}|${_title(v.title)}', () => []).add(v);
    }
    final out = <DupGroup>[];
    for (final e in map.entries) {
      if (e.value.length < 2) continue;
      final t = _tracks(e.value.first);
      final exact = e.value.every((v) => v.tracks.length == e.value.first.tracks.length && _tracks(v) == t);
      out.add(DupGroup(e.key, e.value, exact));
    }
    out.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      return a.first.artist.toLowerCase().compareTo(b.first.artist.toLowerCase());
    });
    return out;
  }

  static KoofrSettings? account(Vinyl v) {
    for (final a in KoofrAccounts.list) {
      if (sourceInAccount(v.source, a.id)) return a;
    }
    return null;
  }

  /// Dónde está la copia, en palabras.
  static String where(Vinyl v) {
    if (CloudUpload.isLocal(v)) {
      final p = Uri.parse(v.trackUrls.first).toFilePath();
      return 'Teléfono · ${File(p).parent.path}';
    }
    final a = account(v);
    if (a == null) return 'Sin carpeta';
    final rel = KoofrClient(a).relSegments(v.trackUrls.first);
    return 'Nube · ${rel.sublist(0, rel.length - 1).join('/')}';
  }

  /// Quita una copia: en la nube la mueve a "_duplicados" (o la borra); en el teléfono la borra.
  /// Un tema suelto solo quita su archivo; un álbum, su carpeta entera.
  static Future<void> remove(Vinyl v, {required bool trash}) async {
    if (v.trackUrls.isEmpty) return;
    if (CloudUpload.isLocal(v)) {
      await CloudUpload.deleteLocal(v);
      return;
    }
    final acct = account(v);
    if (acct == null) throw const KoofrException('Cuenta no encontrada');
    final client = KoofrClient(acct);
    Future<void> one(List<String> rel, bool isDir) => trash
        ? client.execute(MovePlan(rel, ['_duplicados', ...rel], isDir: isDir))
        : client.remove(rel, isDir: isDir);
    if (v.single) {
      for (final u in v.trackUrls) {
        await one(client.relSegments(u), false);
      }
    } else {
      final rel = client.relSegments(v.trackUrls.first);
      await one(rel.sublist(0, rel.length - 1), true);
    }
  }
}
