import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'koofr_settings.dart';

/// Caché de miniaturas en disco: las portadas de la nube se descargan una vez,
/// se reducen (máx. 720 px) y después se leen del teléfono, sin red.
class ThumbCache {
  static Directory? _dir;
  static final Map<String, Future<File?>> _pending = {};
  static int _active = 0;
  static final List<Completer<void>> _queue = [];

  static Future<Directory> _root() async {
    final d = _dir;
    if (d != null) return d;
    final base = await getApplicationSupportDirectory();
    final n = Directory('${base.path}/thumbs');
    await n.create(recursive: true);
    return _dir = n;
  }

  static String _name(String s) {
    var a = 0x811c9dc5;
    var b = 0x811c9dc5;
    final u = s.codeUnits;
    for (var i = 0; i < u.length; i++) {
      a = ((a ^ u[i]) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ u[u.length - 1 - i]) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${a.toRadixString(16)}${b.toRadixString(16)}.jpg';
  }

  /// Miniatura en disco (la descarga si hace falta). null si no se pudo.
  static Future<File?> get(String url) => _pending.putIfAbsent(url, () => _load(url).whenComplete(() => _pending.remove(url)));

  static Future<File?> _load(String url) async {
    try {
      final f = File('${(await _root()).path}/${_name(url)}');
      if (await f.exists() && await f.length() > 100) return f;
      await _slot();
      try {
        final res = await http.get(Uri.parse(url), headers: KoofrSettings.headersFor(url)).timeout(const Duration(seconds: 25));
        if (res.statusCode != 200 || res.bodyBytes.length < 200) return null;
        final out = await compute(_shrink, res.bodyBytes);
        await f.writeAsBytes(out, flush: true);
        return f;
      } finally {
        _release();
      }
    } catch (_) {
      return null;
    }
  }

  // Máximo 3 descargas a la vez para no saturar la lista.
  static Future<void> _slot() async {
    if (_active < 3) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
  }

  static void _release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  /// Tamaño usado por la caché (bytes).
  static Future<int> size() async {
    var n = 0;
    final d = await _root();
    await for (final e in d.list()) {
      if (e is File) n += await e.length();
    }
    return n;
  }

  static Future<void> clear() async {
    final d = await _root();
    await for (final e in d.list()) {
      if (e is File) await e.delete();
    }
  }
}

Uint8List _shrink(Uint8List bytes) {
  try {
    final im = img.decodeImage(bytes);
    if (im == null) return bytes;
    final r = im.width > 720 ? img.copyResize(im, width: 720) : im;
    return Uint8List.fromList(img.encodeJpg(r, quality: 82));
  } catch (_) {
    return bytes;
  }
}
