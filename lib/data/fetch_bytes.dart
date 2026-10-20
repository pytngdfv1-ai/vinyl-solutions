import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'koofr_settings.dart';

/// Descarga un archivo (local o de Koofr) en memoria.
Future<Uint8List> fetchBytes(String url) async {
  if (url.startsWith('file:')) {
    return File(Uri.parse(url).toFilePath()).readAsBytes();
  }
  final res = await http
      .get(
        Uri.parse(url),
        headers: KoofrSettings.headersFor(url) ?? const {},
      )
      .timeout(const Duration(seconds: 90));
  if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
  return res.bodyBytes;
}
