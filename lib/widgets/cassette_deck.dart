import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/vinyl.dart';

/// Casetero en modo oscuro: tapa de vidrio y un cassette realista
/// (carcasa transparente, etiqueta con renglones, carretes con dientes,
/// cinta que pasa de un carrete al otro, rodillos y tornillos) más las
/// teclas mecánicas REW / PLAY / PAUSE / F.F / EJECT.
class CassetteDeck extends StatefulWidget {
  const CassetteDeck({
    super.key,
    required this.vinyl,
    required this.playing,
    required this.label,
    this.progress = 0,
    this.trackIndex = 0,
    this.onPlay,
    this.onPause,
    this.onPrev,
    this.onNext,
    this.onEject,
  });

  final Vinyl vinyl;
  final bool playing;

  /// Texto de la etiqueta: "Tema – Artista".
  final String label;
  final double progress;
  final int trackIndex;
  final VoidCallback? onPlay, onPause, onPrev, onNext, onEject;

  @override
  State<CassetteDeck> createState() => _CassetteDeckState();
}

/// Estado de los carretes: ángulos (giro antihorario) y avance de la cinta.
class _ReelState extends ChangeNotifier {
  double aL = 0, aR = 0, overall = 0;
  Color tint = const Color(0xFFE8C14A);
  void tick() => notifyListeners();
}

class _CassetteDeckState extends State<CassetteDeck> with SingleTickerProviderStateMixin {
  final _st = _ReelState();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  // Radios (en alturas del cassette): la cinta avanza a velocidad constante,
  // así que el carrete con menos cinta gira más rápido.
  static const _rMax = 0.205, _rMin = 0.115, _rMid = 0.16;

  void _tick(Duration e) {
    final dt = (e - _last).inMicroseconds / 1e6;
    _last = e;
    if (dt <= 0 || dt > 0.5) return;
    final o = _st.overall;
    final rl = _rMax - (_rMax - _rMin) * o;
    final rr = _rMin + (_rMax - _rMin) * o;
    const w0 = 2.6; // rad/s con el rollo a medio radio
    // Antihorario (negativo en pantalla), los dos igual, como al reproducir.
    _st.aL -= w0 * _rMid / rl * dt;
    _st.aR -= w0 * _rMid / rr * dt;
    _st.tick();
  }

