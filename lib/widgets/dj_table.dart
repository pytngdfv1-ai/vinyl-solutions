import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/dj_feed.dart';
import '../data/playlists.dart';
import 'cover_art.dart';

/// Mesa de DJ (dos platos y un mixer central) dibujada por código.
/// El plato del tema que suena gira y su brazo baja al disco; el otro plato
/// tiene cargado el tema siguiente, quieto y con el brazo en reposo.
class DjTable extends StatefulWidget {
  const DjTable({super.key, required this.feed});

  final DjFeed feed;

  @override
  State<DjTable> createState() => _DjTableState();
}

// Espacio de diseño (medidas tomadas de la imagen de referencia).
const double _dw = 1075, _dh = 330;
const double _deckW = 427, _mixX = 432, _mixW = 215, _deck2X = 650;
const Offset _center = Offset(164, 165);
const Offset _pivot = Offset(362, 70);
const double _armLen = 200;
const double _restAngle = 1.745; // ≈100°

double _playAngle(double prog) {
  final r = 128 - 72 * prog;
  final d = _center - _pivot;
  final dist = d.distance;
  final base = math.atan2(d.dy, d.dx);
  final c = ((_armLen * _armLen + dist * dist - r * r) / (2 * _armLen * dist)).clamp(-1.0, 1.0).toDouble();
  return base - math.acos(c);
}

class _DjTableState extends State<DjTable> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  final _spin = [0.0, 0.0];
  final _speed = [0.0, 0.0];
  final _arm = [_restAngle, _restAngle];
  double _xf = 0;
  double _clock = 0;
  Duration _last = Duration.zero;
  DjFeed get feed => widget.feed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  void _onTick(Duration t) {
    final dt = math.min(0.05, (t - _last).inMicroseconds / 1e6);
    _last = t;
    var anyPlaying = false;
    for (var d = 0; d < 2; d++) {
      final target = feed.spinning(d) ? 1.0 : 0.0;
      if (target > 0) anyPlaying = true;
      _speed[d] += (target - _speed[d]) * math.min(1.0, dt * 3);
      _spin[d] -= _speed[d] * dt * 3.2 * feed.rate(d); // antihorario, como el disco
      final armTarget = feed.armDown(d) ? _playAngle(feed.progress(d)) : _restAngle;
      _arm[d] += (armTarget - _arm[d]) * math.min(1.0, dt * 4);
    }
    _xf += (feed.xf - _xf) * math.min(1.0, dt * (feed.interactive ? 14 : 3));
    if (anyPlaying) _clock += dt;
    _tick.value++;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: feed,
      builder: (_, __) {
        final entries = [feed.entry(0), feed.entry(1)];
        return LayoutBuilder(
          builder: (_, c) {
            final s = math.min(c.maxWidth / _dw, c.maxHeight / _dh);
            return Center(
              child: SizedBox(
                width: _dw * s,
                height: _dh * s,
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _TablePainter(this, s))),
                    for (var d = 0; d < 2; d++) ..._deck(d, s, entries[d]),
                    if (feed.interactive) ..._touch(s),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Zonas táctiles: start/stop, pitch de cada plato y crossfader.
  List<Widget> _touch(double s) {
    final out = <Widget>[];
    for (var d = 0; d < 2; d++) {
      final x0 = d == 0 ? 0.0 : _deck2X;
      out.add(Positioned(
        left: (x0 + 346) * s,
        top: 250 * s,
        width: 36 * s,
        height: 36 * s,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => feed.onPlatter(d)),
      ));
      void pitchAt(Offset local) => feed.onPitch(d, ((227 - (170 + local.dy / s)) / 45).clamp(-1.0, 1.0).toDouble());
      out.add(Positioned(
        left: (x0 + 372) * s,
        top: 170 * s,
        width: 40 * s,
        height: 114 * s,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (t) => pitchAt(t.localPosition),
          onVerticalDragUpdate: (t) => pitchAt(t.localPosition),
          onDoubleTap: () => feed.onPitch(d, 0),
        ),
      ));
    }
    void xfAt(Offset local) => feed.onXf(((30 + local.dx / s) - 45) / 135);
    out.add(Positioned(
      left: (_mixX + 30) * s,
      top: 276 * s,
      width: 165 * s,
      height: 36 * s,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (t) => xfAt(t.localPosition),
        onHorizontalDragUpdate: (t) => xfAt(t.localPosition),
      ),
    ));
    return out;
  }

  List<Widget> _deck(int d, double s, PlEntry? e) {
    final x0 = d == 0 ? 0.0 : _deck2X;
    const R = 155.0;
    final label = e == null
        ? null
        : SizedBox(
            width: 84 * s,
            height: 84 * s,
            child: ClipOval(child: CoverArt(vinyl: e.asVinyl(), radius: 0)),
          );
    return [
      Positioned(
        left: (x0 + _center.dx - R) * s,
        top: (_center.dy - R) * s,
        width: 2 * R * s,
        height: 2 * R * s,
        child: GestureDetector(
          onTap: feed.interactive ? () => feed.onPlatter(d) : null,
          child: AnimatedBuilder(
          animation: _tick,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CustomPaint(painter: _PlatterPainter(e != null))),
              if (label != null) label,
              Container(
                width: 8 * s,
                height: 8 * s,
                decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle),
              ),
            ],
          ),
          builder: (_, child) => Transform.rotate(angle: _spin[d], child: child),
        ),
        ),
      ),
      Positioned(
        left: x0 * s,
        top: 0,
        width: _deckW * s,
        height: _dh * s,
        child: IgnorePointer(child: CustomPaint(painter: _ArmPainter(this, d, s))),
      ),
    ];
  }
}

