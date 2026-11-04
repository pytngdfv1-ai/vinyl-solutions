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
      builder: (context, a, _) => Center(
        child: AspectRatio(
          aspectRatio: 0.63,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              CaseTray(showPegs: a > 0.02),
              CaseLid(vinyl: vinyl, angle: 1.45 * a),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeja del estuche: plástico traslúcido, hueco oscuro, bisagra y clavijas.
class CaseTray extends StatelessWidget {
  const CaseTray({super.key, this.showPegs = true});
  final bool showPegs;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TrayPainter(showPegs));
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

/// Tapa de plástico transparente con la portada; gira sobre su borde izquierdo.
class CaseLid extends StatelessWidget {
  const CaseLid({super.key, required this.vinyl, this.angle = 0});
  final Vinyl vinyl;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateY(-angle),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // La portada va impresa en el papel dentro de la tapa.
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
            child: CassetteCard(vinyl: vinyl),
          ),
          // Plástico transparente con brillo y borde.
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
      ),
    );
  }
}
