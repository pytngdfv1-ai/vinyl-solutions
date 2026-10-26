import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Guarda carátulas incrustadas en el teléfono (funcionan sin conexión).
class CoverCache {
  static Future<String> save(String key, Uint8List bytes, String? mime) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/covers');
    await dir.create(recursive: true);
    final ext = (mime ?? '').contains('png') ? 'png' : 'jpg';
    final f = File('${dir.path}/${_hash(key)}.$ext');
    await f.writeAsBytes(bytes, flush: true);
    return Uri.file(f.path).toString();
  }

  /// Descarga una portada de internet y la guarda en el teléfono (funciona sin conexión).
  /// Si no se puede descargar, devuelve la misma URL.
  static Future<String> remember(String key, String url) async {
    if (url.startsWith('file:')) return url;
    try {
      final res = await http
          .get(Uri.parse(url), headers: const {'User-Agent': 'VinylSolutions/1.0 (personal music library app)'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.length < 500) return url;
      return await save(key, res.bodyBytes, res.headers['content-type']);
    } catch (_) {
      return url;
    }
  }

  static String _hash(String s) {
    var a = 0x811c9dc5;
    var b = 0x811c9dc5;
    final units = s.codeUnits;
    for (var i = 0; i < units.length; i++) {
      a = ((a ^ units[i]) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ units[units.length - 1 - i]) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${a.toRadixString(16)}${b.toRadixString(16)}';
  }
}
