import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cover_image.dart';
import '../models/vinyl.dart';
import 'cover_art.dart';

/// Geometría compartida del tocadisco.
class _Geo {
  _Geo(Size s)
      : w = s.width,
        h = s.height;

  final double w;
  final double h;

  Offset get center => Offset(w * 0.40, h * 0.52);
  double get r => math.min(w * 0.36, h * 0.46);
  Offset get pivot => Offset(w * 0.9, h * 0.12);

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

/// Tocadisco: el disco gira, la etiqueta lleva la portada y el brazo avanza
/// del borde exterior al centro a medida que avanza el tema.
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
    _sync();
  }

  @override
  void didUpdateWidget(covariant Turntable old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _sync();
  }

  void _sync() {
    if (widget.playing) {
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
          final lr = g.r * 0.34;
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
          : CoverImage(url: url, fallback: fallback, cacheWidth: 300),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({required this.spin});

  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geo(size);
    final body = Offset.zero & size;

    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(14)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC9C9C9), Color(0xFF8A8A8A)],
        ).createShader(body),
    );

    final r = g.r;
    canvas.drawCircle(g.center, r * 1.07, Paint()..color = const Color(0xFF2B2B2B));

    canvas.save();
    canvas.translate(g.center.dx, g.center.dy);
    canvas.rotate(spin * 2 * math.pi);
    final disc = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF101010));
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.14),
            Colors.transparent,
            Colors.white.withOpacity(0.14),
            Colors.transparent,
          ],
          stops: const [0, 0.12, 0.5, 0.62, 1],
        ).createShader(disc),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withOpacity(0.07);
    for (var k = 0; k < 7; k++) {
      canvas.drawCircle(Offset.zero, r * (0.4 + 0.085 * k), groove);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => old.spin != spin;
}

class _ArmPainter extends CustomPainter {
  _ArmPainter({required this.progress, required this.arm});

  final double progress;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geo(size);
    final r = g.r;

    // Agujero central sobre la etiqueta.
    canvas.drawCircle(g.center, r * 0.035, Paint()..color = const Color(0xFFD0D0D0));

    // Surco exterior (inicio del tema) -> surco interior (final del tema).
    final aPlay = g.angleFor(r * (0.93 - 0.51 * progress.clamp(0.0, 1.0)));
    final aRest = g.angleFor(r * 0.93) - 0.30; // brazo fuera del disco
    final a = aRest + (aPlay - aRest) * arm;

    final tip = g.tip(a);
    final dir = Offset(-math.sin(a), math.cos(a));

    final line = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      g.pivot + const Offset(2, 3),
      tip + const Offset(2, 3),
      line..color = Colors.black26,
    );
    canvas.drawLine(g.pivot, tip, line..color = const Color(0xFFEDEDED));
    canvas.drawLine(
      tip - dir * 12,
      tip,
      Paint()
        ..color = const Color(0xFF2A2A2A)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(g.pivot, 13, Paint()..color = const Color(0xFF6E6E6E));
    canvas.drawCircle(g.pivot, 7, Paint()..color = const Color(0xFFD8D8D8));
  }

  @override
  bool shouldRepaint(covariant _ArmPainter old) =>
      old.progress != progress || old.arm != arm;
}
