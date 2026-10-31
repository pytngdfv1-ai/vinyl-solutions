import 'package:flutter/material.dart';

import 'package:just_audio/just_audio.dart';

import '../audio/dj_engine.dart';
import '../audio/dj_session.dart';
import '../audio/player_service.dart';
import '../screens/dj_live_screen.dart';
import '../models/vinyl.dart';
import 'cover_art.dart';

/// Mini reproductor: muestra lo que suena mientras buscas otro disco.
class NowPlayingChip extends StatelessWidget {
  const NowPlayingChip({super.key, required this.onOpen});

  final ValueChanged<Vinyl> onOpen;

  @override
  Widget build(BuildContext context) {
    final audio = PlayerService.instance;
    final p = audio.player;
    return ValueListenableBuilder<DjEngine?>(
      valueListenable: DjSession.active,
      builder: (context, dj, _) => dj != null ? _djChip(context, dj) : _normal(context, audio, p),
    );
  }

  /// Cápsula del DJ en vivo: el tema que suena, play/pausa y atajo para volver a la mesa.
  Widget _djChip(BuildContext context, DjEngine dj) {
    return AnimatedBuilder(
      animation: dj,
      builder: (_, __) {
        final e = dj.decks[dj.activeDeck].entry ?? dj.decks[1 - dj.activeDeck].entry;
        return Material(
          color: const Color(0xDD1E1E1E),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => DjLiveScreen(engine: dj, name: DjSession.name)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 2, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: e == null ? const Icon(Icons.album) : ClipOval(child: CoverArt(vinyl: e.asVinyl(), radius: 0)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'DJ · ${e?.title ?? DjSession.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(dj.anyPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () => dj.anyPlaying ? dj.pauseAll() : dj.resumeAll(),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Detener el DJ',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: DjSession.stop,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _normal(BuildContext context, PlayerService audio, AudioPlayer p) {
    return ValueListenableBuilder<Vinyl?>(
      valueListenable: audio.nowPlaying,
      builder: (_, v, __) {
        if (v == null) return const SizedBox.shrink();
        return Material(
          color: const Color(0xDD1E1E1E),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => onOpen(v),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 2, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 32, height: 32, child: ClipOval(child: CoverArt(vinyl: v, radius: 0))),
                  const SizedBox(width: 8),
                  Flexible(
                    child: StreamBuilder<int?>(
                      stream: p.currentIndexStream,
                      builder: (_, s) {
                        final i = s.data ?? 0;
                        return Text(
                          i < v.tracks.length ? v.tracks[i] : v.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: p.playingStream,
                    initialData: p.playing,
                    builder: (_, s) => IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon((s.data ?? false) ? Icons.pause : Icons.play_arrow),
                      onPressed: () => (s.data ?? false) ? p.pause() : p.play(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

