import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/dj_feed.dart';
import '../audio/player_service.dart';
import '../audio/playlist_player.dart';
import '../data/playlists.dart';
import '../widgets/cover_art.dart';
import '../widgets/dj_table.dart';

/// Modo DJ (pantalla horizontal): arriba la mesa con dos platos, abajo la portada
/// del tema que suena y, a su derecha, las siguientes hasta terminar la playlist.
class DjScreen extends StatefulWidget {
  const DjScreen({super.key});

  @override
  State<DjScreen> createState() => _DjScreenState();
}

class _DjScreenState extends State<DjScreen> {
  final _audio = PlayerService.instance;
  final _feed = PlaylistFeed();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _feed.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: ValueListenableBuilder<PlSession?>(
          valueListenable: PlaylistPlayer.instance.session,
          builder: (_, s, __) {
            if (s == null || !PlaylistPlayer.isPlaylist(_audio.nowPlaying.value)) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No hay una playlist sonando', style: TextStyle(color: Colors.white70)),
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver')),
                  ],
                ),
              );
            }
            return Column(
              children: [
                _TopBar(session: s, audio: _audio),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: DjTable(feed: _feed))),
                _Strip(session: s, audio: _audio),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.audio});
  final PlSession session;
  final PlayerService audio;

  @override
  Widget build(BuildContext context) {
    final p = audio.player;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
          Expanded(
            child: Text(
              '${session.name} · ${session.shuffled ? 'aleatoria' : 'en orden'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: StreamBuilder<Duration>(
              stream: p.positionStream,
              builder: (_, s) {
                final dur = p.duration?.inMilliseconds.toDouble() ?? 0;
                final pos = (s.data ?? Duration.zero).inMilliseconds.toDouble();
                return Slider(
                  value: dur > 0 ? pos.clamp(0.0, dur).toDouble() : 0,
                  max: dur > 0 ? dur : 1,
                  onChanged: (x) => p.seek(Duration(milliseconds: x.round())),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: () => audio.goTrack((p.currentIndex ?? 0) - 1),
          ),
          StreamBuilder<bool>(
            stream: p.playingStream,
            initialData: p.playing,
            builder: (_, s) => IconButton.filled(
              icon: Icon((s.data ?? false) ? Icons.pause : Icons.play_arrow),
              onPressed: () => (s.data ?? false) ? p.pause() : p.play(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: () => audio.goTrack((p.currentIndex ?? 0) + 1),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Portada del tema actual y, a la derecha, las que vienen después.
class _Strip extends StatelessWidget {
  const _Strip({required this.session, required this.audio});
  final PlSession session;
  final PlayerService audio;

  @override
  Widget build(BuildContext context) {
    final p = audio.player;
    return SizedBox(
      height: 112,
      child: StreamBuilder<int?>(
        stream: p.currentIndexStream,
        initialData: p.currentIndex,
        builder: (_, ix) {
          final ci = (ix.data ?? 0).clamp(0, session.entries.length - 1).toInt();
          final rest = session.entries.sublist(ci);
          return ListView.separated(
            key: ValueKey(ci),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            itemCount: rest.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final e = rest[i];
              final now = i == 0;
              final size = now ? 76.0 : 58.0;
              return GestureDetector(
                onTap: now ? null : () => audio.goTrack(ci + i),
                child: SizedBox(
                  width: now ? 150 : 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          border: Border.all(color: now ? const Color(0xFFE8C14A) : Colors.white12, width: now ? 2 : 1),
                        ),
                        child: CoverArt(vinyl: e.asVinyl(), radius: 0),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(now ? 'SUENA' : '$i', style: TextStyle(fontSize: 9, color: now ? const Color(0xFFE8C14A) : Colors.white38)),
                            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: now ? 12 : 11, fontWeight: FontWeight.w600)),
                            Text(e.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
