import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vinyl.dart';
import 'cassette_card.dart';
import 'cover_art.dart';

/// Animación de apertura (~1,5 s): el disco sale de su funda y cae al tocadisco, o el cassette
/// se abre en 3D y cae a la casetera. Un toque la salta. Se dibuja encima y luego desaparece.
class OpenAnim extends StatefulWidget {
  const OpenAnim({super.key, required this.vinyl, required this.child});
  final Vinyl vinyl;
  final Widget child;

  @override
  State<OpenAnim> createState() => _OpenAnimState();
}

class _OpenAnimState extends State<OpenAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
        });
  bool _done = false;

  bool get _cass => widget.vinyl.cassette || widget.vinyl.single;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _disc(double d) {
    final v = widget.vinyl;
    final lr = d * 0.34;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2A2C)),
        ),
        Container(
          width: lr * 2,
          height: lr * 2,
          decoration: BoxDecoration(shape: BoxShape.circle, color: hueColor(v.hue, 0.7, 0.5)),
          child: ClipOval(
            child: Stack(fit: StackFit.expand, children: [
              if (v.coverUrl != null)
                buildCoverImage(v.coverUrl!, cacheWidth: 200, fallback: const SizedBox.shrink()),
              Container(color: Colors.black38),
              Padding(
                padding: EdgeInsets.all(lr * 0.28),
                child: Center(
                  child: Text(
                    '${v.artist}\n${v.title}${v.year > 0 ? '\n${v.year}' : ''}',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: lr * 0.22, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Container(width: d * 0.04, height: d * 0.04, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _done = true),
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth, h = c.maxHeight;
                final base = math.min(w * 0.5, h * 0.9);
                return AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final t = _c.value;
                    final fade = t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0;
                    final fall = Curves.easeIn.transform(((t - 0.4) / 0.6).clamp(0.0, 1.0));
                    final open = Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));
                    final dy = -h * 0.5 * (1 - fall);
                    final obj = _cass
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY((1 - open) * 1.3)
                              ..rotateX((1 - fall) * 0.5),
                            child: SizedBox(width: base * 0.9, height: base * 0.9 * 1.0, child: CassetteCard(vinyl: widget.vinyl)),
                          )
                        : Stack(alignment: Alignment.center, children: [
                            // Funda (la portada) y disco que sale de ella hacia la derecha.
                            Opacity(
                              opacity: 1 - fall,
                              child: SizedBox(width: base, height: base, child: CoverArt(vinyl: widget.vinyl, radius: 4)),
                            ),
                            Transform.translate(
                              offset: Offset(base * 0.45 * open * (1 - fall), 0),
                              child: Transform.rotate(angle: fall * 4, child: _disc(base * (1 - 0.15 * fall))),
                            ),
                          ]);
                    return Opacity(
                      opacity: fade,
                      child: Container(
                        color: Colors.black.withOpacity(0.35 * fade),
                        child: Transform.translate(offset: Offset(0, dy), child: Center(child: obj)),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
      ],
    );
  }
}
