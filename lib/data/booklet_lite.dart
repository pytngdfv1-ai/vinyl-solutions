import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';
import 'fetch_bytes.dart';

/// Folletos livianos: cada página del PDF se guarda como imagen WebP
/// (~1600 px de alto, calidad 78). El PDF original no se toca; por folleto
/// el usuario elige cuál ver.
class BookletLite {
  static const _key = 'booklet_lite_v1';
  static const _autoKey = 'booklet_lite_auto';
  static const pageHeight = 1600;
  static const quality = 78;

  static Map<String, List<String>> _pages = {};
  static Map<String, bool> _use = {};
  static bool auto = false;
  static final Set<String> _failed = {};
  static bool _running = false;

  static String _id(String pdfUrl) => base64Url.encode(utf8.encode(Uri.parse(pdfUrl).removeFragment().path));

  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      auto = p.getBool(_autoKey) ?? false;
      final raw = p.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _pages = {for (final e in (j['pages'] as Map).entries) e.key as String: List<String>.from(e.value as List)};
        _use = Map<String, bool>.from(j['use'] as Map);
      }
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode({'pages': _pages, 'use': _use}));
    } catch (_) {}
  }

  static Future<void> setAuto(bool v) async {
    auto = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_autoKey, v);
    } catch (_) {}
  }

  /// Páginas de la versión liviana (null si no existe).
  static List<String>? pagesOf(String pdfUrl) {
    final l = _pages[_id(pdfUrl)];
    return l == null || l.isEmpty ? null : l;
  }

  /// ¿Mostrar la versión liviana de este folleto? (por defecto sí, si existe)
  static bool useLite(String pdfUrl) => pagesOf(pdfUrl) != null && (_use[_id(pdfUrl)] ?? true);

  static Future<void> setUseLite(String pdfUrl, bool v) async {
    _use[_id(pdfUrl)] = v;
    await _save();
  }

  /// Tamaño en disco de la versión liviana (bytes).
  static Future<int> sizeOf(String pdfUrl) async {
    var n = 0;
    for (final u in pagesOf(pdfUrl) ?? const <String>[]) {
      try {
        n += await File(Uri.parse(u).toFilePath()).length();
      } catch (_) {}
    }
    return n;
  }

  /// Convierte el PDF a imágenes WebP. Lanza si no se puede.
  static Future<List<String>> convert(String pdfUrl, {void Function(int done, int total)? onProgress}) async {
    final bytes = await fetchBytes(pdfUrl);
    final doc = await PdfDocument.openData(bytes);
    final id = _id(pdfUrl);
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/booklets/${_hash(id)}');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final out = <String>[];
    try {
      final total = doc.pagesCount;
      for (var i = 1; i <= total; i++) {
        final page = await doc.getPage(i);
        try {
          final h = pageHeight.toDouble();
          final w = (page.width / page.height * h).roundToDouble();
          final img = await page.render(
            width: w,
            height: h,
            format: PdfPageImageFormat.webp,
            backgroundColor: '#FFFFFF',
            quality: quality,
          );
          if (img == null) throw Exception('No se pudo dibujar la página $i');
          final f = File('${dir.path}/p${i.toString().padLeft(3, '0')}.webp');
          await f.writeAsBytes(img.bytes, flush: true);
          out.add(Uri.file(f.path).toString());
        } finally {
          await page.close();
        }
        onProgress?.call(i, total);
      }
    } finally {
      await doc.close();
    }
    _pages[id] = out;
    _use[id] = true;
    await _save();
    return out;
  }

  /// Quita la versión liviana (el PDF original queda intacto).
  static Future<void> remove(String pdfUrl) async {
    final id = _id(pdfUrl);
    for (final u in _pages[id] ?? const <String>[]) {
      try {
        await File(Uri.parse(u).toFilePath()).delete();
      } catch (_) {}
    }
    _pages.remove(id);
    _use.remove(id);
    _failed.remove(id);
    await _save();
  }

  /// Si la opción está activa, convierte en segundo plano los PDF nuevos (de a uno).
  static Future<void> autoConvert(List<Vinyl> Function() items) async {
    if (!auto || _running) return;
    _running = true;
    try {
      for (final v in List.of(items())) {
        for (final pdf in v.pdfs) {
          if (pagesOf(pdf) != null || _failed.contains(_id(pdf))) continue;
          try {
            await convert(pdf);
          } catch (_) {
            _failed.add(_id(pdf)); // no se reintenta en esta sesión
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    } finally {
      _running = false;
    }
  }
}