const _panel = Color(0xFF050505);
const _edge = Color(0xFF2E2E2E);

class _TablePainter extends CustomPainter {
  _TablePainter(this.st, this.s) : super(repaint: st._tick);
  final _DjTableState st;
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(s);
    _deckPanel(canvas, 0);
    _deckPanel(canvas, _deck2X);
    _mixer(canvas);
  }

  void _panelBox(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = _panel);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _edge,
    );
  }

  void _deckPanel(Canvas canvas, double x0) {
    canvas.save();
    canvas.translate(x0, 0);
    _panelBox(canvas, const Rect.fromLTWH(0, 0, _deckW, _dh));
    final lug = Paint()..color = const Color(0xFF3A3A3A);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(67, -7, 30, 7), const Radius.circular(2)), lug);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(337, -7, 25, 7), const Radius.circular(2)), lug);
    // Adaptador de 45 (arriba a la izquierda).
    canvas.drawCircle(const Offset(32, 35), 17, Paint()..color = const Color(0xFFB9B9B9));
    canvas.drawCircle(const Offset(32, 35), 12, Paint()..color = const Color(0xFFF0F0F0));
    // Perilla inferior izquierda.
    canvas.drawCircle(const Offset(17, 265), 14, Paint()..color = const Color(0xFF3C3C3C));
    canvas.drawCircle(const Offset(17, 265), 10, Paint()..color = const Color(0xFF111111));
    // Etiqueta blanca y botoncitos.
    canvas.drawRect(const Rect.fromLTWH(20, 292, 30, 26), Paint()..color = const Color(0xFFD8D8D8));
    canvas.drawRect(const Rect.fromLTWH(57, 311, 21, 7), Paint()..color = const Color(0xFFCFCFCF));
    canvas.drawRect(const Rect.fromLTWH(82, 311, 18, 7), Paint()..color = const Color(0xFFCFCFCF));
    // Start / stop.
    canvas.drawCircle(const Offset(364, 267), 9, Paint()..color = const Color(0xFFE8E8E8));
    // Pitch: carril con marcas y cursor rojo.
    canvas.drawRect(const Rect.fromLTWH(380, 178, 22, 98), Paint()..color = const Color(0xFF151515));
    final tick = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 0.8;
    for (var i = 0; i <= 16; i++) {
      final y = 182 + i * 5.6;
      canvas.drawLine(Offset(383, y), Offset(i % 4 == 0 ? 392 : 388, y), tick);
    }
    final py = 227 - st.feed.pitch(x0 == 0 ? 0 : 1) * 45;
    canvas.drawRect(Rect.fromLTWH(382, py - 1.5, 18, 3), Paint()..color = const Color(0xFFE53935));
    canvas.restore();
  }

  void _mixer(Canvas canvas) {
    canvas.save();
    canvas.translate(_mixX, 0);
    _panelBox(canvas, const Rect.fromLTWH(0, 0, _mixW, _dh));
    // 12 pads redondos (el que "late" sigue el compás mientras suena).
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFBDBDBD);
    final lit = (st._clock * 2).floor() % 12;
    var n = 0;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 4; c++) {
        final o = Offset(48 + c * 41.7, 50 + r * 37.5);
        if (st._speed[0] + st._speed[1] > 0.2 && n == lit) {
          canvas.drawCircle(o, 14, Paint()..color = const Color(0x33FFFFFF));
        }
        canvas.drawCircle(o, 15, ring);
        n++;
      }
    }
    // 5 faders con sus marcas.
    const xs = [35.0, 73.0, 109.0, 150.0, 190.0];
    const pos = [0.3, 0.55, 0.4, 0.65, 0.35];
    final dash = Paint()
      ..color = const Color(0xDDFFFFFF)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      final x = xs[i];
      for (var y = 152.0; y < 270; y += 6.5) {
        canvas.drawLine(Offset(x - 11, y), Offset(x - 4, y), dash);
        canvas.drawLine(Offset(x + 4, y), Offset(x + 11, y), dash);
      }
      canvas.drawRect(Rect.fromLTWH(x - 1.5, 150, 3, 122), Paint()..color = const Color(0xFF111111));
      final ky = 150 + 110 * pos[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 7, ky, 14, 9), const Radius.circular(1.5)),
        Paint()..color = const Color(0xFF8E8E8E),
      );
    }
    // Crossfader: la perilla va al plato que suena.
    canvas.drawRect(const Rect.fromLTWH(45, 293, 135, 3), Paint()..color = const Color(0xFF8A8A8A));
    final kx = 45 + 135 * st._xf - 11;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(kx, 287, 22, 15), const Radius.circular(2)),
      Paint()..color = const Color(0xFFE0E0E0),
    );
    // Franja tipo código de barras.
    final bar = Paint()..color = const Color(0xDDFFFFFF);
    for (var i = 0; i < 44; i++) {
      canvas.drawRect(Rect.fromLTWH(48 + i * 3.0, 308, i % 3 == 0 ? 1.0 : 1.8, 16), bar);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TablePainter o) => true;
}

