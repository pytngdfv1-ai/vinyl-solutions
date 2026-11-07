import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vinyl.dart';
import 'cassette_card.dart';

/// Estuche transparente de cassette (vertical): bandeja con bisagra a la izquierda y dos
/// clavijas para los carretes, y tapa de plástico con la portada. Se usa igual en la ficha
/// y en la animación (la tapa se abre/cierra con [open]).
class CassetteCase extends StatelessWidget {
  const CassetteCase({super.key, required this.vinyl, this.open = false, this.lid = 0});

  final Vinyl vinyl;

  /// Estuche abierto de forma estática (cassette dentro del casetero).
  final bool open;

  /// Apertura animada 0..1 (si se da, manda sobre [open]).
  final double lid;

  @override
  Widget build(BuildContext context) {
    final target = lid > 0 ? lid : (open ? 1.0 : 0.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: lid > 0 ? Duration.zero : const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, a, _) => LayoutBuilder(builder: (context, c) {
        final cw = math.min(c.maxWidth, c.maxHeight * 0.63);
        return Center(
        child: Transform.translate(
          // Con la tapa abierta, el conjunto (tapa + bandeja) queda centrado.
          offset: Offset(cw * 0.5 * (a > 1 ? 1 : a), 0),
          child: AspectRatio(
          aspectRatio: 0.63,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              CaseTray(vinyl: vinyl, showPegs: a > 0.02),
              CaseLid(vinyl: vinyl, angle: math.pi * a, showTracks: false),
            ],
          ),
        ),
        ),
        );
      }),
    );
  }
}

/// Bandeja del estuche: plástico traslúcido, hueco oscuro, bisagra y clavijas.
class CaseTray extends StatelessWidget {
  const CaseTray({super.key, this.vinyl, this.showPegs = true});
  final Vinyl? vinyl;
  final bool showPegs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _TrayPainter(showPegs)),
        // El cassette descansa sobre la cara de la portada.
        if (vinyl != null)
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth, h = c.maxHeight;
            return Positioned.fromRect(
              rect: Rect.fromLTRB(w * 0.11, h * 0.035, w * 0.96, h * 0.965),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(w * 0.03),
                child: CassetteCard(vinyl: vinyl!),
              ),
            );
          }),
      ],
    );
  }
}

class _TrayPainter extends CustomPainter {
  _TrayPainter(this.pegs);
  final bool pegs;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(w * 0.05));
    canvas.drawRRect(body.shift(Offset(w * 0.02, h * 0.012)), Paint()..color = Colors.black54);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9FB0BC), Color(0xFF6F7E89), Color(0xFF8795A0)],
        ).createShader(Offset.zero & s),
    );
    // Hueco interior oscuro.
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.11, h * 0.035, w * 0.96, h * 0.965),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(inner, Paint()..color = const Color(0xFF1A1D21));
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55FFFFFF),
    );
    // Bisagra a la izquierda.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(0, h * 0.02, w * 0.07, h * 0.98), Radius.circular(w * 0.03)),
      Paint()..color = const Color(0xFF5E6B75),
    );
    for (final y in [0.18, 0.5, 0.82]) {
      canvas.drawCircle(Offset(w * 0.035, h * y), w * 0.018, Paint()..color = const Color(0xFFC9D2D8));
    }
    if (pegs) {
      // Dos clavijas de tres puntas para los carretes.
      final peg = Paint()..color = const Color(0xFFDDE3E8);
      for (final c in [Offset(w * 0.535, h * 0.28), Offset(w * 0.535, h * 0.72)]) {
        canvas.drawCircle(c, w * 0.055, Paint()..color = const Color(0xFF30353B));
        for (var i = 0; i < 3; i++) {
          final a = i * 2.0944 - 1.5708;
          canvas.drawLine(
            c,
            c + Offset(w * 0.07 * math.cos(a), w * 0.07 * math.sin(a)),
            peg
              ..strokeWidth = w * 0.028
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(c, w * 0.018, Paint()..color = const Color(0xFF8E98A0));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrayPainter old) => old.pegs != pegs;
}

/// Tapa de plástico transparente. Cerrada muestra la portada; al abrirse más de 90° se ve su
/// cara interna con la lista de temas (adaptada al rectángulo de la tapa).
class CaseLid extends StatelessWidget {
  const CaseLid({super.key, required this.vinyl, this.angle = 0, this.showTracks = true});
  final Vinyl vinyl;
  final double angle;

  /// Muestra la lista de temas en la cara interna (en la animación se deja lisa).
  final bool showTracks;

  @override
  Widget build(BuildContext context) {
    final inner = angle > math.pi / 2;
    final face = inner
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi), // la cara interna se ve al revés: se corrige
            child: showTracks ? _LidTracks(vinyl: vinyl) : const _LidBlank(),
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(2),
                child: CassetteCard(vinyl: vinyl),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white60, width: 1.3),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x44FFFFFF), Color(0x0FFFFFFF), Color(0x33FFFFFF)],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ],
          );
    return Transform(
      alignment: Alignment.centerLeft,
      // Se abre hacia el frente (hacia quien mira), con perspectiva marcada: el borde exterior crece.
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0035)
        ..rotateY(-angle),
      child: face,
    );
  }
}

/// Cara interna lisa: plástico transparente oscuro.
class _LidBlank extends StatelessWidget {
  const _LidBlank();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white54, width: 1.3),
        color: const Color(0x66222428),
      ),
    );
  }
}

/// Cara interna de la tapa: lista de temas sobre plástico oscuro.
class _LidTracks extends StatelessWidget {
  const _LidTracks({required this.vinyl});
  final Vinyl vinyl;

  @override
  Widget build(BuildContext context) {
    final t = vinyl.tracks;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white54, width: 1.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2E33), Color(0xFF1B1E22)],
        ),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final fs = c.maxWidth * 0.075;
        return Padding(
          padding: EdgeInsets.all(c.maxWidth * 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vinyl.artist.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: fs * 0.9, letterSpacing: 1.2),
              ),
              Text(
                vinyl.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: fs * 1.25),
              ),
              Divider(color: Colors.white24, height: fs),
              Expanded(
                child: ClipRect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < t.length && i < 30; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: fs * 0.25),
                          child: Text(
                            '${i + 1}. ${t[i]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: fs * 0.95),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
