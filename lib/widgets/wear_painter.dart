import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/ui_settings.dart';
import '../models/vinyl.dart';

/// Desgaste procedural (sin imágenes): rayas finas, polvo y ruido. Estable por disco.
class Wear {
  /// Intensidad 0..0.7 derivada del identificador (los discos "usados" se ven más gastados).
  static double of(Vinyl v) {
    var h = 0;
    for (final c in v.id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return 0.12 + (h % 100) / 100 * 0.58;
  }

  static int seedOf(Vinyl v) {
    var h = 7;
    for (final c in v.id.codeUnits) {
      h = (h * 33 + c) & 0x7fffffff;
    }
    return h;
  }
}

class WearPainter extends CustomPainter {
  WearPainter({required this.seed, required this.wear, this.round = false});

  final int seed;
  final double wear;
  final bool round;

  @override
  void paint(Canvas canvas, Size size) {
    if (wear <= 0 || !UiSettings.fx) return;
    final rnd = math.Random(seed);
    final w = size.width, h = size.height;
    canvas.save();
    if (round) {
      canvas.clipPath(Path()..addOval(Offset.zero & size));
    }
    final scratch = Paint()
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final n = (10 + 40 * wear).round();
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * w, y = rnd.nextDouble() * h;
      final len = (0.04 + rnd.nextDouble() * 0.22) * math.min(w, h);
      final a = rnd.nextDouble() * math.pi * 2;
      scratch.color = Colors.white.withOpacity(0.04 + 0.16 * wear * rnd.nextDouble());
      canvas.drawLine(Offset(x, y), Offset(x + math.cos(a) * len, y + math.sin(a) * len), scratch);
    }
    final dust = Paint();
    final m = (30 + 120 * wear).round();
    for (var i = 0; i < m; i++) {
      dust.color = Colors.white.withOpacity(0.05 + 0.2 * wear * rnd.nextDouble());
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), 0.4 + rnd.nextDouble() * 0.6, dust);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WearPainter old) => old.seed != seed || old.wear != wear;
}
