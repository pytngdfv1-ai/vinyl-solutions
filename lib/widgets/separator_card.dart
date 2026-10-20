import 'package:flutter/material.dart';

/// Separador negro entre artistas, con el nombre del grupo que sigue.
class SeparatorCard extends StatelessWidget {
  const SeparatorCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final initial = label.isEmpty ? '' : label.characters.first.toUpperCase();
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: w * 0.07,
                  top: 0,
                  child: Container(
                    width: w * 0.16,
                    height: w * 0.1,
                    alignment: Alignment.center,
                    color: const Color(0xFF1E1E1E),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: w * 0.06,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: w * 0.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
