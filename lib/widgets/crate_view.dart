import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vinyl.dart';
import 'cover_art.dart';
import 'separator_card.dart';

/// Caja de discos en perspectiva: arrastra vertical para hojear,
/// toca el disco del frente para sacarlo.
class CrateView extends StatefulWidget {
  const CrateView({
    super.key,
    required this.items,
    required this.onPick,
    this.onLongPress,
  });

  final List<Vinyl> items;
  final ValueChanged<Vinyl> onPick;
  final ValueChanged<Vinyl>? onLongPress;

  @override
  State<CrateView> createState() => _CrateViewState();
}

class _CrateViewState extends State<CrateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  double _pos = 0;
  double _from = 0;
  double _to = 0;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(() {
        _setPos(_from + (_to - _from) * Curves.easeOutCubic.transform(_ctl.value));
      });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  double get _max => math.max(0, widget.items.length - 1).toDouble();

  void _setPos(double v) {
    final p = v.clamp(0.0, _max).toDouble();
    final idx = p.round();
    if (idx != _last) {
      _last = idx;
      HapticFeedback.selectionClick();
    }
    setState(() => _pos = p);
  }

  void _snapTo(double target) {
    _from = _pos;
    _to = target.clamp(0.0, _max).toDouble();
    _ctl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Biblioteca vacía\nToca + y elige "Conectar Koofr"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final n = items.length;
    final pos = _pos.clamp(0.0, _max).toDouble();

    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final h = cons.maxHeight;
        final c = math.min(w * 0.84, h * 0.52);
        const lip = 76.0;
        final frontTop = h - c - lip;
        final cx = w / 2;
        final front = pos.round();
        final lo = math.max(0, pos.floor() - 1);
        final hi = math.min(n - 1, pos.floor() + 14);

        final cards = <Widget>[];
        for (var i = hi; i >= lo; i--) {
          cards.add(_card(items[i], i - pos, c, frontTop, cx, i == front));
        }

        final current = items[front];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onPick(current),
          onLongPress: widget.onLongPress == null ? null : () => widget.onLongPress!(current),
          onVerticalDragStart: (_) => _ctl.stop(),
          onVerticalDragUpdate: (d) => _setPos(_pos + d.delta.dy / 70),
          onVerticalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            _snapTo((_pos + v / 1400).roundToDouble());
          },
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _WoodPainter(c))),
              ...cards,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: lip,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 90, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF5A3A22), Color(0xFF2E1C10)],
                    ),
                    boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 12)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        current.isDivider ? current.title.toUpperCase() : current.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        current.isDivider
                            ? 'Siguiente grupo   ${front + 1}/$n'
                            : '${current.artist}${current.year > 0 ? ' · ${current.year}' : ''}   ${front + 1}/$n',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(Vinyl v, double d, double c, double frontTop, double cx, bool isFront) {
    Widget cover = v.isDivider ? SeparatorCard(label: v.title) : CoverArt(vinyl: v);
    if (isFront && !v.isDivider) cover = Hero(tag: 'cover-${v.id}', child: cover);

    if (d >= 0) {
      final k = math.pow(0.955, d).toDouble();
      final top = frontTop - 20 * (1 - k) / (1 - 0.955);
      final size = c * k;
      final shade = math.min(0.65, d * 0.045);
      return Positioned(
        left: cx - size / 2,
        top: top,
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, -2))],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cover,
              IgnorePointer(
                child: ColoredBox(color: Colors.black.withOpacity(shade)),
              ),
            ],
          ),
        ),
      );
    }

    // El disco de adelante cae hacia ti al hojear.
    final t = (-d).clamp(0.0, 1.0).toDouble();
    return Positioned(
      left: cx - c / 2,
      top: frontTop,
      width: c,
      height: c,
      child: Opacity(
        opacity: 1 - t,
        child: Transform.translate(
          offset: Offset(0, t * c * 0.4),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(t * 1.3),
            child: cover,
          ),
        ),
      ),
    );
  }
}

class _WoodPainter extends CustomPainter {
  _WoodPainter(this.cover);
  final double cover;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0B0B), Color(0xFF1A110B)],
        ).createShader(rect),
    );
    final side = (size.width - cover) / 2 - 6;
    if (side > 0) {
      final wood = Paint()..color = const Color(0xFF3A2414);
      canvas.drawRect(Rect.fromLTWH(0, 0, side, size.height), wood);
      canvas.drawRect(Rect.fromLTWH(size.width - side, 0, side, size.height), wood);
    }
    final grain = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grain);
    }
  }

  @override
  bool shouldRepaint(covariant _WoodPainter old) => old.cover != cover;
}
