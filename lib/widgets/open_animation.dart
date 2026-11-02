import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/vinyl.dart';
import 'cover_art.dart';
import 'turntable.dart';
import 'vinyl_disc.dart';

/// Animación al abrir un disco o un cassette (~1,5 s, se salta tocando la pantalla).
/// Disco: sale del sobre con perspectiva 3D, se inclina, y aterriza sobre el plato con un
/// resorte (rebote). Es el MISMO [VinylDisc] que luego queda en el plato: sin salto visual.
class OpenAnimation extends StatefulWidget {
  const OpenAnimation({
    super.key,
    required this.vinyl,
    required this.onDone,
    required this.targetKey,
    required this.sourceKey,
  });

  final Vinyl vinyl;
  final VoidCallback onDone;

  /// Dónde queda el disco / cassette (tornamesa o casetero) y de dónde sale (la portada).
  final GlobalKey targetKey;
  final GlobalKey sourceKey;

  @override
  State<OpenAnimation> createState() => _OpenAnimationState();
}

class _OpenAnimationState extends State<OpenAnimation> with TickerProviderStateMixin {
  // Salida del sobre (0..1) y aterrizaje con resorte (sin límites: rebota).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final AnimationController _land = AnimationController.unbounded(vsync: this, value: 0);
  Rect? _target, _source;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      if (_target == null) {
        _finish();
        return;
      }
      _c.forward().whenComplete(_landing);
    });
  }

  Rect? _rectOf(GlobalKey k) {
    final ctx = k.currentContext;
    final me = context.findRenderObject();
    if (ctx == null || me is! RenderBox) return null;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox || !rb.attached) return null;
    final tl = me.globalToLocal(rb.localToGlobal(Offset.zero));
    return tl & rb.size;
  }

  void _measure() => setState(() {
        _target = _rectOf(widget.targetKey);
        _source = _rectOf(widget.sourceKey);
      });

  void _landing() {
    if (!mounted || _finished) return;
    const spring = SpringDescription(mass: 1, stiffness: 230, damping: 15);
    _land
        .animateWith(SpringSimulation(spring, 0, 1, 2.2, tolerance: const Tolerance(distance: 0.004, velocity: 0.08)))
        .whenComplete(_finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    HapticFeedback.mediumImpact();
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    _land.dispose();
    super.dispose();
  }

  bool get _tape => widget.vinyl.cassette || widget.vinyl.single;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _land]),
        builder: (context, _) {
          final t = _target;
          if (t == null) return const SizedBox.expand();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              _tape ? _cassette(t, _source) : _disc(t, _source),
            ],
          );
        },
      ),
    );
  }

  // ---- Disco: sale del sobre con perspectiva y aterriza con rebote ----
  Widget _disc(Rect target, Rect? source) {
    final v = widget.vinyl;
    final tracks = v.tracks.length;
    final sc = Turntable.scaleFor(v.single, tracks);
    final geo = Turntable.discGeometry(target.size, sc);
    final tCenter = target.topLeft + geo.$1;
    final tD = geo.$2 * 2;
    final src = source ?? Rect.fromCenter(center: target.center + Offset(0, target.height), width: tD, height: tD);
    final sD = math.min(src.width, src.height) * 0.96;

    final e = Curves.easeInOutCubic.transform(_c.value);
    final lv = _land.value; // 0 → 1 (con rebote)
    final hover = tCenter + Offset(0, -tD * 0.18);
    final landing = _c.isCompleted || _land.value != 0;

    final Offset pos;
    final double dia, tilt, elev;
    if (!landing) {
      pos = Offset.lerp(src.center, hover, e)!;
      dia = sD + (tD * 1.07 - sD) * e;
      tilt = 0.95 * (1 - e) + 0.28 * e; // se inclina más al salir, se endereza al llegar
      elev = e;
    } else {
      pos = Offset.lerp(hover, tCenter, lv)!;
      dia = tD * (1.07 - 0.07 * lv);
      tilt = 0.28 * (1 - lv).clamp(0.0, 1.0);
      elev = (1 - lv).clamp(0.0, 1.0);
    }
    final spin = (1 - (landing ? 1.0 : e * 0.8)) * 3.0 + (landing ? (1 - lv) * 0.6 : 0.0);
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..rotateX(tilt)
      ..rotateY(-tilt * 0.35);
    final sleeveFade = landing ? (1 - lv * 1.4).clamp(0.0, 1.0).toDouble() : 1.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: pos.dx - dia / 2,
          top: pos.dy - dia / 2,
          width: dia,
          height: dia,
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: VinylDisc(
              vinyl: v,
              diameter: dia,
              spin: spin,
              labelRatio: Turntable.labelRatioFor(sc),
              tracks: tracks,
              elevation: elev,
            ),
          ),
        ),
        // Sobre: copia de la portada encima del disco mientras sale.
        if (source != null && sleeveFade > 0)
          Positioned.fromRect(
            rect: src,
            child: Opacity(
              opacity: sleeveFade,
              child: DecoratedBox(
                decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)]),
                child: CoverArt(vinyl: v, radius: 2),
              ),
            ),
          ),
      ],
    );
  }

  // ---- Cassette: se abre en 3D y cae al casetero ----
  Widget _cassette(Rect target, Rect? source) {
    final w = target.right + target.left, h = target.bottom * 2.4, t = _c.value;
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
