import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../data/tilt.dart';
import '../data/ui_settings.dart';

import '../data/cover_color.dart';
import '../models/vinyl.dart';
import 'cover_art.dart';

/// Disco de vinilo ÚNICO: se usa igual al salir de la funda (open_animation) y sobre el plato
/// (turntable), así la etiqueta nunca cambia. Capas: cuerpo estático (canto, surcos, zonas lisas
/// entre pistas), capa que gira (etiqueta con portada + texto curvo) y brillo.
class VinylDisc extends StatelessWidget {
  const VinylDisc({
    super.key,
    required this.vinyl,
    required this.diameter,
    this.spin = 0,
    this.labelRatio = 0.33,
    this.tracks = 1,
    this.elevation = 0,
    this.light = 0,
    this.wear = 0,
  });

  final Vinyl vinyl;
  final double diameter;

  /// Giro en radianes (solo gira la etiqueta; los surcos son simétricos).
  final double spin;
  final double labelRatio;
  final int tracks;

  /// 0 = apoyado en el plato, 1 = levantado (sombra grande y difusa).
  final double elevation;

  /// Ángulo de la luz (inclinación del teléfono) para el brillo.
  final double light;

  /// Desgaste 0..1.
  final double wear;

  @override
  Widget build(BuildContext context) {
    final d = diameter;
    final e = elevation.clamp(0.0, 1.0).toDouble();
    final shadow = BoxShadow(
      color: Colors.black.withOpacity(0.5 - 0.15 * e),
      blurRadius: 3 + 24 * e,
      offset: Offset(0, 1 + 17 * e),
    );
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [shadow])),
          ),
          RepaintBoundary(
            child: CustomPaint(size: Size.square(d), painter: _DiscBodyPainter(tracks, labelRatio)),
          ),
          Transform.rotate(
            angle: spin,
            child: RepaintBoundary(
              child: SizedBox(
                width: d,
                height: d,
                child: Center(
                  child: SizedBox(
                    width: d * labelRatio,
                    height: d * labelRatio,
                    child: DiscLabel(vinyl: vinyl),
                  ),
                ),
              ),
            ),
          ),
          if (UiSettings.fx)
            IgnorePointer(child: _Sheen(diameter: d, angle: light + spin * 0.15)),
        ],
      ),
    );
  }
}

/// Canto del vinilo, superficie con surcos finos y zonas lisas entre pistas.
class _DiscBodyPainter extends CustomPainter {
  _DiscBodyPainter(this.tracks, this.labelRatio);
  final int tracks;
  final double labelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    // Parte de abajo (grosor visible del disco).
    canvas.drawCircle(c + Offset(0, r * 0.016), r, Paint()..color = const Color(0xFF040405));
    // Canto: aro más claro justo en el borde.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1B1B1E), Color(0xFF1B1B1E), Color(0xFF4A4A4F), Color(0xFF101012)],
          stops: [0, 0.955, 0.978, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Superficie.
    canvas.drawCircle(c, r * 0.982, Paint()..color = const Color(0xFF151517));
    canvas.drawCircle(
      c,
      r * 0.982,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Zonas: entrada lisa, surcos por tema y salida lisa junto a la etiqueta.
    final ro = r * 0.93;
    final ri = r * (labelRatio + 0.10);
    final n = math.min(math.max(1, tracks), 31);
    final gapW = math.max(1.4, r * 0.016);
    final gaps = <double>[for (var k = 1; k < n; k++) ro - (ro - ri) * k / n];

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, r * 0.0045);
    final step = math.max(1.1, r * 0.012);
    var i = 0;
    for (var rad = ro; rad > ri; rad -= step, i++) {
      if (gaps.any((g) => (g - rad).abs() < gapW * 1.6)) continue; // zona lisa
      groove.color = i.isEven ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.35);
      canvas.drawCircle(c, rad, groove);
    }
    final gapPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = gapW
      ..color = const Color(0xFF0B0B0D);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.005)
      ..color = Colors.white.withOpacity(0.10);
    for (final g in gaps) {
      canvas.drawCircle(c, g, gapPaint);
      canvas.drawCircle(c, g + gapW * 0.9, rim);
    }
    // Aro liso alrededor de la etiqueta.
    canvas.drawCircle(c, r * (labelRatio + 0.115), Paint()..color = const Color(0xFF0E0E10));
  }

  @override
  bool shouldRepaint(covariant _DiscBodyPainter old) => old.tracks != tracks || old.labelRatio != labelRatio;
}

/// Brillo del vinilo: shader si está disponible (según la inclinación del teléfono); si no, degradado.
class _Sheen extends StatefulWidget {
  const _Sheen({required this.diameter, required this.angle});
  final double diameter;
  final double angle;

  @override
  State<_Sheen> createState() => _SheenState();
}

class _SheenState extends State<_Sheen> {
  VoidCallback? _release;

  @override
  void initState() {
    super.initState();
    _release = Tilt.instance.acquire();
    SheenShader.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    return ValueListenableBuilder<Offset>(
      valueListenable: Tilt.instance.value,
      builder: (_, t, __) {
        final prog = SheenShader.program;
        return CustomPaint(
          size: Size.square(d),
          painter: prog == null
              ? _SheenFallback(widget.angle + t.dx * 1.2)
              : _SheenShaderPainter(prog, widget.angle, t),
        );
      },
    );
  }
}

