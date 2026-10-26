import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';
import 'fetch_bytes.dart';
import 'koofr_client.dart';
import 'koofr_settings.dart';
import 'library_utils.dart';

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
  static const _besideKey = 'booklet_lite_beside';
  static bool auto = false;

  /// Guarda también las páginas junto al PDF original (nube o carpeta del teléfono).
  static bool beside = true;

  /// Aviso del último intento de guardar junto al PDF (null = todo bien).
  static String? lastNote;
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
      beside = p.getBool(_besideKey) ?? true;
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

  static Future<void> setBeside(bool v) async {
    beside = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_besideKey, v);
    } catch (_) {}
  }

  static const _prefix = 'Libreto liviano - ';

  static String _pdfName(String pdfUrl) {
    var n = Uri.parse(pdfUrl).pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'PDF');
    try {
      n = Uri.decodeComponent(n);
    } catch (_) {}
    return n.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
  }

  /// Nombre de la carpeta donde se guardan las páginas junto al PDF.
  static String liteFolder(String pdfUrl) => '$_prefix${_pdfName(pdfUrl)}';

  /// ¿Es una página liviana guardada junto al PDF (no un libreto normal)?
  static bool isLitePage(String url) =>
      Uri.decodeFull(Uri.parse(url).removeFragment().path).contains('/$_prefix');

  /// Páginas livianas que el disco ya trae de la carpeta (hechas en otro equipo).
  static List<String>? remotePages(Vinyl v, String pdfUrl) {
    final key = '/${liteFolder(pdfUrl)}/';
    final l = [
      for (final u in v.booklet)
        if (Uri.decodeFull(Uri.parse(u).removeFragment().path).contains(key)) u,
    ]..sort(naturalCompare);
    return l.isEmpty ? null : l;
  }

  /// Páginas de la versión liviana (null si no existe).
  static List<String>? pagesOf(String pdfUrl) {
    final l = _pages[_id(pdfUrl)];
    return l == null || l.isEmpty ? null : l;
  }

  /// ¿Mostrar la versión liviana de este folleto? (por defecto sí, si existe)
  static bool useLite(String pdfUrl) => pagesOf(pdfUrl) != null && (_use[_id(pdfUrl)] ?? true);

  /// Elección del usuario para este folleto (por defecto: la liviana, si existe).
  static bool preferLite(String pdfUrl) => _use[_id(pdfUrl)] ?? true;

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
    lastNote = null;
    if (beside) {
      try {
        await _putBeside(pdfUrl, out);
      } on KoofrException catch (e) {
        lastNote = 'No se guardó junto al PDF: ${e.message}';
      } catch (e) {
        lastNote = 'No se guardó junto al PDF: $e';
      }
    }
    return out;
  }

  /// Copia las páginas a `Libreto liviano - <pdf>` al lado del PDF (si el PDF está en una
  /// carpeta de libreto, al lado de esa carpeta, para que el escáner la encuentre).
  static Future<void> _putBeside(String pdfUrl, List<String> pages) async {
    final folder = liteFolder(pdfUrl);
    if (pdfUrl.startsWith('file:')) {
      var dir = File(Uri.parse(pdfUrl).toFilePath()).parent;
      if (isBookletDir(dir.uri.pathSegments.where((x) => x.isNotEmpty).last)) dir = dir.parent;
      final dest = Directory('${dir.path}/$folder');
      await dest.create(recursive: true);
      for (final u in pages) {
        final f = File(Uri.parse(u).toFilePath());
        await f.copy('${dest.path}/${f.uri.pathSegments.last}');
      }
      return;
    }
    final acct = KoofrAccounts.byUrl(pdfUrl);
    if (acct == null) throw const KoofrException('Cuenta no encontrada');
    final client = KoofrClient(acct);
    var dir = client.relSegments(pdfUrl);
    dir = dir.sublist(0, dir.length - 1);
    if (dir.isNotEmpty && isBookletDir(dir.last)) dir = dir.sublist(0, dir.length - 1);
    final dest = [...dir, folder];
    await client.ensureDir(dest);
    for (final u in pages) {
      final f = File(Uri.parse(u).toFilePath());
      await client.putBytes(dest, f.uri.pathSegments.last, await f.readAsBytes(), type: 'image/webp');
    }
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
