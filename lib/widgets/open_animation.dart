import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/vinyl.dart';
import '../data/ui_settings.dart';
import 'cassette_body.dart';
import 'cassette_case.dart';
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
    this.reverse = false,
  });

  /// Recorrido inverso (EJECT): el cassette sale del casetero.
  final bool reverse;

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
    duration: Duration(milliseconds: _tape ? 3000 : 2200),
  );
  late final AnimationController _land = AnimationController.unbounded(vsync: this, value: 0);
  final ReelState _reels = ReelState();
  Rect? _target, _source;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _reels.tint = HSLColor.fromAHSL(1, widget.vinyl.hue % 360, 0.62, 0.5).toColor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      if (_target == null) {
        _finish();
        return;
      }
      if (widget.reverse) {
        _c.value = 1;
        _c.reverse().whenComplete(_finish);
      } else {
        _c.forward().whenComplete(_landing);
      }
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
    if (_tape) {
      // El cassette queda "encajado": clic háptico al llegar.
      HapticFeedback.mediumImpact();
    }
    const spring = SpringDescription(mass: 1, stiffness: 110, damping: 12);
    _land
        .animateWith(SpringSimulation(spring, 0, 1, 2.2, tolerance: const Tolerance(distance: 0.004, velocity: 0.08)))
        .whenComplete(_finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    if (!widget.reverse) HapticFeedback.mediumImpact();
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

  // ---- Cassette: el estuche se abre, el cassette sale, gira en perspectiva y se desliza en la ranura ----
  Widget _cassette(Rect bay, Rect? source) {
    final v = widget.vinyl;
    final cw = bay.width, ch = bay.height;
    final src = source ??
        Rect.fromCenter(center: bay.center + Offset(0, bay.height * 3), width: cw * 0.4, height: cw * 0.4);
    final p = _c.value;
    final lv = _land.value;
    final landing = _land.value != 0;
    // Fases: 0–.22 abre el estuche · .22–.62 el cassette sale y sube · .62–1 baja y entra en la ranura.
    final lid = Curves.easeInOut.transform((p / 0.22).clamp(0.0, 1.0).toDouble());
    final up = Curves.easeOutCubic.transform(((p - 0.22) / 0.4).clamp(0.0, 1.0).toDouble());
    final dn = Curves.easeInOutCubic.transform(((p - 0.62) / 0.38).clamp(0.0, 1.0).toDouble());
    final hover = bay.center + Offset(0, -ch * 1.15);
    Offset pos = p < 0.62 ? Offset.lerp(src.center, hover, up)! : Offset.lerp(hover, bay.center, dn)!;
    if (landing) pos = bay.center + Offset(0, -ch * 0.12 * lv * (1 - lv));
    final s0 = (math.min(src.width, src.height) * 0.9 / cw).clamp(0.25, 0.9).toDouble();
    final scale = p < 0.62 ? s0 + (1.12 - s0) * up : 1.12 + (1.0 - 1.12) * dn;
    final rx = p < 0.62 ? 0.9 + (0.35 - 0.9) * up : 0.35 * (1 - dn);
    final ry = p < 0.62 ? -0.7 + (-0.15 + 0.7) * up : -0.15 * (1 - dn);
    final rz = p < 0.62 ? -math.pi / 2 * (1 - up) : 0.0; // vertical en el estuche, horizontal al insertar
    final elev = (landing ? 0.0 : (p < 0.62 ? up : 1 - dn)).toDouble();
    final fx = UiSettings.fx;
    final m = Matrix4.identity()
      ..setEntry(3, 2, fx ? 0.0012 : 0)
      ..rotateX(fx ? rx : 0)
      ..rotateY(fx ? ry : 0)
      ..rotateZ(rz)
      ..scale(scale);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bandeja del estuche (con clavijas), siempre visible bajo el cassette.
        Positioned.fromRect(
          rect: src,
          child: const Center(child: AspectRatio(aspectRatio: 0.63, child: CaseTray())),
        ),
        Positioned(
          left: pos.dx - cw / 2,
          top: pos.dy - ch / 2,
          width: cw,
          height: ch,
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cw * 0.03),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35 + 0.25 * elev),
                      blurRadius: 4 + 30 * elev,
                      offset: Offset(0, 3 + 24 * elev),
                    ),
                  ],
                ),
                child: CassetteBody(
                  vinyl: v,
                  label:
                      '${v.tracks.isNotEmpty ? v.tracks.first : v.title} – ${v.artist}',
                  st: _reels,
                ),
              ),
            ),
          ),
        ),
        // Tapa transparente del estuche: gira sobre su borde izquierdo (se abre al sacar, se cierra al guardar).
        Positioned.fromRect(
          rect: src,
          child: Center(
            child: AspectRatio(aspectRatio: 0.63, child: CaseLid(vinyl: v, angle: 1.45 * lid)),
          ),
        ),
      ],
    );
  }
}
