import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';
import '../widgets/turntable.dart';
import 'booklet_screen.dart';

/// Disco sacado de la caja: tornamesa arriba, carátula abajo.
/// Toca la carátula para darla vuelta (pistas), la tornamesa para play/pausa.
class StageScreen extends StatefulWidget {
  const StageScreen({super.key, required this.store, required this.vinyl});

  final VinylStore store;
  final Vinyl vinyl;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  final _audio = PlayerService.instance;
  bool _flipped = false;
  bool _simPlaying = false; // discos sin audio: solo animación
  String? _error;

  Vinyl get v => widget.vinyl;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!v.hasAudio) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) setState(() => _simPlaying = true);
      return;
    }
    // Si este disco ya está sonando, la reproducción continúa sin tocarla.
    if (_audio.nowPlaying.value?.id == v.id) return;
    // Si otro disco está sonando, no lo interrumpas: solo se cambia al elegir un tema.
    if (_audio.nowPlaying.value != null && _audio.player.playing) return;
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await _ensureLoaded();
  }

  Future<bool> _ensureLoaded({int index = 0}) async {
    if (_audio.nowPlaying.value?.id == v.id) return true;
    try {
      await _audio.start(v, index: index);
      return _audio.nowPlaying.value?.id == v.id;
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo reproducir: $e');
      return false;
    }
  }

  // La música NO se detiene al cerrar esta pantalla.

  Widget _turntable() {
    if (!v.hasAudio) {
      return Turntable(
        vinyl: v,
        playing: _simPlaying,
        trackCount: v.tracks.length,
        single: v.single,
      );
    }
    final p = _audio.player;
    return ValueListenableBuilder<Vinyl?>(
      valueListenable: _audio.nowPlaying,
      builder: (_, np, __) {
        if (np?.id != v.id) {
          return Turntable(
            vinyl: v,
            playing: false,
            trackCount: v.tracks.length,
            single: v.single,
          );
        }
        return StreamBuilder<bool>(
          stream: p.playingStream,
          initialData: p.playing,
          builder: (_, ps) => StreamBuilder<int?>(
            stream: p.currentIndexStream,
            initialData: p.currentIndex,
            builder: (_, ix) => StreamBuilder<Duration>(
              stream: p.positionStream,
              builder: (_, pos) {
                final dur = p.duration?.inMilliseconds ?? 0;
                final cur = (pos.data ?? Duration.zero).inMilliseconds;
                final prog = dur > 0 ? (cur / dur).clamp(0.0, 1.0).toDouble() : 0.0;
                return Turntable(
                  vinyl: v,
                  playing: ps.data ?? false,
                  progress: prog,
                  trackIndex: ix.data ?? 0,
                  trackCount: v.tracks.length,
                  single: v.single,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggle() async {
    if (!v.hasAudio) {
      setState(() => _simPlaying = !_simPlaying);
      return;
    }
    if (_audio.nowPlaying.value?.id != v.id) {
      await _ensureLoaded();
      return;
    }
    final p = _audio.player;
    p.playing ? p.pause() : p.play();
  }

  Future<void> _playTrack(int i) async {
    if (_audio.nowPlaying.value?.id == v.id) {
      await _audio.goTrack(i);
    } else {
      await _ensureLoaded(index: i); // carga el disco directamente en ese tema
    }
  }

  void _prev() => _audio.goTrack((_audio.player.currentIndex ?? 0) - 1);
  void _next() => _audio.goTrack((_audio.player.currentIndex ?? 0) + 1);

  @override
  Widget build(BuildContext context) {
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
                  IconButton(
                    tooltip: 'Menú principal',
                    icon: const Icon(Icons.home_outlined),
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                  const Spacer(),
                  if (v.hasBooklet)
                    IconButton(
                      tooltip: 'Libreto',
                      icon: const Icon(Icons.menu_book),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => BookletScreen(vinyl: v)),
                      ),
                    ),
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
                onTap: _toggle,
                child: _turntable(),
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
                          child: _FlipCover(
                            vinyl: v,
                            flipped: _flipped,
                            onTrack: _playTrack,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ValueListenableBuilder<Vinyl?>(
              valueListenable: _audio.nowPlaying,
              builder: (_, np, __) => np != null && np.id != v.id && v.hasAudio
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Sigue sonando: ${np.title}. Toca un tema o play para cambiar.',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _Controls(
              vinyl: v,
              audio: _audio,
              onToggle: _toggle,
              onPrev: _prev,
              onNext: _next,
              simPlaying: _simPlaying,
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.vinyl,
    required this.audio,
    required this.onToggle,
    required this.onPrev,
    required this.onNext,
    required this.simPlaying,
  });

  final Vinyl vinyl;
  final PlayerService audio;
  final VoidCallback onToggle;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool simPlaying;

  @override
  Widget build(BuildContext context) {
    final p = audio.player;
    final v = vinyl;
    return ValueListenableBuilder<Vinyl?>(
      valueListenable: audio.nowPlaying,
      builder: (context, np, _) {
        final active = np?.id == v.id;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            children: [
              if (v.hasAudio)
                active
                    ? StreamBuilder<Duration>(
                        stream: p.positionStream,
                        builder: (_, s) {
                          final dur = p.duration ?? Duration.zero;
                          final maxMs = dur.inMilliseconds.toDouble();
                          final pos = (s.data ?? Duration.zero).inMilliseconds.toDouble();
                          return Slider(
                            value: maxMs > 0 ? pos.clamp(0.0, maxMs).toDouble() : 0,
                            max: maxMs > 0 ? maxMs : 1,
                            onChanged: (x) => p.seek(Duration(milliseconds: x.round())),
                          );
                        },
                      )
                    : const Slider(value: 0, onChanged: null),
              Row(
                children: [
                  Expanded(
                    child: v.hasAudio && active
                        ? StreamBuilder<int?>(
                            stream: p.currentIndexStream,
                            builder: (_, s) {
                              final i = s.data ?? 0;
                              final t = i < v.tracks.length ? v.tracks[i] : v.title;
                              return _Info(title: t, sub: '${v.artist} · ${v.title}');
                            },
                          )
                        : _Info(title: v.title, sub: '${v.artist}  ${v.yearLabel}'),
                  ),
                  if (v.hasAudio) ...[
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: active ? onPrev : null,
                    ),
                    StreamBuilder<bool>(
                      stream: p.playingStream,
                      initialData: p.playing,
                      builder: (_, s) => IconButton.filled(
                        iconSize: 30,
                        icon: Icon(active && (s.data ?? false) ? Icons.pause : Icons.play_arrow),
                        onPressed: onToggle,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: active ? onNext : null,
                    ),
                  ] else
                    IconButton.filled(
                      iconSize: 30,
                      icon: Icon(simPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: onToggle,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.title, required this.sub});
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60),
        ),
      ],
    );
  }
}

class _FlipCover extends StatelessWidget {
  const _FlipCover({
    required this.vinyl,
    required this.flipped,
    required this.onTrack,
  });

  final Vinyl vinyl;
  final bool flipped;
  final ValueChanged<int> onTrack;

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
                  child: _Back(vinyl: vinyl, onTrack: onTrack),
                )
              : CoverArt(vinyl: vinyl),
        );
      },
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.vinyl, required this.onTrack});
  final Vinyl vinyl;
  final ValueChanged<int> onTrack;

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
                itemBuilder: (_, i) => InkWell(
                  onTap: () => onTrack(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text('${i + 1}.  ${vinyl.tracks[i]}'),
                  ),
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
                Text(v.yearLabel, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(v.owned ? Icons.check : Icons.add),
                        label: Text(v.owned ? 'En colección' : 'Agregar'),
                        onPressed: () => store.toggleOwned(v.id),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                        onPressed: () {
                          PlayerService.instance.stopIf(v.id);
                          store.remove(v.id);
                          Navigator.of(context)
                            ..pop()
                            ..pop();
                        },
                      ),
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
