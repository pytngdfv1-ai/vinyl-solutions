import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vinyl.dart';

/// Reproductor de cassette en modo oscuro: carcasa de vidrio transparente,
/// etiqueta blanca con "Tema – Artista", carretes que giran y teclas.
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

class _CassetteDeckState extends State<CassetteDeck> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant CassetteDeck old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) _c.repeat();
    if (!widget.playing && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    final n = math.max(1, v.tracks.length);
    final overall = ((widget.trackIndex + widget.progress) / n).clamp(0.0, 1.0);
    final sideB = widget.trackIndex >= (n / 2).ceil() && n > 1;
    final tint = HSLColor.fromAHSL(1, v.hue % 360, 0.72, 0.55).toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = w * 0.62;
            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => CustomPaint(
                      size: Size(w, h),
                      painter: _CassettePainter(
                        spin: _c.value * 2 * math.pi,
                        overall: overall,
                        tint: tint,
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.07,
                    top: h * 0.075,
                    width: w * 0.86,
                    height: h * 0.27,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF111111),
                            fontWeight: FontWeight.w900,
                            fontSize: w * 0.062,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.085,
                    top: h * 0.375,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: w * 0.015),
                      color: const Color(0xFF222222),
                      child: Text(
                        sideB ? 'B' : 'A',
                        style: TextStyle(
                            color: tint, fontWeight: FontWeight.w900, fontSize: w * 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    right: w * 0.09,
                    top: h * 0.4,
                    child: Text(
                      '${v.tracks.length} TEMAS',
                      style: TextStyle(
                          color: const Color(0xFF222222),
                          fontWeight: FontWeight.w800,
                          fontSize: w * 0.032),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Key('REW', Icons.fast_rewind, widget.onPrev),
            _Key('PLAY', Icons.play_arrow, widget.onPlay, active: widget.playing),
            _Key('PAUSE', Icons.pause, widget.onPause),
            _Key('F.F', Icons.fast_forward, widget.onNext),
            _Key('EJECT', Icons.eject, widget.onEject),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.icon, this.onTap, {this.active = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFD8CDB6) : const Color(0xFFE9E0CC),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black87, offset: Offset(0, 3))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: const Color(0xFF3A3328)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 8, color: Color(0xFF3A3328), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CassettePainter extends CustomPainter {
  _CassettePainter({required this.spin, required this.overall, required this.tint});

  final double spin;
  final double overall;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.04));

    // Carcasa de vidrio ahumado.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x40FFFFFF), Color(0x14FFFFFF), Color(0x30FFFFFF)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x88FFFFFF),
    );

    // Etiqueta blanca.
    final label = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.07, h * 0.075, w * 0.86, h * 0.27), const Radius.circular(5));
    canvas.drawRRect(label, Paint()..color = const Color(0xFFF7F3EA));

    // Franja de color (toma el tono del disco), un poco transparente.
    final strip = Rect.fromLTWH(w * 0.07, h * 0.345, w * 0.86, h * 0.43);
    canvas.drawRect(strip, Paint()..color = tint.withOpacity(0.88));

    // Ventana oscura con los carretes.
    final win = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.56), width: w * 0.68, height: h * 0.26),
        Radius.circular(h * 0.13));
    canvas.drawRRect(win, Paint()..color = const Color(0xCC0B0B0B));

    final rMax = h * 0.115;
    final rMin = h * 0.065;
    final left = rMax - (rMax - rMin) * overall; // se vacía
    final right = rMin + (rMax - rMin) * overall; // se llena
    _reel(canvas, Offset(w * 0.3, h * 0.56), left, h * 0.062, spin);
    _reel(canvas, Offset(w * 0.7, h * 0.56), right, h * 0.062, spin);

    // Cinta visible entre carretes.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.4, h * 0.545, w * 0.2, h * 0.03),
      Paint()..color = const Color(0x99F0E6D0),
    );

    // Parte baja (trapecio) con orificios.
    final low = Path()
      ..moveTo(w * 0.14, h * 0.78)
      ..lineTo(w * 0.86, h * 0.78)
      ..lineTo(w * 0.93, h * 0.96)
      ..lineTo(w * 0.07, h * 0.96)
      ..close();
    canvas.drawPath(low, Paint()..color = const Color(0x55000000));
    final hole = Paint()..color = const Color(0xFFEDEDED);
    canvas.drawCircle(Offset(w * 0.2, h * 0.88), w * 0.022, hole);
    canvas.drawCircle(Offset(w * 0.8, h * 0.88), w * 0.022, hole);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.34, h * 0.86), width: w * 0.03, height: w * 0.03), hole);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.66, h * 0.86), width: w * 0.03, height: w * 0.03), hole);

    // Tornillos.
    final screw = Paint()..color = const Color(0xCCDDDDDD);
    for (final p in [
      Offset(w * 0.035, h * 0.05),
      Offset(w * 0.965, h * 0.05),
      Offset(w * 0.035, h * 0.95),
      Offset(w * 0.965, h * 0.95),
    ]) {
      canvas.drawCircle(p, w * 0.012, screw);
    }

    // Brillo de vidrio.
    final shine = Path()
      ..moveTo(w * 0.1, 0)
      ..lineTo(w * 0.3, 0)
      ..lineTo(w * 0.12, h)
      ..lineTo(0, h)
      ..close();
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawPath(shine, Paint()..color = const Color(0x12FFFFFF));
    canvas.restore();
  }

  void _reel(Canvas canvas, Offset c, double tape, double hub, double a) {
    canvas.drawCircle(c, tape, Paint()..color = const Color(0xFF3B2A1E)); // cinta enrollada
    canvas.drawCircle(c, hub, Paint()..color = const Color(0xFFEFEFEF));
    canvas.drawCircle(c, hub * 0.72, Paint()..color = const Color(0xFF151515));
    final tooth = Paint()
      ..color = const Color(0xFFEFEFEF)
      ..strokeWidth = hub * 0.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final ang = a + i * math.pi / 3;
      canvas.drawLine(
        c + Offset(math.cos(ang), math.sin(ang)) * hub * 0.35,
        c + Offset(math.cos(ang), math.sin(ang)) * hub * 0.68,
        tooth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CassettePainter o) =>
      o.spin != spin || o.overall != overall || o.tint != tint;
}
