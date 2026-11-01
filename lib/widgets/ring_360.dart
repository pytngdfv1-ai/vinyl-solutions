import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Anillo 360°: las tarjetas giran alrededor de ti. Arrastra de lado para girar,
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

  bool get _wrap => widget.count >= 9;
  double get _step => _wrap ? 2 * math.pi / widget.count : 0.7;
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
        final ch = math.min(h * 0.58, w * 0.66 / widget.aspect);
        final cw = ch * widget.aspect;
        final r = math.max(w * 0.2, w / 2 - cw * 0.28);
        final cx = w / 2;
        final cy = h * 0.44;
        final px = math.max(24.0, r * _step);
        final front = _index(_pos);

        final placed = <_Placed>[];
        for (var i = 0; i < n; i++) {
          var d = i - _pos;
          if (_wrap) {
            d = d % n;
            if (d > n / 2) d -= n;
          }
          placed.add(_Placed(i, d, d * _step));
        }
        placed.sort((a, b) => math.cos(a.th).compareTo(math.cos(b.th)));

        final cards = <Widget>[];
        for (final e in placed) {
          final depth = (1 + math.cos(e.th)) / 2;
          final s = 0.42 + 0.58 * math.pow(depth, 1.4).toDouble();
          final x = r * math.sin(e.th);
          final dy = -(1 - depth) * ch * 0.26;
          final shade = ((1 - depth) * 0.75).clamp(0.0, 0.75).toDouble();
          cards.add(Positioned(
            left: cx + x - cw / 2,
            top: cy + dy - ch / 2,
            width: cw,
            height: ch,
            child: GestureDetector(
              onTap: () => e.i == front ? widget.onFront(e.i) : _snapTo(_pos + e.d),
              onLongPress: e.i == front && widget.onLongPressFront != null
                  ? () => widget.onLongPressFront!(e.i)
                  : null,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0008)
                  ..rotateY(-e.th * 0.6)
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
