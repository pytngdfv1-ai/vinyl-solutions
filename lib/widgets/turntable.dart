import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/vinyl.dart';
import 'vinyl_disc.dart';


Offset _rot(Offset v, double t) => Offset(
      v.dx * math.cos(t) - v.dy * math.sin(t),
      v.dx * math.sin(t) + v.dy * math.cos(t),
    );

/// Geometría compartida del tocadisco.
class _Geo {
  _Geo(Size s, {this.scale = 1.0})
      : w = s.width,
        h = s.height;

  final double w;
  final double h;

  /// Tamaño del disco respecto al plato: 1 = LP, 0.8 = 10", 0.64 = single de 7".
  final double scale;
  double get dr => r * scale;
  double get labelRatio => scale >= 1 ? 0.33 : (scale > 0.7 ? 0.40 : 0.48);

  Offset get center => Offset(w * 0.39, h * 0.50);
  double get r => math.min(w * 0.34, h * 0.405);
  Offset get pivot => Offset(w * 0.9, h * 0.17);
  double get baseR => w * 0.075;

  double get _dist => (pivot - center).distance;
  double get _a0 => math.atan2(pivot.dx - center.dx, center.dy - pivot.dy);

  /// Largo del brazo: llega hasta cerca de la etiqueta (surco interior).
  double get armLen => _dist - r * 0.25;

  /// Ángulo del brazo para que la aguja quede a [rad] del centro del disco.
  double angleFor(double rad) {
    final c = ((armLen * armLen + _dist * _dist - rad * rad) / (2 * armLen * _dist))
        .clamp(-1.0, 1.0)
        .toDouble();
    return _a0 - math.acos(c);
  }

  Offset tip(double a) => pivot + Offset(-math.sin(a), math.cos(a)) * armLen;
}

int _bands(int tracks) => math.min(math.max(1, tracks), 31);

/// Tocadisco plano y claro: el disco gira, la etiqueta lleva la portada y el
/// brazo avanza del borde exterior al centro a medida que avanza el tema.
class Turntable extends StatefulWidget {
  const Turntable({
    super.key,
    required this.vinyl,
    required this.playing,
    this.progress = 0,
    this.trackIndex = 0,
    this.trackCount = 1,
    this.single = false,
    this.showDisc = true,
  });

  final Vinyl vinyl;
  final bool playing;

  /// Avance del tema actual (0 = inicio, 1 = final).
  final double progress;

  /// Tema actual, cantidad de temas (una banda de surcos por tema) y si es un tema suelto.
  final int trackIndex;
  final int trackCount;
  final bool single;

  /// false mientras el disco viaja en la animación de apertura (el plato queda vacío).
  final bool showDisc;

  /// Centro y radio del disco sobre el plato, para la animación de apertura.
  static (Offset, double) discGeometry(Size s, double scale) {
    final g = _Geo(s, scale: scale);
    return (g.center, g.dr);
  }

  static double labelRatioFor(double scale) => scale >= 1 ? 0.33 : (scale > 0.7 ? 0.40 : 0.48);

  static double scaleFor(bool single, int trackCount) => single ? 0.64 : (trackCount <= 4 ? 0.8 : 1.0);

  double get scale => scaleFor(single, trackCount);

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

  // Giro extra por el dedo / inercia (se suma al giro continuo del motor).
  late final AnimationController _fling = AnimationController.unbounded(vsync: this)
    ..addListener(() => _extra = _fling.value);
  double _extra = 0;
  Offset? _lastLocal;
  Offset _discCenter = Offset.zero;
  bool _dragging = false;

  static const double _motorRadPerSec = 2 * math.pi / 1.8;

  double _angleOf(Offset p) => math.atan2(p.dy - _discCenter.dy, p.dx - _discCenter.dx);

  void _dragStart(DragStartDetails d) {
    _fling.stop();
    _dragging = true;
    _lastLocal = d.localPosition;
    if (_spin.isAnimating) _spin.stop(canceled: false); // el dedo manda mientras arrastras
  }

  void _dragUpdate(DragUpdateDetails d) {
    final prev = _lastLocal;
    if (prev == null) return;
    var da = _angleOf(d.localPosition) - _angleOf(prev);
    if (da > math.pi) da -= 2 * math.pi;
    if (da < -math.pi) da += 2 * math.pi;
    setState(() {
      _extra += da;
      _fling.value = _extra;
    });
    _lastLocal = d.localPosition;
  }

