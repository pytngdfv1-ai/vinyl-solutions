import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vinyl.dart';
import 'cover_art.dart';

const double _deg = math.pi / 180;

Offset _rot(Offset v, double t) => Offset(
      v.dx * math.cos(t) - v.dy * math.sin(t),
      v.dx * math.sin(t) + v.dy * math.cos(t),
    );

/// Geometría compartida del tocadisco.
class _Geo {
  _Geo(Size s)
      : w = s.width,
        h = s.height;

  final double w;
  final double h;

  Offset get center => Offset(w * 0.39, h * 0.50);
  double get r => math.min(w * 0.34, h * 0.405);
  Offset get pivot => Offset(w * 0.9, h * 0.17);
  double get baseR => w * 0.075;

  double get _dist => (pivot - center).distance;
  double get _a0 => math.atan2(pivot.dx - center.dx, center.dy - pivot.dy);

  /// Largo del brazo: llega hasta cerca de la etiqueta (surco interior).
  double get armLen => _dist - r * 0.42;

  /// Ángulo del brazo para que la aguja quede a [rad] del centro del disco.
  double angleFor(double rad) {
    final c = ((armLen * armLen + _dist * _dist - rad * rad) / (2 * armLen * _dist))
        .clamp(-1.0, 1.0)
        .toDouble();
    return _a0 - math.acos(c);
  }

  Offset tip(double a) => pivot + Offset(-math.sin(a), math.cos(a)) * armLen;
}

/// Tocadisco plano y claro: el disco gira, la etiqueta lleva la portada y el
/// brazo avanza del borde exterior al centro a medida que avanza el tema.
class Turntable extends StatefulWidget {
  const Turntable({
    super.key,
    required this.vinyl,
    required this.playing,
    this.progress = 0,
  });

  final Vinyl vinyl;
  final bool playing;

  /// Avance del tema actual (0 = inicio, 1 = final).
  final double progress;

  @override
  State<Turntable> createState() => _TurntableState();
}

class _TurntableState extends State<Turntable> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _arm = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _sync(initial: true);
  }

  @override
  void didUpdateWidget(covariant Turntable old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _sync();
  }

  void _sync({bool initial = false}) {
    if (widget.playing) {
      if (initial) _arm.value = 1; // ya sonaba: el brazo aparece apoyado
      _arm.forward();
      _spin.repeat();
    } else {
      _arm.reverse();
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _arm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: LayoutBuilder(
        builder: (context, c) {
          final g = _Geo(Size(c.maxWidth, c.maxHeight));
          final lr = g.r * 0.33;
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, __) => CustomPaint(
                    painter: _DiscPainter(spin: _spin.value),
                  ),
                ),
              ),
              Positioned(
                left: g.center.dx - lr,
                top: g.center.dy - lr,
                width: lr * 2,
                height: lr * 2,
                child: RotationTransition(
                  turns: _spin,
                  child: _Label(vinyl: widget.vinyl),
                ),
              ),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: widget.progress),
                  duration: const Duration(milliseconds: 300),
                  builder: (_, p, __) => AnimatedBuilder(
                    animation: _arm,
                    builder: (_, __) => CustomPaint(
                      painter: _ArmPainter(
                        progress: p,
                        arm: Curves.easeInOut.transform(_arm.value),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Etiqueta redonda del disco con la portada del álbum.
class _Label extends StatelessWidget {
  const _Label({required this.vinyl});
  final Vinyl vinyl;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(color: hueColor(vinyl.hue, 0.7, 0.5));
    final url = vinyl.coverUrl;
    return ClipOval(
      child: url == null
          ? fallback
          : buildCoverImage(url, cacheWidth: 300, fallback: fallback),
    );
  }
}

/// Base, plato, disco con reflejos y control de velocidad.
class _DiscPainter extends CustomPainter {
  _DiscPainter({required this.spin});

  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geo(size);
    final w = size.width;
    final h = size.height;

    // Base clara.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.03)),
      Paint()..color = const Color(0xFFF4F4F2),
    );

    // Botón cuadrado (arriba a la izquierda).
    final bs = w * 0.07;
    final btn = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.035, h * 0.06, bs, bs),
      Radius.circular(bs * 0.22),
    );
    canvas.drawRRect(btn.shift(Offset(0, bs * 0.12)), Paint()..color = const Color(0xFFE0DEDE));
    canvas.drawRRect(btn, Paint()..color = const Color(0xFF9C9C9C));
    canvas.drawRRect(btn.deflate(bs * 0.13), Paint()..color = const Color(0xFFC8C8C8));

    // Control de velocidad (derecha).
    final sx = w * 0.935;
    final sw = w * 0.075;
    final slider = RRect.fromRectAndRadius(
      Rect.fromLTRB(sx - sw / 2, h * 0.56, sx + sw / 2, h * 0.97),
      Radius.circular(sw * 0.15),
    );
    canvas.drawRRect(slider.shift(Offset(0, sw * 0.12)), Paint()..color = const Color(0xFFE0DEDE));
    canvas.drawRRect(slider, Paint()..color = const Color(0xFF9C9C9C));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(sx - sw * 0.07, h * 0.60, sx + sw * 0.07, h * 0.93),
        Radius.circular(sw * 0.07),
      ),
      Paint()..color = const Color(0xFF1B1B1B),
    );
    final knob = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(sx, h * 0.745), width: sw * 0.92, height: sw * 0.78),
      Radius.circular(sw * 0.14),
    );
    canvas.drawRRect(knob.shift(Offset(0, sw * 0.1)), Paint()..color = const Color(0xFF6E6E6E));
    canvas.drawRRect(knob, Paint()..color = Colors.white);
    canvas.drawRRect(knob.deflate(sw * 0.17), Paint()..color = const Color(0xFFD6D6D6));

    // Plato.
    final r = g.r;
    canvas.drawCircle(
      g.center + Offset(0, r * 0.03),
      r * 1.1,
      Paint()
        ..color = Colors.black.withOpacity(0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(g.center, r * 1.1, Paint()..color = const Color(0xFF9E9E9E));

    // Disco (gira).
    canvas.save();
    canvas.translate(g.center.dx, g.center.dy);
    canvas.rotate(spin * 2 * math.pi);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF2A2A2C));

    // Reflejos en sectores (arriba y abajo), como el disco de referencia.
    final bandRect = Rect.fromCircle(center: Offset.zero, radius: r * 0.70);
    Paint band(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.50
      ..color = c;
    final mid = band(const Color(0xFF3B3B3E));
    final light = band(const Color(0xFF515154));
    for (final c in [-math.pi / 2, math.pi / 2]) {
      canvas.drawArc(bandRect, c - 44 * _deg, 88 * _deg, false, mid);
      canvas.drawArc(bandRect, c - 16 * _deg, 32 * _deg, false, light);
    }

    // Surcos.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.008)
      ..color = const Color(0xFF0E0E10);
    canvas.drawCircle(Offset.zero, r * 0.79, groove);
    canvas.drawCircle(Offset.zero, r * 0.63, groove);

    // Anillo negro alrededor de la etiqueta.
    canvas.drawCircle(Offset.zero, r * 0.46, Paint()..color = const Color(0xFF111113));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => old.spin != spin;
}

