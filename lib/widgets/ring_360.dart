import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Anillo 360°: tú estás en el centro y las tarjetas giran a tu alrededor. Arrastra de lado para girar,
/// toca la del frente para abrirla o cualquier otra para traerla al frente.
class Ring360 extends StatefulWidget {
  const Ring360({
    super.key,
    required this.count,
    required this.itemBuilder,
    required this.onFront,
    this.onLongPressFront,
    this.caption,
    this.aspect = 1.0,
    this.initial = 0,
  });

  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ValueChanged<int> onFront;
  final ValueChanged<int>? onLongPressFront;

  /// Título y subtítulo del elemento que está al frente.
  final (String, String?) Function(int index)? caption;

  /// Ancho / alto de cada tarjeta.
  final double aspect;
  final int initial;

  @override
  State<Ring360> createState() => _Ring360State();
}

class _Placed {
  _Placed(this.i, this.d, this.th);
  final int i;
  final double d;
  final double th;
}

class _Ring360State extends State<Ring360> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late double _pos = widget.initial.toDouble();
  double _from = 0;
  double _to = 0;
  int _last = -1;

  bool get _wrap => widget.count >= 6;
  double get _step => _wrap ? 2 * math.pi / widget.count : 0.9;
  double get _max => math.max(0, widget.count - 1).toDouble();

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
      ..addListener(() {
        _setPos(_from + (_to - _from) * Curves.easeOutCubic.transform(_ctl.value));
      });
    _pos = _wrap ? _pos : _pos.clamp(0.0, _max).toDouble();
  }

  @override
  void didUpdateWidget(covariant Ring360 old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) {
      _ctl.stop();
      _pos = _wrap ? _pos : _pos.clamp(0.0, _max).toDouble();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  int _index(double p) {
    final n = widget.count;
    if (n == 0) return 0;
    final r = p.round();
    return _wrap ? ((r % n) + n) % n : r.clamp(0, n - 1);
  }

  void _setPos(double v) {
    final p = _wrap ? v : v.clamp(0.0, _max).toDouble();
    final idx = _index(p);
    if (idx != _last) {
      _last = idx;
      HapticFeedback.selectionClick();
    }
    setState(() => _pos = p);
  }

  void _snapTo(double t) {
    _from = _pos;
    _to = _wrap ? t : t.clamp(0.0, _max).toDouble();
    _ctl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.count;
    if (n == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final h = cons.maxHeight;
        final ch = math.min(h * 0.58, w * 0.52 / widget.aspect);
        final cw = ch * widget.aspect;
        final cx = w / 2;
        final cy = h * 0.44;
        // Tú estás en el centro del anillo: cada radián de giro mueve las tarjetas [k] píxeles.
        final k = (w / 2) / 1.15;
        final px = math.max(20.0, k * _step);
        final front = _index(_pos);

        final placed = <_Placed>[];
        for (var i = 0; i < n; i++) {
          var d = i - _pos;
          if (_wrap) {
            d = d % n;
            if (d > n / 2) d -= n;
          }
          final th = d * _step;
          if (th.abs() > 1.75) continue; // detrás de ti: no se ve
          placed.add(_Placed(i, d, th));
        }
        // Primero las más lejanas (a los lados); la del frente queda encima.
        placed.sort((a, b) => b.th.abs().compareTo(a.th.abs()));

        final cards = <Widget>[];
        for (final e in placed) {
          final t = (e.th.abs() / 1.2).clamp(0.0, 1.0).toDouble();
          final s = 1 - 0.22 * t * t;
          final x = k * e.th;
          final shade = (t * t * 0.7).clamp(0.0, 0.7).toDouble();
          cards.add(Positioned(
            left: cx + x - cw / 2,
            top: cy - ch / 2,
            width: cw,
            height: ch,
            child: GestureDetector(
              onTap: () => e.i == front ? widget.onFront(e.i) : _snapTo(_pos + e.d),
              onLongPress: e.i == front && widget.onLongPressFront != null
                  ? () => widget.onLongPressFront!(e.i)
                  : null,
              child: Transform(
                alignment: Alignment.center,
                // La tarjeta mira hacia ti: las de la derecha se giran hacia la izquierda y viceversa.
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0007)
                  ..rotateY(e.th * 0.85)
                  ..scale(s, s, 1.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.itemBuilder(context, e.i),
                    IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(color: Colors.black.withOpacity(shade)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ));
        }

        final cap = widget.caption?.call(front);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _ctl.stop(),
          onHorizontalDragUpdate: (d) => _setPos(_pos - d.delta.dx / px),
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            _snapTo((_pos - v / (px * 5)).roundToDouble());
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _FloorPainter(cx, cy + ch * 0.56, w))),
              ...cards,
              if (cap != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cap.$1,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      if (cap.$2 != null)
                        Text(cap.$2!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.white60)),
                      Text('${front + 1} / $n', style: const TextStyle(fontSize: 12, color: Colors.white38)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Suelo del anillo: un resplandor bajo las tarjetas, como si estuvieras en el centro de la sala.
class _FloorPainter extends CustomPainter {
  _FloorPainter(this.cx, this.y, this.w);
  final double cx;
  final double y;
  final double w;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: Offset(cx, y), width: w * 0.95, height: w * 0.16);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(colors: [Colors.white.withOpacity(0.10), Colors.transparent]).createShader(rect),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.07);
    for (var i = 1; i <= 3; i++) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, y), width: w * 0.3 * i, height: w * 0.05 * i), ring);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => old.cx != cx || old.y != y || old.w != w;
}
