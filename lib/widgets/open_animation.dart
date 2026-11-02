import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vinyl.dart';
import 'cover_art.dart';

/// Animación al abrir un disco o un cassette (~1,5 s, se salta tocando la pantalla).
/// Disco: sale de la funda y cae sobre la tornamesa, con su etiqueta central (artista, álbum, año).
/// Cassette: se abre en 3D y cae al casetero, con la portada cubriendo la franja de color.
class OpenAnimation extends StatefulWidget {
  const OpenAnimation({super.key, required this.vinyl, required this.onDone});

  final Vinyl vinyl;
  final VoidCallback onDone;

  @override
  State<OpenAnimation> createState() => _OpenAnimationState();
}

class _OpenAnimationState extends State<OpenAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _tape => widget.vinyl.cassette || widget.vinyl.single;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final fade = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0).toDouble();
          return LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            return Opacity(
              opacity: fade,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.55 * fade))),
                  _tape ? _cassette(w, h, t) : _disc(w, h, t),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  // ---- Disco: sale de la funda y cae a la tornamesa ----
  Widget _disc(double w, double h, double t) {
    final v = widget.vinyl;
    final d = math.min(w * 0.62, h * 0.34);
    final sleeve = d * 1.06;
    const out = 0.45;
    final a = Curves.easeOut.transform((t / out).clamp(0.0, 1.0).toDouble());
    final b = Curves.easeIn.transform(((t - out) / (1 - out)).clamp(0.0, 1.0).toDouble());
    final startY = h * 0.66, outY = h * 0.66 - sleeve * 0.75, endY = h * 0.3;
    final y = t < out ? startY + (outY - startY) * a : outY + (endY - outY) * b;
    final scale = t < out ? 1.0 : 1.0 - 0.12 * b;
    final sleeveFade = (1 - (t - out) / 0.3).clamp(0.0, 1.0).toDouble();
    return Stack(
      children: [
        Positioned(
          left: w / 2 - d / 2,
          top: y - d / 2,
          width: d,
          height: d,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(angle: t * 2.2, child: _DiscFace(v)),
          ),
        ),
        Positioned(
          left: w / 2 - sleeve / 2,
          top: startY - sleeve / 2,
          width: sleeve,
          height: sleeve,
          child: Opacity(
            opacity: sleeveFade,
            child: DecoratedBox(
              decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 10)]),
              child: CoverArt(vinyl: v, radius: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Cassette: se abre en 3D y cae al casetero ----
  Widget _cassette(double w, double h, double t) {
    final cw = w * 0.7;
    final ch = cw / 1.57;
    final k = Curves.easeInOut.transform(t.clamp(0.0, 1.0).toDouble());
    final y = -ch + (h * 0.3 + ch) * k;
    final tilt = 1.1 * (1 - k); // gira hasta quedar de frente
    final open = math.sin(math.min(t / 0.5, 1.0) * math.pi) * 0.5; // tapa que se abre y cierra
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(tilt)
      ..rotateY(-0.6 * (1 - k));
    return Positioned(
      left: w / 2 - cw / 2,
      top: y,
      width: cw,
      height: ch,
      child: Transform(
        alignment: Alignment.center,
        transform: m,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _TapeFace(widget.vinyl)),
            // Tapa transparente que se abre un instante.
            Positioned(
              left: 0,
              right: 0,
              top: -ch * open,
              height: ch * 0.18,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(-open * 1.6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    border: Border.all(color: Colors.white38),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Disco negro con surcos y etiqueta central: artista, álbum y año.
class _DiscFace extends StatelessWidget {
  const _DiscFace(this.v);
  final Vinyl v;

  @override
  Widget build(BuildContext context) {
    final label = HSLColor.fromAHSL(1, v.hue % 360, 0.55, 0.45).toColor();
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0B0B0C),
        boxShadow: [BoxShadow(color: Colors.black, blurRadius: 12)],
      ),
      child: LayoutBuilder(builder: (context, c) {
        final d = c.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final r in [0.92, 0.8, 0.68, 0.56])
              Container(
                width: d * r,
                height: d * r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10, width: 0.8),
                ),
              ),
            Container(
              width: d * 0.38,
              height: d * 0.38,
              padding: EdgeInsets.all(d * 0.04),
              decoration: BoxDecoration(shape: BoxShape.circle, color: label),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(v.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: d * 0.04)),
                  Text(v.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: d * 0.034)),
                  if (v.year > 0)
                    Text(v.yearLabel, style: TextStyle(color: Colors.white70, fontSize: d * 0.03)),
                ],
              ),
            ),
            Container(
              width: d * 0.03,
              height: d * 0.03,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
            ),
          ],
        );
      }),
    );
  }
}

/// Cassette horizontal: etiqueta arriba, portada sobre la franja de color y ventana.
class _TapeFace extends StatelessWidget {
  const _TapeFace(this.v);
  final Vinyl v;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final t = v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.03),
          color: const Color(0xFF2B2D30),
          border: Border.all(color: Colors.white54, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 12)],
        ),
        child: Stack(
          children: [
            Positioned(
              left: w * 0.07,
              top: h * 0.09,
              width: w * 0.873,
              height: h * 0.22,
              child: Container(
                color: const Color(0xFFF4F0E4),
                alignment: Alignment.center,
                child: Text('$t – ${v.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'cursive',
                        color: const Color(0xFF1F3C88),
                        fontWeight: FontWeight.w700,
                        fontSize: w * 0.06)),
              ),
            ),
            Positioned(
              left: w * 0.07,
              top: h * 0.31,
              width: w * 0.873,
              height: h * 0.43,
              child: v.coverUrl != null
                  ? CoverArt(vinyl: v, radius: 0)
                  : ColoredBox(color: HSLColor.fromAHSL(1, v.hue % 360, 0.62, 0.5).toColor()),
            ),
            Positioned(
              left: w * 0.21,
              top: h * 0.337,
              width: w * 0.595,
              height: h * 0.248,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1A1C),
                  borderRadius: BorderRadius.circular(h * 0.124),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