  void _dragEnd(DragEndDetails d) {
    _dragging = false;
    final p = _lastLocal ?? _discCenter;
    final r = p - _discCenter;
    final v = d.velocity.pixelsPerSecond;
    final r2 = math.max(1.0, r.dx * r.dx + r.dy * r.dy);
    final omega = (r.dx * v.dy - r.dy * v.dx) / r2; // rad/s (tangencial / radio)
    _lastLocal = null;
    _coast(omega.clamp(-40.0, 40.0).toDouble(), resumeMotor: widget.playing);
  }

  /// Inercia con rozamiento; al acabar, si sigue sonando, vuelve el motor.
  void _coast(double omega, {required bool resumeMotor}) {
    _fling.value = _extra;
    if (omega.abs() < 0.2) {
      if (resumeMotor) _spin.repeat();
      return;
    }
    _fling
        .animateWith(FrictionSimulation(0.12, _extra, omega, tolerance: const Tolerance(distance: 0.01, velocity: 0.05)))
        .whenComplete(() {
      if (mounted && !_dragging && widget.playing && !_spin.isAnimating) _spin.repeat();
    });
  }

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
      _arm.forward().whenComplete(() {
        if (!initial && mounted) HapticFeedback.mediumImpact(); // la aguja toca el surco
      });
      if (!_dragging) _spin.repeat();
    } else {
      _arm.reverse();
      if (_spin.isAnimating) {
        _spin.stop(canceled: false);
        _coast(_motorRadPerSec, resumeMotor: false); // el plato sigue girando por inercia y se detiene
      }
    }
  }

  @override
  void dispose() {
    _fling.dispose();
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
          final g = _Geo(Size(c.maxWidth, c.maxHeight), scale: widget.scale);
          _discCenter = g.center;
          return Listener(
            // Tocar el disco lo detiene (sin competir con el toque de play/pausa).
            onPointerDown: (e) {
              if ((e.localPosition - g.center).distance <= g.dr && _fling.isAnimating) _fling.stop();
            },
            child: GestureDetector(
            onPanStart: _dragStart,
            onPanUpdate: _dragUpdate,
            onPanEnd: _dragEnd,
            child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _DiscPainter(scale: widget.scale)),
              ),
              if (widget.showDisc)
                Positioned(
                  left: g.center.dx - g.dr,
                  top: g.center.dy - g.dr,
                  width: g.dr * 2,
                  height: g.dr * 2,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_spin, _fling]),
                    builder: (_, __) => VinylDisc(
                      vinyl: widget.vinyl,
                      diameter: g.dr * 2,
                      spin: _spin.value * 2 * math.pi + _extra,
                      labelRatio: g.labelRatio,
                      tracks: widget.trackCount,
                    ),
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
                        scale: widget.scale,
                        trackIndex: widget.trackIndex,
                        trackCount: widget.trackCount,
                        progress: p,
                        arm: Curves.easeInOut.transform(_arm.value),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
          );
        },
      ),
    );
  }
}

/// Base, plato, disco con reflejos y control de velocidad.
class _DiscPainter extends CustomPainter {
  _DiscPainter({required this.scale});

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geo(size, scale: scale);
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
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => old.scale != scale;
}

/// Eje central, base del brazo, brazo curvo con contrapeso y cápsula.
class _ArmPainter extends CustomPainter {
  _ArmPainter({
    required this.progress,
    required this.arm,
    required this.scale,
    required this.trackIndex,
    required this.trackCount,
  });

  final double progress;
  final double arm;
  final double scale;
  final int trackIndex;
  final int trackCount;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geo(size, scale: scale);
    final r = g.r;
    final dr = g.dr;
    final bR = g.baseR;

    // Eje blanco sobre la etiqueta.
    canvas.drawCircle(g.center + Offset(0, r * 0.014), r * 0.05, Paint()..color = const Color(0xFFB5413C));
    canvas.drawCircle(g.center, r * 0.05, Paint()..color = Colors.white);

    // La aguja recorre la banda del tema actual: de su borde exterior al interior.
    final ro = dr * 0.93;
    final ri = dr * (g.labelRatio + 0.10);
    final bands = _bands(trackCount);
    final idx = trackCount > bands
        ? (trackIndex * bands ~/ trackCount).clamp(0, bands - 1)
        : trackIndex.clamp(0, bands - 1);
    final width = (ro - ri) / bands;
    final radius = ro - (idx + progress.clamp(0.0, 1.0)) * width;
    final aPlay = g.angleFor(radius);
    final aRest = g.angleFor(ro) - 0.30; // brazo fuera del disco
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
      old.progress != progress ||
      old.arm != arm ||
      old.scale != scale ||
      old.trackIndex != trackIndex ||
      old.trackCount != trackCount;
}
