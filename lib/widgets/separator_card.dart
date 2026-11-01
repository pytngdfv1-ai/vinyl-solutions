import 'package:flutter/material.dart';

/// Separador entre artistas: totalmente transparente, con una solapa que sobresale
/// por arriba con el nombre del artista que sigue (como las pestañas de una caja de discos).
class SeparatorCard extends StatelessWidget {
  const SeparatorCard({super.key, required this.label, this.shade = 0});

  final String label;

  /// Oscurecimiento de la solapa según la distancia en la pila (0 a 1).
  final double shade;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final tabH = w * 0.11;
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned(
              left: w * 0.06,
              top: -tabH,
              width: w * 0.62,
              height: tabH,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.025),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFFEDE3CF), Colors.black, shade.clamp(0.0, 1.0)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(w * 0.025)),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, -1))],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      color: Color.lerp(const Color(0xFF1B1B1B), Colors.white54, shade.clamp(0.0, 1.0)),
                      fontSize: w * 0.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
