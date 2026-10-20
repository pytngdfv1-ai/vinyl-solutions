import 'dart:io';

import 'package:flutter/material.dart';

import '../data/koofr_settings.dart';
import '../models/vinyl.dart';

/// Imagen de portada: archivo local (file://) o red (Koofr / internet).
Widget buildCoverImage(
  String url, {
  required int cacheWidth,
  required Widget fallback,
  BoxFit fit = BoxFit.cover,
}) {
  if (url.startsWith('file:')) {
    return Image.file(
      File(Uri.parse(url).toFilePath()),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
  return Image.network(
    url,
    headers: KoofrSettings.headersFor(url),
    fit: fit,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
    errorBuilder: (_, __, ___) => fallback,
    loadingBuilder: (_, child, p) => p == null ? child : fallback,
  );
}

Color hueColor(double hue, double s, double l) =>
    HSLColor.fromAHSL(1, hue % 360, s, l).toColor();

/// Carátula generada por código (no usa imágenes con derechos de autor).
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.vinyl, this.radius = 4});

  final Vinyl vinyl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final art = _generated();
    final url = vinyl.coverUrl;
    if (url == null) return art;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: buildCoverImage(url, cacheWidth: 700, fallback: art),
    );
  }

  Widget _generated() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _CoverPainter(vinyl.hue),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return Padding(
              padding: EdgeInsets.all(w * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vinyl.artist.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (w * 0.04).clamp(8.0, 16.0),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      vinyl.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w * 0.11,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: w * 0.01),
                  Text(
                    vinyl.yearLabel,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: (w * 0.04).clamp(8.0, 16.0),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.hue);
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hueColor(hue, 0.65, 0.38), hueColor(hue + 40, 0.7, 0.16)],
        ).createShader(rect),
    );
    final c = Offset(size.width * 0.68, size.height * 0.42);
    final r = size.width * 0.28;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = hueColor(hue + 180, 0.75, 0.62).withOpacity(0.9),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012
      ..color = Colors.white.withOpacity(0.25);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, r + i * size.width * 0.05, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _CoverPainter old) => old.hue != hue;
}
