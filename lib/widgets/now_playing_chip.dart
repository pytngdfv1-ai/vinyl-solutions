import 'package:flutter/material.dart';

import '../audio/player_service.dart';
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

