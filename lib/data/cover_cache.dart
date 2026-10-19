import 'dart:io';
import 'dart:typed_data';

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
