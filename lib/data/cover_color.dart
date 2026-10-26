import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'fetch_bytes.dart';

/// Color dominante (promedio ponderado por saturación) de una portada.
class CoverColor {
  static final Map<String, Color?> _cache = {};

  static Future<Color?> of(String? url) async {
    if (url == null) return null;
    if (_cache.containsKey(url)) return _cache[url];
    Color? out;
    try {
      final Uint8List bytes = await fetchBytes(url);
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
      final img = (await codec.getNextFrame()).image;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (data != null) {
        var r = 0.0, g = 0.0, b = 0.0, wsum = 0.0;
        for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
          final pr = data.getUint8(i), pg = data.getUint8(i + 1), pb = data.getUint8(i + 2);
          final mx = [pr, pg, pb].reduce((a, c) => a > c ? a : c);
          final mn = [pr, pg, pb].reduce((a, c) => a < c ? a : c);
          final w = 0.2 + (mx - mn) / 255.0; // favorece los colores vivos
          r += pr * w;
          g += pg * w;
          b += pb * w;
          wsum += w;
        }
        if (wsum > 0) {
          out = Color.fromARGB(255, (r / wsum).round(), (g / wsum).round(), (b / wsum).round());
        }
      }
    } catch (_) {
      return null; // sin conexión o imagen inválida: se usa el fondo normal
    }
    _cache[url] = out;
    return out;
  }

  /// Versión oscura del color, apta como fondo del reproductor.
  static Color background(Color c) {
    final h = HSLColor.fromColor(c);
    return h.withSaturation((h.saturation * 0.8).clamp(0.15, 0.6)).withLightness(0.16).toColor();
  }
}
