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
  static const _rMax = 0.1245, _rMin = 0.101, _rMid = 0.1128;

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
                      left: cw * 0.09,
                      top: ch * 0.09,
                      width: cw * 0.84,
                      height: ch * 0.22,
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

/// Cassette dibujado con las proporciones de un cassette real (medidas tomadas de la
/// imagen de referencia): etiqueta, franja de color, ventana tipo píldora con los dos
/// carretes en sus extremos, ventanilla del contador y parte baja con rodillos.
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