/// Eje central, base del brazo, brazo curvo con contrapeso y cápsula.
class _ArmPainter extends CustomPainter {
  _ArmPainter({required this.progress, required this.arm});

  final double progress;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geo(size);
    final r = g.r;
    final bR = g.baseR;

    // Eje blanco sobre la etiqueta.
    canvas.drawCircle(g.center + Offset(0, r * 0.014), r * 0.05, Paint()..color = const Color(0xFFB5413C));
    canvas.drawCircle(g.center, r * 0.05, Paint()..color = Colors.white);

    // Surco exterior (inicio del tema) -> surco interior (final del tema).
    final aPlay = g.angleFor(r * (0.93 - 0.51 * progress.clamp(0.0, 1.0)));
    final aRest = g.angleFor(r * 0.93) - 0.30; // brazo fuera del disco
    final a = aRest + (aPlay - aRest) * arm;

    final tip = g.tip(a);
    final dir = Offset(-math.sin(a), math.cos(a));
    final len = g.armLen;

    // Brazo: recto desde la base y con curva final hacia el disco.
    final d2 = _rot(dir, -0.10);
    final p1 = g.pivot + d2 * (len * 0.62);
    final ctrl = g.pivot + d2 * (len * 0.92);
    final shaft = Path()
      ..moveTo(g.pivot.dx, g.pivot.dy)
      ..lineTo(p1.dx, p1.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
    final shaftW = g.w * 0.024;
    final shadowOff = Offset(g.w * 0.016, g.w * 0.022);

    // Base del brazo.
    canvas.drawCircle(g.pivot, bR, Paint()..color = const Color(0xFF262626));

    // Sombra del brazo.
    canvas.drawPath(
      shaft.shift(shadowOff),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shaftW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withOpacity(0.12),
    );
    canvas.drawPath(
      shaft,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shaftW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF9B9B9B),
    );

    // Contrapeso (hacia atrás de la base).
    final sl = g.w * 0.085;
    final rear = g.pivot - dir * sl;
    canvas.drawLine(
      g.pivot,
      rear,
      Paint()
        ..color = const Color(0xFFBDBDBD)
        ..strokeWidth = bR * 0.4,
    );
    canvas.drawLine(
      g.pivot - dir * (sl * 0.5),
      rear,
      Paint()
        ..color = const Color(0xFF4D4D50)
        ..strokeWidth = bR * 0.66,
    );

    // Anillo claro, palanca y punto de la base.
    canvas.drawCircle(g.pivot, bR * 0.52, Paint()..color = const Color(0xFFC9C9C9));
    canvas.drawLine(
      g.pivot + Offset(-0.5, -0.62) * bR,
      g.pivot + Offset(0.02, 0.1) * bR,
      Paint()
        ..color = Colors.white
        ..strokeWidth = bR * 0.22
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(g.pivot + Offset(0.74, 0.56) * bR, bR * 0.1, Paint()..color = const Color(0xFFD8D8D8));

    // Cápsula con la aguja.
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(a + 0.30);
    final hl = g.w * 0.085;
    final hw = g.w * 0.034;
    final shell = RRect.fromRectAndRadius(
      Rect.fromLTWH(-hw / 2, -hl, hw, hl * 0.95),
      Radius.circular(hw * 0.3),
    );
    canvas.drawRRect(
      shell.shift(Offset(g.w * 0.012, g.w * 0.016)),
      Paint()..color = Colors.black.withOpacity(0.12),
    );
    canvas.drawRRect(shell, Paint()..color = const Color(0xFF4A4A4C));
    canvas.drawRect(
      Rect.fromLTWH(-hw * 0.12, -hl * 0.05, hw * 0.24, hl * 0.24),
      Paint()..color = const Color(0xFFE6E6E6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArmPainter old) =>
      old.progress != progress || old.arm != arm;
}
