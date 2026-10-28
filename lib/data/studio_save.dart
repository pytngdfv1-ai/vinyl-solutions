import 'dart:io';
import 'dart:typed_data';

import '../models/vinyl.dart';
import 'cover_cache.dart';
import 'koofr_client.dart';
import 'koofr_settings.dart';
import 'vinyl_store.dart';

/// Guarda lo descargado en Cover Studio dentro de la carpeta del disco
/// (nube o teléfono / PC) y lo registra en la biblioteca.
class StudioSave {
  static String extOf(Uint8List b) {
    if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50) return 'png';
    if (b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57) return 'webp';
    if (b.length > 4 && b[0] == 0x25 && b[1] == 0x50) return 'pdf';
    return 'jpg';
  }

  static String mimeOf(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'image/jpeg',
      };

  static String safe(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Escribe [bytes] como "[base].[ext]" en la carpeta del disco sin pisar otro archivo.
  /// Devuelve la URL del archivo o null si el disco no tiene carpeta (disco a mano).
  static Future<String?> inFolder(Vinyl v, Uint8List bytes, String base, String ext) async {
    if (v.trackUrls.isEmpty) return null;
    final first = v.trackUrls.first;
    final b = safe(base);
    if (first.startsWith('file:')) {
      final dir = File(Uri.parse(first).toFilePath()).parent;
      var name = '$b.$ext';
      var n = 2;
      while (await File('${dir.path}${Platform.pathSeparator}$name').exists()) {
        name = '$b ($n).$ext';
        n++;
      }
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      await f.writeAsBytes(bytes, flush: true);
      return Uri.file(f.path).toString();
    }
    final acct = KoofrAccounts.byUrl(first);
    if (acct == null) throw Exception('Cuenta no encontrada');
    final client = KoofrClient(acct);
    final rel = client.relSegments(first);
    final dir = rel.sublist(0, rel.length - 1);
    for (var n = 1; n <= 30; n++) {
      final name = n == 1 ? '$b.$ext' : '$b ($n).$ext';
      final ok = await client.putBytes(dir, name, bytes, overwrite: false, type: mimeOf(ext));
      if (ok) return client.urlOf([...dir, name]);
    }
    throw Exception('Demasiados archivos con ese nombre');
  }

  /// Guarda una imagen. Con [asCover] además la deja como portada del disco;
  /// las páginas de libreto se suman al libreto.
  static Future<void> image(VinylStore store, Vinyl v, Uint8List bytes,
      {required String label, required String type, bool asCover = false}) async {
    final ext = extOf(bytes);
    final base = type == 'front' ? 'Portada' : label;
    final saved = await inFolder(v, bytes, base, ext);
    if (asCover) {
      // Copia local para verla sin conexión.
      final local = await CoverCache.save('studio_${v.id}_${DateTime.now().millisecondsSinceEpoch}', bytes, mimeOf(ext));
      await store.setCover(v.id, local);
    }
    if (type == 'booklet' && saved != null) await store.addBooklet(v.id, saved);
  }

  /// Guarda un PDF en la carpeta del disco y lo suma al libreto.
  static Future<bool> pdf(VinylStore store, Vinyl v, Uint8List bytes, String name) async {
    final base = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final url = await inFolder(v, bytes, base, 'pdf');
    if (url == null) return false;
    await store.addPdf(v.id, url);
    return true;
  }
}
