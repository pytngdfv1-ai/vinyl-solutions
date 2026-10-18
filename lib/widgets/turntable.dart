import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vinyl.dart';
import 'cover_art.dart';

/// Tornamesa: el disco gira y el brazo baja al reproducir.
class Turntable extends StatefulWidget {
  const Turntable({super.key, required this.vinyl, required this.playing});

  final Vinyl vinyl;
  final bool playing;

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
    duration: const Duration(milliseconds: 900),
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
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _arm]),
        builder: (context, _) => CustomPaint(
          painter: _TurntablePainter(
            hue: widget.vinyl.hue,
            spin: _spin.value,
            arm: Curves.easeInOut.transform(_arm.value),
          ),
        ),
      ),
    );
  }
}

class _TurntablePainter extends CustomPainter {
  _TurntablePainter({required this.hue, required this.spin, required this.arm});

  final double hue;
  final double spin;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
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

    final center = Offset(w * 0.40, h * 0.52);
    final r = math.min(w * 0.36, h * 0.46);

    canvas.drawCircle(center, r * 1.07, Paint()..color = const Color(0xFF2B2B2B));

    // Disco girando.
    canvas.save();
    canvas.translate(center.dx, center.dy);
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
    canvas.drawCircle(Offset.zero, r * 0.34, Paint()..color = hueColor(hue, 0.7, 0.5));
    canvas.drawCircle(Offset(r * 0.2, 0), r * 0.03, Paint()..color = Colors.white70);
    canvas.drawCircle(Offset.zero, r * 0.04, Paint()..color = const Color(0xFFD0D0D0));
    canvas.restore();

    // Brazo.
    final pivot = Offset(w * 0.9, h * 0.12);
    final target = Offset(center.dx + r * 0.55, center.dy);
    final len = (target - pivot).distance;
    final aPlay = math.atan2(pivot.dx - target.dx, target.dy - pivot.dy);
    final a = aPlay * (0.35 + 0.65 * arm);
    final tip = pivot + Offset(-math.sin(a), math.cos(a)) * len;

    final armPaint = Paint()
      ..color = const Color(0xFFEDEDED)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot + const Offset(2, 3), tip + const Offset(2, 3),
        Paint()..color = Colors.black26..strokeWidth = 5..strokeCap = StrokeCap.round);
    canvas.drawLine(pivot, tip, armPaint);
    canvas.drawCircle(pivot, 13, Paint()..color = const Color(0xFF6E6E6E));
    canvas.drawCircle(pivot, 7, Paint()..color = const Color(0xFFD8D8D8));
    canvas.drawCircle(tip, 5, Paint()..color = const Color(0xFF222222));
  }

  @override
  bool shouldRepaint(covariant _TurntablePainter old) => true;
}
