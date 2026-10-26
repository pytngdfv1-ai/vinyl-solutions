import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/vinyl.dart';
import 'fetch_bytes.dart';
import 'koofr_client.dart';
import 'koofr_settings.dart';

/// Decodifica (jpg/png/webp), reduce a 1600 px de ancho y recomprime en JPEG.
List<Object> _toJpeg(Uint8List bytes) {
  final im = img.decodeImage(bytes);
  if (im == null) throw Exception('Imagen no válida');
  final r = im.width > 1600 ? img.copyResize(im, width: 1600) : im;
  return [Uint8List.fromList(img.encodeJpg(r, quality: 82)), r.width, r.height];
}

/// Crea un PDF con las imágenes del libreto y lo guarda en la carpeta del disco.
class ImagesToPdf {
  static Future<Uint8List> build(List<String> urls, {void Function(int done, int total)? onProgress}) async {
    final doc = pw.Document();
    for (var i = 0; i < urls.length; i++) {
      final bytes = await fetchBytes(urls[i]);
      final r = await compute(_toJpeg, bytes);
      final w = (r[1] as int).toDouble();
      final h = (r[2] as int).toDouble();
      final image = pw.MemoryImage(r[0] as Uint8List);
      const pageW = 595.0;
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(pageW, pageW * h / w),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ));
      onProgress?.call(i + 1, urls.length);
    }
    return doc.save();
  }

  /// Guarda el PDF en la carpeta del disco (nube o teléfono) sin pisar otro.
  /// Devuelve la URL del PDF nuevo.
  static Future<String> saveInAlbumFolder(Vinyl v, Uint8List pdf, {String base = 'Libreto'}) async {
    if (v.trackUrls.isEmpty) throw Exception('Este disco no tiene carpeta');
    final first = v.trackUrls.first;
    if (first.startsWith('file:')) {
      final dir = File(Uri.parse(first).toFilePath()).parent;
      var name = '$base.pdf';
      var n = 2;
      while (await File('${dir.path}/$name').exists()) {
        name = '$base ($n).pdf';
        n++;
      }
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(pdf, flush: true);
      return Uri.file(f.path).toString();
    }
    final acct = KoofrAccounts.byUrl(first);
    if (acct == null) throw Exception('Cuenta no encontrada');
    final client = KoofrClient(acct);
    final rel = client.relSegments(first);
    final dir = rel.sublist(0, rel.length - 1);
    for (var n = 1; n <= 20; n++) {
      final name = n == 1 ? '$base.pdf' : '$base ($n).pdf';
      final ok = await client.putBytes(dir, name, pdf, overwrite: false, type: 'application/pdf');
      if (ok) return client.urlOf([...dir, name]);
    }
    throw Exception('Ya hay demasiados PDF con ese nombre');
  }
}