  void _sync() {
    if (widget.playing && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant CassetteDeck old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _st.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    final n = math.max(1, v.tracks.length);
    final overall = ((widget.trackIndex + widget.progress) / n).clamp(0.0, 1.0).toDouble();
    final sideB = n > 1 && widget.trackIndex >= (n / 2).ceil();
    final tint = HSLColor.fromAHSL(1, v.hue % 360, 0.62, 0.5).toColor();
    _st.overall = overall;
    _st.tint = tint;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cw = w * 0.84;
      final ch = cw / 1.57; // proporción real de un cassette
      return Container(
        padding: EdgeInsets.fromLTRB(w * 0.04, w * 0.035, w * 0.04, w * 0.04),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.04),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF34373A), Color(0xFF232527), Color(0xFF17181A)],
          ),
          border: Border.all(color: const Color(0xFF4A4D50), width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Franja superior: rejilla del parlante, LED y marca.
            SizedBox(
              height: w * 0.075,
              child: Row(
                children: [
                  _Screw(w * 0.03),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: CustomPaint(painter: _GrillePainter(), size: Size.infinite),
                  ),
                  SizedBox(width: w * 0.03),
                  Text('STEREO',
                      style: TextStyle(
                          color: const Color(0xFF8C9094),
                          fontSize: w * 0.026,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800)),
                  SizedBox(width: w * 0.025),
                  Container(
                    width: w * 0.024,
                    height: w * 0.024,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.playing ? const Color(0xFF42F56B) : const Color(0xFF2A3A2E),
                      boxShadow: widget.playing
                          ? const [BoxShadow(color: Color(0xAA42F56B), blurRadius: 8)]
                          : null,
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  _Screw(w * 0.03),
                ],
              ),
            ),
            SizedBox(height: w * 0.02),
            // Bahía del cassette con tapa de vidrio.
            Container(
              padding: EdgeInsets.all(w * 0.03),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(w * 0.025),
                color: const Color(0xFF070708),
                border: Border.all(color: const Color(0xFF55585B), width: 1.4),
                boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6, spreadRadius: -1)],
              ),
              child: SizedBox(
                width: cw,
                height: ch,
                child: Stack(
                  children: [
                    CustomPaint(size: Size(cw, ch), painter: _CassettePainter(_st)),
                    // Etiqueta escrita a mano.
                    Positioned(
                      left: cw * 0.11,
                      top: ch * 0.075,
                      width: cw * 0.78,
                      height: ch * 0.25,
                      child: Center(
                        child: Text(
                          widget.label,
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
                      left: cw * 0.115,
                      top: ch * 0.345,
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
                      top: ch * 0.355,
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
                ),
              ),
            ),
            SizedBox(height: w * 0.035),
            // Teclas mecánicas.
            Container(
              padding: EdgeInsets.fromLTRB(w * 0.02, w * 0.012, w * 0.02, w * 0.02),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3A3C3E)),
              ),
              child: Row(
                children: [
                  _Key('REW', Icons.fast_rewind, widget.onPrev),
                  _Key('PLAY', Icons.play_arrow, widget.onPlay, pressed: widget.playing),
                  _Key('PAUSE', Icons.pause, widget.onPause),
                  _Key('F.F', Icons.fast_forward, widget.onNext),
                  _Key('EJECT', Icons.eject, widget.onEject),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Screw extends StatelessWidget {
  const _Screw(this.d);
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

class _GrillePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xFF0A0A0B);
    final hi = Paint()..color = const Color(0x22FFFFFF);
    const step = 7.0;
    for (var y = step / 2; y < s.height; y += step) {
      for (var x = step / 2; x < s.width; x += step) {
        canvas.drawCircle(Offset(x, y + 0.6), 1.5, hi);
        canvas.drawCircle(Offset(x, y), 1.5, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.icon, this.onTap, {this.pressed = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 8.5,
                      letterSpacing: 0.6,
                      color: Color(0xFF9A9EA2),
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 46,
                margin: EdgeInsets.only(top: pressed ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: pressed
                        ? const [Color(0xFF3A3C3F), Color(0xFF2A2B2D)]
                        : const [Color(0xFF6A6D71), Color(0xFF3F4144)],
                  ),
                  border: Border.all(color: const Color(0xFF16171A)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black,
                        offset: Offset(0, pressed ? 1 : 4),
                        blurRadius: pressed ? 1 : 2),
                  ],
                ),
                child: Center(
                  child: Icon(icon,
                      size: 20,
                      color: pressed ? const Color(0xFF7CF59A) : const Color(0xFFD4D6D9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _CassettePainter extends CustomPainter {
  _CassettePainter(this.st) : super(repaint: st);

  final _ReelState st;
  double get overall => st.overall;
  Color get tint => st.tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shell = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.03));

    // --- Carcasa: plástico transparente ahumado ---
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

    // --- Etiqueta de papel con renglones y borde superior recortado ---
    final lab = Rect.fromLTWH(w * 0.075, h * 0.05, w * 0.85, h * 0.29);
    final labPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        lab,
        topLeft: Radius.circular(w * 0.03),
        topRight: Radius.circular(w * 0.03),
        bottomLeft: const Radius.circular(1),
        bottomRight: const Radius.circular(1),
      ));
    canvas.drawPath(
      labPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCFAF4), Color(0xFFE9E4D6)],
        ).createShader(lab),
    );
    final rule = Paint()
      ..color = const Color(0x553B63C4)
      ..strokeWidth = 0.7;
    for (var i = 1; i <= 3; i++) {
      final y = lab.top + lab.height * (0.28 + i * 0.2);
      canvas.drawLine(Offset(lab.left + 6, y), Offset(lab.right - 6, y), rule);
    }
    canvas.drawLine(
      Offset(lab.left + w * 0.08, lab.top),
      Offset(lab.left + w * 0.08, lab.bottom),
      Paint()
        ..color = const Color(0x55D8453C)
        ..strokeWidth = 0.8,
    );
    // Franja de color bajo la etiqueta.
    final band = Rect.fromLTWH(lab.left, lab.bottom, lab.width, h * 0.055);
    canvas.drawRect(band, Paint()..color = tint);
    canvas.drawRect(
        Rect.fromLTWH(band.left, band.top, band.width, band.height * 0.35),
        Paint()..color = const Color(0x33FFFFFF));

    // --- Ventana del carrete y cinta ---
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.11, h * 0.43, w * 0.78, h * 0.37),
      Radius.circular(h * 0.185),
    );
    canvas.drawRRect(win, Paint()..color = const Color(0xFF050506));
    canvas.save();
    canvas.clipRRect(win);

    final rHub = h * 0.092;
    final rMin = h * 0.115;
    final rMax = h * 0.205;
    final cy = h * 0.615;
    final lx = w * 0.30;
    final rx = w * 0.70;
    final leftTape = rMax - (rMax - rMin) * overall; // se vacía
    final rightTape = rMin + (rMax - rMin) * overall; // se llena

    for (final e in [(Offset(lx, cy), leftTape), (Offset(rx, cy), rightTape)]) {
      final c = e.$1;
      final r = e.$2;
      // Cinta enrollada marrón con brillo.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0xFF6B4A33), Color(0xFF3A2619), Color(0xFF52382A)],
            stops: const [0.5, 0.9, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      // Anillos concéntricos de la cinta enrollada.
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0x2A000000);
      for (var q = rHub * 1.12; q < r; q += h * 0.011) {
        canvas.drawCircle(c, q, ring);
      }
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x44FFFFFF),
      );
    }
    canvas.restore();

    // Carretes (aro blanco con 6 dientes hacia adentro).
    final nearEmptyL = leftTape < rMin + (rMax - rMin) * 0.25;
    final nearEmptyR = rightTape < rMin + (rMax - rMin) * 0.25;
    _hub(canvas, Offset(lx, cy), rHub, st.aL, nearEmptyL);
    _hub(canvas, Offset(rx, cy), rHub, st.aR, nearEmptyR);

    // Ventanilla central con marcas del contador.
    final mid = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, cy), width: w * 0.17, height: h * 0.15),
      const Radius.circular(2),
    );
    canvas.drawRRect(mid, Paint()..color = const Color(0xFF0C0C0D));
    canvas.drawRRect(
      mid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF),
    );
    // Cinta visible: franja clara cuyo ancho sigue el avance.
    canvas.drawRect(
      Rect.fromCenter(center: Offset(w * 0.5, cy), width: w * 0.15, height: h * 0.05),
      Paint()..color = const Color(0xFF6D4C37),
    );
    final tick = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 8; i++) {
      final x = w * 0.5 - w * 0.075 + i * (w * 0.15 / 8);
      canvas.drawLine(Offset(x, cy + h * 0.055), Offset(x, cy + h * (i.isEven ? 0.072 : 0.065)), tick);
    }
    canvas.drawCircle(
      Offset(w * 0.5 - w * 0.075 + overall * w * 0.15, cy + h * 0.015),
      h * 0.012,
      Paint()..color = const Color(0xFFFFE08A),
    );

    // --- Parte baja: trapecio con rodillos y cabezal ---
    final low = Path()
      ..moveTo(w * 0.17, h * 0.80)
      ..lineTo(w * 0.83, h * 0.80)
      ..lineTo(w * 0.90, h * 0.985)
      ..lineTo(w * 0.10, h * 0.985)
      ..close();
    canvas.drawPath(
      low,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF17181A), Color(0xFF0C0C0D)],
        ).createShader(Rect.fromLTWH(0, h * 0.8, w, h * 0.2)),
    );
    canvas.drawPath(
      low,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55FFFFFF),
    );
    final metal = Paint()..color = const Color(0xFFC5C8CC);
    final hole = Paint()..color = const Color(0xFF000000);
    // Rodillos guía (con cinta pasando).
    for (final x in [w * 0.17, w * 0.83]) {
      canvas.drawCircle(Offset(x, h * 0.92), h * 0.04, metal);
      canvas.drawCircle(Offset(x, h * 0.92), h * 0.018, hole);
    }
    _tape(canvas, w, h, Offset(lx, cy), leftTape, Offset(rx, cy), rightTape);
    // Orificios del cabezal y cabrestante.
    canvas.drawCircle(Offset(w * 0.5, h * 0.9), h * 0.036, hole);
    canvas.drawCircle(Offset(w * 0.5, h * 0.9), h * 0.036,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x66FFFFFF));
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.34, h * 0.885), width: w * 0.032, height: h * 0.05), hole);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.66, h * 0.885), width: w * 0.032, height: h * 0.05), hole);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.5, h * 0.82), width: w * 0.06, height: h * 0.03),
        Paint()..color = const Color(0xFF8A6A3C)); // almohadilla de presión

    // --- Tornillos (5, como el cassette real) ---
    for (final p in [
      Offset(w * 0.035, h * 0.055),
      Offset(w * 0.965, h * 0.055),
      Offset(w * 0.035, h * 0.945),
      Offset(w * 0.965, h * 0.945),
      Offset(w * 0.5, h * 0.36),
    ]) {
      canvas.save();
      canvas.translate(p.dx - w * 0.011, p.dy - w * 0.011);
      _ScrewPainter().paint(canvas, Size(w * 0.022, w * 0.022));
      canvas.restore();
    }
  }

  /// Punto de tangencia desde [p] al rollo (centro [c], radio [r]); del lado exterior.
  Offset _tangent(Offset c, double r, Offset p, bool left) {
    final d = (p - c).distance;
    if (d <= r + 0.5) return c + Offset(left ? -r : r, 0);
    final th = math.atan2(p.dy - c.dy, p.dx - c.dx);
    final al = math.acos(r / d);
    final a = c + Offset(math.cos(th + al), math.sin(th + al)) * r;
    final b = c + Offset(math.cos(th - al), math.sin(th - al)) * r;
    return left ? (a.dx < b.dx ? a : b) : (a.dx > b.dx ? a : b);
  }

  /// La cinta sale tangente al borde del rollo izquierdo (origen), da la vuelta a los
  /// rodillos de abajo, cruza el frente y entra tangente al borde del rollo derecho (destino).
  void _tape(Canvas canvas, double w, double h, Offset cl, double rl, Offset cr, double rr) {
    final g1 = Offset(w * 0.17, h * 0.92);
    final g2 = Offset(w * 0.83, h * 0.92);
    final k = h * 0.04;
    final p1 = g1 + Offset(-k, 0);
    final p2 = g2 + Offset(k, 0);
    final t1 = _tangent(cl, rl, p1, true);
    final t2 = _tangent(cr, rr, p2, false);
    final path = Path()
      ..moveTo(t1.dx, t1.dy)
      ..lineTo(p1.dx, p1.dy)
      ..arcTo(Rect.fromCircle(center: g1, radius: k), math.pi, -math.pi / 2, false)
      ..lineTo(g2.dx, g2.dy + k)
      ..arcTo(Rect.fromCircle(center: g2, radius: k), math.pi / 2, -math.pi / 2, false)
      ..lineTo(t2.dx, t2.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.014
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF5A3F2D),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.004
        ..color = const Color(0x55FFFFFF),
    );
  }

  /// Carrete: aro blanco translúcido con aletas, centro oscuro con 6 dientes y ranura
  /// en cruz. La pestaña roja (punta de la cinta) se ve cuando el rollo casi se acabó.
  void _hub(Canvas canvas, Offset c, double r, double a, bool showClip) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFEDEDEA));
    final fin = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 0.8;
    for (var i = 0; i < 12; i++) {
      final ang = a + i * math.pi / 6;
      canvas.drawLine(c + Offset(math.cos(ang), math.sin(ang)) * r * 0.72,
          c + Offset(math.cos(ang), math.sin(ang)) * r * 0.97, fin);
    }
    canvas.drawCircle(c, r * 0.62, Paint()..color = const Color(0xFF111112));
    final tooth = Paint()
      ..color = const Color(0xFFEDEDEA)
      ..strokeWidth = r * 0.18
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < 6; i++) {
      final ang = a + i * math.pi / 3;
      canvas.drawLine(c + Offset(math.cos(ang), math.sin(ang)) * r * 0.40,
          c + Offset(math.cos(ang), math.sin(ang)) * r * 0.64, tooth);
    }
    canvas.drawCircle(c, r * 0.22, Paint()..color = const Color(0xFF2A2A2C));
    final cross = Paint()
      ..color = const Color(0xFF777777)
      ..strokeWidth = 0.8;
    canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * 0.16,
        c - Offset(math.cos(a), math.sin(a)) * r * 0.16, cross);
    canvas.drawLine(c + Offset(-math.sin(a), math.cos(a)) * r * 0.16,
        c - Offset(-math.sin(a), math.cos(a)) * r * 0.16, cross);
    if (showClip) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a + math.pi * 0.62);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(0, -r * 0.84), width: r * 0.55, height: r * 0.2),
            Radius.circular(r * 0.08)),
        Paint()..color = const Color(0xFFC0394B),
      );
      canvas.restore();
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x66000000),
    );
  }

  @override
  bool shouldRepaint(covariant _CassettePainter o) => true;
}
