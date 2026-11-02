import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/ui_settings.dart';
import '../models/vinyl.dart';
import 'cover_art.dart';

/// Estado de los carretes: ángulos (giro antihorario) y avance de la cinta.
class ReelState extends ChangeNotifier {
  double aL = 0, aR = 0, overall = 0;
  Color tint = const Color(0xFFE8C14A);
  /// Luz 0..1 (inclinación del teléfono) para el reflejo del plástico.
  double light = 0.5;
  /// Desgaste 0..1.
  double wear = 0;
  void tick() => notifyListeners();
}


/// Cassette único: el mismo dibujo en la animación de apertura, en el casetero y al expulsar.
/// Carcasa con grosor, ventana con carretes y cinta, tornillos, ranuras de la base,
/// etiqueta con la portada y reflejo en el plástico.
class CassetteBody extends StatelessWidget {
  const CassetteBody({
    super.key,
    required this.vinyl,
    required this.label,
    required this.st,
    this.sideB = false,
  });

  final Vinyl vinyl;
  final String label;
  final bool sideB;
  final ReelState st;

  @override
  Widget build(BuildContext context) {
    final v = vinyl;
    return LayoutBuilder(builder: (context, c) {
      final cw = c.maxWidth, ch = c.maxHeight;
      return Stack(
        children: [
          CustomPaint(size: Size(cw, ch), painter: _CassettePainter(st)),
          // Etiqueta de color: la portada adaptada cubre la franja (sin tapar la ventana).
          if (v.coverUrl != null)
            Positioned.fill(
              child: ClipPath(
                clipper: _StripClipper(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArt(vinyl: v, radius: 0),
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x33000000)),
                    ),
                  ],
                ),
              ),
            ),
          // Etiqueta escrita a mano.
          Positioned(
            left: cw * 0.09,
            top: ch * 0.09,
            width: cw * 0.84,
            height: ch * 0.22,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'cursive',
                  color: const Color(0xFF1F3C88),
                  fontWeight: FontWeight.w700,
                  fontSize: cw * 0.068,
                ),
              ),
            ),
          ),
          Positioned(
            left: cw * 0.085,
            top: ch * 0.6,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: cw * 0.014),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(1.5),
              ),
              child: Text(
                sideB ? 'B' : 'A',
                style: TextStyle(
                    color: const Color(0xFFF2F2F2),
                    fontWeight: FontWeight.w900,
                    fontSize: cw * 0.045),
              ),
            ),
          ),
          Positioned(
            right: cw * 0.12,
            top: ch * 0.6,
            child: Text(
              'NORMAL · ${v.tracks.length} T',
              style: TextStyle(
                  color: const Color(0xFF3B3B3B),
                  fontWeight: FontWeight.w800,
                  fontSize: cw * 0.026),
            ),
          ),
          // Reflejo del vidrio de la tapa.
          IgnorePointer(
            child: CustomPaint(size: Size(cw, ch), painter: _GlassPainter()),
          ),
        ],
      );
    });
  }
}

/// Franja de color del cassette menos la ventana en píldora.
class _StripClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final strip = Path()..addRect(Rect.fromLTRB(w * 0.07, h * 0.31, w * 0.943, h * 0.74));
    final pill = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.21, h * 0.337, w * 0.805, h * 0.585),
        Radius.circular(h * 0.124),
      ));
    return Path.combine(PathOperation.difference, strip, pill);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class CassetteScrew extends StatelessWidget {
  const CassetteScrew(this.d);
  final double d;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: d,
        height: d,
        child: CustomPaint(painter: _ScrewPainter()),
      );
}

class _ScrewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFB9BCC0), Color(0xFF5B5E62)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final slot = Paint()
      ..color = const Color(0xFF1C1D1F)
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + Offset(-r * 0.6, r * 0.2), c + Offset(r * 0.6, -r * 0.2), slot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}