class _SheenShaderPainter extends CustomPainter {
  _SheenShaderPainter(this.program, this.angle, this.tilt);
  final ui.FragmentProgram program;
  final double angle;
  final Offset tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final sh = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, angle)
      ..setFloat(3, tilt.dx)
      ..setFloat(4, tilt.dy)
      ..setFloat(5, 1.0);
    canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
  }

  @override
  bool shouldRepaint(covariant _SheenShaderPainter old) =>
      old.angle != angle || old.tilt != tilt || old.program != program;
}

/// Brillo angular sin shader (dos lóbulos opuestos). El shader lo reemplaza cuando está disponible.
class _SheenFallback extends CustomPainter {
  _SheenFallback(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r * 0.95);
    final lobe = Colors.white.withOpacity(0.16);
    const none = Color(0x00FFFFFF);
    canvas.drawCircle(
      Offset(r, r),
      r * 0.95,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [none, none, lobe, none, none, lobe, none],
          stops: const [0, 0.08, 0.125, 0.17, 0.58, 0.625, 0.67],
          transform: GradientRotation(angle),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SheenFallback old) => old.angle != angle;
}

/// Etiqueta central generada desde la portada: color dominante de fondo, recorte circular del
/// centro de la portada, artista y título en texto curvo, y agujero central.
class DiscLabel extends StatefulWidget {
  const DiscLabel({super.key, required this.vinyl});
  final Vinyl vinyl;

  @override
  State<DiscLabel> createState() => _DiscLabelState();
}

class _DiscLabelState extends State<DiscLabel> {
  late Future<Color?> _color = CoverColor.of(widget.vinyl.coverUrl);

  @override
  void didUpdateWidget(covariant DiscLabel old) {
    super.didUpdateWidget(old);
    if (old.vinyl.coverUrl != widget.vinyl.coverUrl) _color = CoverColor.of(widget.vinyl.coverUrl);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    final url = v.coverUrl;
    final fallbackColor = hueColor(v.hue, 0.6, 0.42);
    return FutureBuilder<Color?>(
      future: _color,
      builder: (context, snap) {
        final base = snap.data ?? fallbackColor;
        final dark = base.computeLuminance() < 0.5;
        final ink = dark ? Colors.white : const Color(0xFF151515);
        return LayoutBuilder(builder: (context, c) {
          final d = c.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(child: ColoredBox(color: base, child: SizedBox(width: d, height: d))),
              SizedBox(
                width: d * 0.60,
                height: d * 0.60,
                child: ClipOval(
                  child: url == null
                      ? ColoredBox(color: Color.lerp(base, Colors.black, 0.25)!)
                      : Transform.scale(
                          scale: 1.5,
                          child: buildCoverImage(
                            url,
                            cacheWidth: 300,
                            fallback: ColoredBox(color: Color.lerp(base, Colors.black, 0.25)!),
                          ),
                        ),
                ),
              ),
              CustomPaint(
                size: Size.square(d),
                painter: _LabelTextPainter(artist: v.artist, title: v.title, year: v.yearLabel, ink: ink),
              ),
              // Agujero central con aro.
              Container(
                width: d * 0.085,
                height: d * 0.085,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A0A0B),
                  border: Border.all(color: Colors.white24, width: math.max(0.6, d * 0.006)),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class _LabelTextPainter extends CustomPainter {
  _LabelTextPainter({required this.artist, required this.title, required this.year, required this.ink});
  final String artist, title, year;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final fs = r * 0.15;
    final style = TextStyle(color: ink, fontSize: fs, fontWeight: FontWeight.w800, letterSpacing: fs * 0.04);
    _arc(canvas, c, artist.toUpperCase(), r * 0.78, -math.pi / 2, false, style, r);
    final t = year.isEmpty ? title : '$title · $year';
    _arc(canvas, c, t, r * 0.69, math.pi / 2, true, style.copyWith(fontWeight: FontWeight.w600), r);
  }

  /// Texto sobre un arco centrado en [mid]; la parte de abajo se lee derecha (de izquierda a derecha).
  void _arc(Canvas canvas, Offset c, String text, double radius, double mid, bool bottom, TextStyle style, double r) {
    if (text.isEmpty) return;
    final maxAngle = 2.1;
    final painters = <TextPainter>[];
    var total = 0.0;
    for (final ch in text.characters) {
      final tp = TextPainter(text: TextSpan(text: ch, style: style), textDirection: TextDirection.ltr)..layout();
      final a = tp.width / radius;
      if (total + a > maxAngle) {
        final dots = TextPainter(text: TextSpan(text: '…', style: style), textDirection: TextDirection.ltr)..layout();
        painters.add(dots);
        total += dots.width / radius;
        break;
      }
      painters.add(tp);
      total += a;
    }
    var cursor = bottom ? mid + total / 2 : mid - total / 2;
    for (final tp in painters) {
      final a = tp.width / radius;
      final ang = bottom ? cursor - a / 2 : cursor + a / 2;
      canvas.save();
      canvas.translate(c.dx + math.cos(ang) * radius, c.dy + math.sin(ang) * radius);
      canvas.rotate(bottom ? ang - math.pi / 2 : ang + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      cursor += bottom ? -a : a;
    }
  }

  @override
  bool shouldRepaint(covariant _LabelTextPainter old) =>
      old.artist != artist || old.title != title || old.year != year || old.ink != ink;
}
