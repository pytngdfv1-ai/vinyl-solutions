import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/cover_color.dart';
import '../models/vinyl.dart';
import 'cassette_card.dart';
import 'cover_art.dart';

/// URL de la contraportada del disco (si se guardó una en el libreto).
String? backCoverOf(Vinyl v) {
  final re = RegExp(r'(contraportada|trasera|back|rear)', caseSensitive: false);
  for (final u in v.booklet) {
    final name = Uri.decodeFull(u.split('/').last);
    if (re.hasMatch(name)) return u;
  }
  return null;
}

/// Cassette en 3D: frente (portada completa con relleno de color), lomo con degradado hasta
/// el color de la parte posterior, y parte posterior (contraportada si existe, si no los temas).
class Cassette3D extends StatefulWidget {
  const Cassette3D({super.key, required this.vinyl});
  final Vinyl vinyl;

  @override
  State<Cassette3D> createState() => _Cassette3DState();
}

class _Cassette3DState extends State<Cassette3D> {
  late String? _back = backCoverOf(widget.vinyl);
  late Future<List<Color?>> _colors =
      Future.wait([CoverColor.of(widget.vinyl.coverUrl), CoverColor.of(_back)]);

  @override
  void didUpdateWidget(covariant Cassette3D old) {
    super.didUpdateWidget(old);
    if (old.vinyl.coverUrl != widget.vinyl.coverUrl || old.vinyl.booklet.length != widget.vinyl.booklet.length) {
      _back = backCoverOf(widget.vinyl);
      _colors = Future.wait([CoverColor.of(widget.vinyl.coverUrl), CoverColor.of(_back)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    final hueColor = HSLColor.fromAHSL(1, v.hue % 360, 0.5, 0.22).toColor();
    return LayoutBuilder(
      builder: (context, c) {
        var hh = c.maxHeight * 0.96;
        var ww = hh * 0.63;
        if (ww > c.maxWidth * 0.9) {
          ww = c.maxWidth * 0.9;
          hh = ww / 0.63;
        }
        final t = ww * 0.2;
        return FutureBuilder<List<Color?>>(
          future: _colors,
          builder: (context, snap) {
            final a = snap.data?[0] ?? hueColor;
            final b = snap.data?[1] ?? Color.lerp(a, Colors.black, 0.4)!;
            Widget face(double fw, double fh, Matrix4 m, Widget child) => Transform(
                  alignment: Alignment.center,
                  transform: m,
                  child: SizedBox(width: fw, height: fh, child: child),
                );
            final title = v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;
            return Center(
              child: SizedBox(
                width: ww,
                height: hh,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    face(ww, hh, Matrix4.identity()..translate(0.0, 0.0, t / 2)..rotateY(math.pi),
                        _BackFace(vinyl: v, backUrl: _back, base: b)),
                    face(t, hh, Matrix4.identity()..translate(-ww / 2, 0.0, 0.0)..rotateY(math.pi / 2),
                        _Spine(from: b, to: a, text: '${v.artist} · $title', quarter: 1)),
                    face(t, hh, Matrix4.identity()..translate(ww / 2, 0.0, 0.0)..rotateY(-math.pi / 2),
                        _Spine(from: a, to: b, text: '${v.artist} · $title', quarter: 3)),
                    face(ww, hh, Matrix4.identity()..translate(0.0, 0.0, -t / 2), CassetteCard(vinyl: v)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Spine extends StatelessWidget {
  const _Spine({required this.from, required this.to, required this.text, required this.quarter});
  final Color from;
  final Color to;
  final String text;
  final int quarter;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [from, to]),
        border: Border.symmetric(horizontal: BorderSide(color: Colors.white38, width: 1.5)),
      ),
      child: RotatedBox(
        quarterTurns: quarter,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackFace extends StatelessWidget {
  const _BackFace({required this.vinyl, required this.backUrl, required this.base});
  final Vinyl vinyl;
  final String? backUrl;
  final Color base;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(base, Colors.black, 0.45)!;
    Widget fill(bool top) => Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [dark, base],
              ),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.5),
        child: backUrl != null
            ? Column(
                children: [
                  fill(true),
                  AspectRatio(
                    aspectRatio: 1,
                    child: buildCoverImage(backUrl!, cacheWidth: 500, fallback: ColoredBox(color: dark)),
                  ),
                  fill(false),
                ],
              )
            : DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dark, base])),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vinyl.artist.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      for (var i = 0; i < vinyl.tracks.length && i < 9; i++)
                        Text('${i + 1}. ${vinyl.tracks[i]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 9)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