class _PlatterPainter extends CustomPainter {
  _PlatterPainter(this.record);
  final bool record;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final k = size.width / 310;
    // Anillo estroboscópico de puntitos.
    final dot = Paint()..color = const Color(0xFFCFCFCF);
    for (var i = 0; i < 120; i++) {
      final a = i * 2 * math.pi / 120;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * 151 * k, 1.5 * k, dot);
    }
    canvas.drawCircle(c, 148 * k, Paint()..color = const Color(0xFF1C1C1C));
    canvas.drawCircle(c, 144 * k, Paint()..color = const Color(0xFF0C0C0C));
    if (record) {
      canvas.drawCircle(c, 130 * k, Paint()..color = const Color(0xFF040404));
      final g = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0x14FFFFFF);
      for (var r = 52.0; r < 128; r += 7) {
        canvas.drawCircle(c, r * k, g);
      }
    }
    canvas.drawCircle(
      c,
      134 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * k
        ..color = const Color(0xFFF2F2F2),
    );
  }

  @override
  bool shouldRepaint(covariant _PlatterPainter o) => o.record != record;
}

class _ArmPainter extends CustomPainter {
  _ArmPainter(this.st, this.d, this.s) : super(repaint: st._tick);
  final _DjTableState st;
  final int d;
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(s);
    final a = st._arm[d];
    final dir = Offset(math.cos(a), math.sin(a));
    final perp = Offset(-dir.dy, dir.dx);
    // Contrapeso (detrás del pivote).
    final cw0 = _pivot - dir * 14;
    final cw1 = _pivot - dir * 52;
    canvas.drawLine(
      cw0,
      cw1,
      Paint()
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8C9094),
    );
    canvas.drawLine(
      cw0 - perp * 4,
      cw1 - perp * 4,
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD9DCDF),
    );
    // Base del pivote.
    canvas.drawCircle(_pivot, 34, Paint()..color = const Color(0xFF2A2A2A));
    canvas.drawCircle(_pivot, 28, Paint()..color = const Color(0xFF6E7378));
    canvas.drawCircle(_pivot, 20, Paint()..color = const Color(0xFFC9CDD1));
    canvas.drawCircle(_pivot, 8, Paint()..color = const Color(0xFF50555A));
    // Tubo del brazo con un leve arco.
    final tip = _pivot + dir * _armLen;
    final mid = _pivot + dir * (_armLen / 2) + perp * 9;
    final tube = Path()
      ..moveTo(_pivot.dx, _pivot.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
    canvas.drawPath(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9EA3A8),
    );
    canvas.drawPath(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE9ECEF),
    );
    // Cabezal (headshell) con la aguja.
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(a + 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -9, 30, 18), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1B1B1B),
    );
    canvas.drawRect(const Rect.fromLTWH(-6, -9, 30, 3), Paint()..color = const Color(0xFFB0B4B8));
    canvas.drawRect(const Rect.fromLTWH(14, -4, 8, 8), Paint()..color = const Color(0xFFE8E8E8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArmPainter o) => true;
}
