import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';
import '../widgets/turntable.dart';

/// Disco sacado de la caja: tornamesa arriba, carátula abajo.
/// Toca la carátula para darla vuelta, toca la tornamesa para play/pausa.
class StageScreen extends StatefulWidget {
  const StageScreen({super.key, required this.store, required this.vinyl});

  final VinylStore store;
  final Vinyl vinyl;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  bool _playing = false;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _playing = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F0E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF161816),
                      builder: (_) => DetailSheet(store: widget.store, vinyl: v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => setState(() => _playing = !_playing),
                child: Turntable(vinyl: v, playing: _playing),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final s = math.min(c.maxWidth - 32, c.maxHeight - 8);
                  return Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _flipped = !_flipped),
                      child: SizedBox(
                        width: s,
                        height: s,
                        child: Hero(
                          tag: 'cover-${v.id}',
                          child: _FlipCover(vinyl: v, flipped: _flipped),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${v.artist} · ${v.year}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    iconSize: 30,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () => setState(() => _playing = !_playing),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlipCover extends StatelessWidget {
  const _FlipCover({required this.vinyl, required this.flipped});

  final Vinyl vinyl;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: flipped ? 1 : 0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) {
        final back = v > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(v * math.pi),
          child: back
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: _Back(vinyl: vinyl),
                )
              : CoverArt(vinyl: vinyl),
        );
      },
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.vinyl});
  final Vinyl vinyl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: hueColor(vinyl.hue, 0.25, 0.12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vinyl.artist.toUpperCase(),
              style: const TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.w700),
            ),
            Text(vinyl.title, style: const TextStyle(color: Colors.white70)),
            const Divider(height: 20),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: vinyl.tracks.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${i + 1}.  ${vinyl.tracks[i]}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ficha del disco: colección, lista de pistas y eliminar.
class DetailSheet extends StatelessWidget {
  const DetailSheet({super.key, required this.store, required this.vinyl});

  final VinylStore store;
  final Vinyl vinyl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final v = store.items.firstWhere((e) => e.id == vinyl.id, orElse: () => vinyl);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.artist.toUpperCase(),
                  style: const TextStyle(color: Colors.white60, letterSpacing: 1.4),
                ),
                Text(
                  v.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                Text('${v.year}', style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(v.owned ? Icons.check : Icons.add),
                        label: Text(v.owned ? 'En colección' : 'Agregar a colección'),
                        onPressed: () => store.toggleOwned(v.id),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        store.remove(v.id);
                        Navigator.of(context)
                          ..pop()
                          ..pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('LISTA DE PISTAS', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: v.tracks.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text('${i + 1}'),
                      title: Text(v.tracks[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