/// Vidrio de la tapa: brillo diagonal y borde.
class _GlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final shine = Path()
      ..moveTo(s.width * 0.05, 0)
      ..lineTo(s.width * 0.30, 0)
      ..lineTo(s.width * 0.08, s.height)
      ..lineTo(0, s.height)
      ..lineTo(0, s.height * 0.4)
      ..close();
    canvas.drawPath(shine, Paint()..color = const Color(0x10FFFFFF));
    final shine2 = Path()
      ..moveTo(s.width * 0.36, 0)
      ..lineTo(s.width * 0.42, 0)
      ..lineTo(s.width * 0.2, s.height)
      ..lineTo(s.width * 0.14, s.height)
      ..close();
    canvas.drawPath(shine2, Paint()..color = const Color(0x0AFFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}


/// Cassette dibujado con las proporciones de un cassette real (medidas tomadas de la
/// imagen de referencia): etiqueta, franja de color, ventana tipo píldora con los dos
/// carretes en sus extremos, ventanilla del contador y parte baja con rodillos.
class _CassettePainter extends CustomPainter {
  _CassettePainter(this.st) : super(repaint: st);

  final ReelState st;
  double get overall => st.overall;
  Color get tint => st.tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shell = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.03));
    // Grosor visible de la carcasa (canto inferior derecho).
    canvas.drawRRect(shell.shift(Offset(w * 0.010, h * 0.018)), Paint()..color = const Color(0xFF0E0F10));
    canvas.drawRRect(
      shell.shift(Offset(w * 0.005, h * 0.009)),
      Paint()..color = const Color(0xFF1C1D1F),
    );

    // --- Carcasa: plástico ahumado transparente ---
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C3E41), Color(0xFF232426), Color(0xFF2E3033)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawRRect(
      shell.deflate(w * 0.008),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x44FFFFFF),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0x99B8BCC2),
    );

    // --- Etiqueta blanca (esquinas superiores cortadas) ---
    final l = w * 0.07, r = w * 0.943;
    final lt = h * 0.09, lb = h * 0.31;
    final cx = w * 0.03, cyc = h * 0.045;
    final labPath = Path()
      ..moveTo(l + cx, lt)
      ..lineTo(r - cx, lt)
      ..lineTo(r, lt + cyc)
      ..lineTo(r, lb)
      ..lineTo(l, lb)
      ..lineTo(l, lt + cyc)
      ..close();
    final labRect = Rect.fromLTRB(l, lt, r, lb);
    canvas.drawPath(
      labPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCFAF4), Color(0xFFE9E4D6)],
        ).createShader(labRect),
    );
    final rule = Paint()
      ..color = const Color(0x553B63C4)
      ..strokeWidth = 0.7;
    for (var i = 1; i <= 3; i++) {
      final y = lt + (lb - lt) * (0.28 + i * 0.2);
      canvas.drawLine(Offset(l + 6, y), Offset(r - 6, y), rule);
    }
    canvas.drawLine(
      Offset(l + w * 0.07, lt),
      Offset(l + w * 0.07, lb),
      Paint()
        ..color = const Color(0x55D8453C)
        ..strokeWidth = 0.8,
    );

    // --- Franja de color (naranja en la referencia; aquí, el tono del disco) ---
    final strip = Rect.fromLTRB(l, lb, r, h * 0.74);
    canvas.drawRect(strip, Paint()..color = tint);
    canvas.drawRect(Rect.fromLTRB(l, lb, r, lb + h * 0.012), Paint()..color = const Color(0x55000000));
    canvas.drawRect(
      Rect.fromLTRB(l, lb + h * 0.012, r, lb + h * 0.07),
      Paint()..color = const Color(0x22FFFFFF),
    );

    // --- Ventana en forma de píldora con los dos carretes en los extremos ---
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.21, h * 0.337, w * 0.805, h * 0.585),
      Radius.circular(h * 0.124),
    );
    canvas.drawRRect(pill, Paint()..color = const Color(0xFF2A2A2C));
    canvas.drawRRect(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55000000),
    );

    final hubR = h * 0.0945; // diámetro del carrete = 0,19 de la altura (como la referencia)
    final fullR = h * 0.1245; // el rollo lleno llega al borde de la píldora
    final emptyR = hubR * 1.07;
    final cy = h * 0.459;
    final lx = w * 0.288;
    final rx = w * 0.727;
    final rl = emptyR + (fullR - emptyR) * (1 - overall); // se vacía
    final rr = emptyR + (fullR - emptyR) * overall; // se llena

    canvas.save();
    canvas.clipRRect(pill);
    for (final e in [(Offset(lx, cy), rl), (Offset(rx, cy), rr)]) {
      final c = e.$1;
      final rad = e.$2;
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0xFF6B4A33), Color(0xFF3A2619), Color(0xFF52382A)],
            stops: const [0.6, 0.92, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: rad)),
      );
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0x2A000000);
      for (var q = hubR * 1.1; q < rad; q += h * 0.008) {
        canvas.drawCircle(c, q, ring);
      }
    }
    // La cinta pasa por abajo de un rollo al otro (origen: izquierdo, destino: derecho).
    final tape = Path()
      ..moveTo(lx, cy + rl)
      ..lineTo(rx, cy + rr);
    canvas.drawPath(
      tape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.012
        ..color = const Color(0xFF5A3F2D),
    );
    canvas.restore();

    _hub(canvas, Offset(lx, cy), hubR, st.aL, rl < hubR * 1.12);
    _hub(canvas, Offset(rx, cy), hubR, st.aR, rr < hubR * 1.12);

    // --- Ventanilla del contador entre los carretes ---
    final cw = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.508, h * 0.42), width: w * 0.224, height: h * 0.117),
      const Radius.circular(2),
    );
    canvas.drawRRect(cw, Paint()..color = const Color(0xFF8A6A4A));
    canvas.save();
    canvas.clipRRect(cw);
    final brownW = cw.width * (0.1 + 0.8 * (1 - overall)); // cinta que queda a la izquierda
    canvas.drawRect(
      Rect.fromLTWH(cw.left, cw.top, brownW, cw.height),
      Paint()..color = const Color(0xFF5B4030),
    );
    canvas.drawRect(
      Rect.fromLTRB(cw.left + brownW, cw.top, cw.right, cw.bottom),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4F4F2), Color(0xFFBDBDBA)],
        ).createShader(cw.outerRect),
    );
    canvas.restore();
    canvas.drawRRect(
      cw,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66000000),
    );
    // Marcas y números del contador.
    final tick = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 10; i++) {
      final x = cw.left + i * cw.width / 10;
      canvas.drawLine(Offset(x, h * 0.488), Offset(x, h * (i.isEven ? 0.512 : 0.502)), tick);
    }
    _text(canvas, '100', Offset(cw.left + cw.width * 0.05, h * 0.545), h * 0.032);
    _text(canvas, '50', Offset(cw.left + cw.width * 0.5, h * 0.545), h * 0.032);
    _text(canvas, '0', Offset(cw.right - cw.width * 0.02, h * 0.545), h * 0.032);

    // --- Parte baja: trapecio con rodillos blancos y cuadraditos ---
    final low = Path()
      ..moveTo(w * 0.204, h * 0.745)
      ..lineTo(w * 0.829, h * 0.745)
      ..lineTo(w * 0.865, h * 0.99)
      ..lineTo(w * 0.165, h * 0.99)
      ..close();
    canvas.drawPath(
      low,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1C1E), Color(0xFF0C0C0D)],
        ).createShader(Rect.fromLTWH(0, h * 0.74, w, h * 0.26)),
    );
    canvas.drawPath(
      low,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55FFFFFF),
    );
    final white = Paint()..color = const Color(0xFFEFEFEF);
    canvas.drawCircle(Offset(w * 0.27, h * 0.938), w * 0.025, white);
    canvas.drawCircle(Offset(w * 0.751, h * 0.938), w * 0.025, white);
    // Ranuras de la base.
    for (final x in [w * 0.44, w * 0.56]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, h * 0.965), width: w * 0.05, height: h * 0.022),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF050505),
      );
    }
    for (final x in [w * 0.37, w * 0.655]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, h * 0.914), width: w * 0.033, height: w * 0.033),
            const Radius.circular(2)),
        white,
      );
    }

    // --- Tornillos: 4 esquinas + 1 en el centro de la parte baja ---
    final sr = w * 0.018;
    for (final p in [
      Offset(w * 0.034, h * 0.05),
      Offset(w * 0.976, h * 0.05),
      Offset(w * 0.034, h * 0.96),
      Offset(w * 0.976, h * 0.96),
      Offset(w * 0.51, h * 0.837),
    ]) {
      canvas.save();
      canvas.translate(p.dx - sr, p.dy - sr);
      _ScrewPainter().paint(canvas, Size(sr * 2, sr * 2));
      canvas.restore();
    }

    // --- Reflejo suave en el plástico (sigue la inclinación del teléfono) y desgaste ---
    if (UiSettings.fx) {
      canvas.save();
      canvas.clipRRect(shell);
      final cx = w * (0.15 + 0.7 * st.light);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1 + 2 * st.light - 0.5, -1),
            end: Alignment(-1 + 2 * st.light + 0.5, 1),
            colors: const [Color(0x00FFFFFF), Color(0x26FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Rect.fromCenter(center: Offset(cx, h / 2), width: w * 0.5, height: h)),
      );
      if (st.wear > 0) {
        final rnd = math.Random(11);
        final sc = Paint()
          ..strokeWidth = 0.5
          ..color = Color.fromRGBO(255, 255, 255, 0.10 + 0.25 * st.wear);
        for (var i = 0; i < (14 * st.wear).round() + 3; i++) {
          final x0 = rnd.nextDouble() * w, y0 = rnd.nextDouble() * h;
          canvas.drawLine(Offset(x0, y0), Offset(x0 + (rnd.nextDouble() - 0.3) * w * 0.25, y0 + (rnd.nextDouble() - 0.5) * h * 0.06), sc);
        }
        final dust = Paint()..color = Color.fromRGBO(255, 255, 255, 0.12 * st.wear);
        for (var i = 0; i < 25 * st.wear; i++) {
          canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), 0.6, dust);
        }
      }
      canvas.restore();
    }
  }

  void _text(Canvas canvas, String t, Offset center, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(color: const Color(0x66FFFFFF), fontSize: size, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Carrete como en la referencia: aro blanco, centro negro y 6 dientes blancos
  /// que giran. La pestaña roja (punta de la cinta) aparece cuando el rollo casi se acabó.
  void _hub(Canvas canvas, Offset c, double r, double a, bool showClip) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF1F1EE));
    canvas.drawCircle(c, r * 0.9, Paint()..color = const Color(0xFF121214));
    final tooth = Paint()
      ..color = const Color(0xFFF1F1EE)
      ..strokeWidth = r * 0.2
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < 6; i++) {
      final ang = a + i * math.pi / 3;
      canvas.drawLine(c + Offset(math.cos(ang), math.sin(ang)) * r * 0.66,
          c + Offset(math.cos(ang), math.sin(ang)) * r * 0.9, tooth);
    }
    // Centro: cilindro oscuro con brillo y ranura en cruz.
    canvas.drawCircle(
      c,
      r * 0.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFF55565A), Color(0xFF0E0E10)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.5)),
    );
    final cross = Paint()
      ..color = const Color(0xFF8A8A8E)
      ..strokeWidth = 0.7;
    canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * 0.2,
        c - Offset(math.cos(a), math.sin(a)) * r * 0.2, cross);
    canvas.drawLine(c + Offset(-math.sin(a), math.cos(a)) * r * 0.2,
        c - Offset(-math.sin(a), math.cos(a)) * r * 0.2, cross);
    if (showClip) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a + math.pi * 0.62);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(0, -r * 0.8), width: r * 0.5, height: r * 0.18),
            Radius.circular(r * 0.07)),
        Paint()..color = const Color(0xFFC0394B),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CassettePainter o) => true;
}

