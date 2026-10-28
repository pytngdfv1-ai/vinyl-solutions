import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/dj_engine.dart';
import '../data/playlists.dart';
import '../widgets/cover_art.dart';
import '../widgets/dj_table.dart';

/// DJ en vivo (horizontal): dos platos que suenan a la vez, crossfader, pitch por plato
/// y mezcla automática con solape. Toca los controles de la mesa o los botones de abajo.
class DjLiveScreen extends StatefulWidget {
  const DjLiveScreen({super.key, required this.playlist, required this.shuffle});
  final Playlist playlist;
  final bool shuffle;

  @override
  State<DjLiveScreen> createState() => _DjLiveScreenState();
}

class _DjLiveScreenState extends State<DjLiveScreen> {
  final _dj = DjEngine();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final q = [...widget.playlist.entries];
    if (widget.shuffle) q.shuffle(Random());
    _dj.start(q).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _dj.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _top(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _ready ? DjTable(feed: _dj) : const Center(child: CircularProgressIndicator()),
              ),
            ),
            SizedBox(
              height: 104,
              child: Row(
                children: [
                  _DeckBar(dj: _dj, d: 0),
                  Expanded(child: _Queue(dj: _dj)),
                  _DeckBar(dj: _dj, d: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _top() => AnimatedBuilder(
        animation: _dj,
        builder: (_, __) => SizedBox(
          height: 44,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
              Expanded(
                child: Text(
                  'DJ en vivo · ${widget.playlist.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Text('Auto-mix', style: TextStyle(fontSize: 12)),
              Switch(value: _dj.autoMix, onChanged: _dj.setAuto),
              PopupMenuButton<int>(
                tooltip: 'Duración del fundido',
                initialValue: _dj.fadeSecs,
                onSelected: _dj.setFade,
                itemBuilder: (_) => [
                  for (final s in const [4, 8, 12, 16]) PopupMenuItem(value: s, child: Text('Fundido de $s s')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${_dj.fadeSecs} s', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              if (_dj.error != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(message: _dj.error!, child: const Icon(Icons.warning_amber, color: Colors.amber, size: 18)),
                ),
            ],
          ),
        ),
      );
}

/// Cue, play/pausa y pitch del plato.
class _DeckBar extends StatelessWidget {
  const _DeckBar({required this.dj, required this.d});
  final DjEngine dj;
  final int d;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AnimatedBuilder(
        animation: dj,
        builder: (_, __) {
          final dk = dj.decks[d];
          final pct = dk.pitch * 8;
          return Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('PLATO ${d == 0 ? 'A' : 'B'}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                Text(dk.entry?.title ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(tooltip: 'Cue (volver al inicio)', icon: const Icon(Icons.first_page), onPressed: () => dj.cue(d)),
                    StreamBuilder<PlayerState>(
                      stream: dk.player.playerStateStream,
                      builder: (_, s) => IconButton.filled(
                        icon: Icon((s.data?.playing ?? false) ? Icons.pause : Icons.play_arrow),
                        onPressed: dk.entry == null ? null : () => dj.toggle(d),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => dj.setPitch(d, 0),
                  child: Text('Pitch ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %',
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lo que viene: lo cargado en cada plato y la cola.
class _Queue extends StatelessWidget {
  const _Queue({required this.dj});
  final DjEngine dj;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dj,
      builder: (_, __) {
        final items = <(String, PlEntry)>[
          for (var d = 0; d < 2; d++)
            if (dj.decks[d].entry != null) (d == 0 ? 'A' : 'B', dj.decks[d].entry!),
          for (var i = dj.nextIndex; i < dj.queue.length; i++) ('${i - dj.nextIndex + 1}', dj.queue[i]),
        ];
        if (items.isEmpty) {
          return const Center(child: Text('Fin de la playlist', style: TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final tag = items[i].$1;
            final e = items[i].$2;
            final deck = tag == 'A' || tag == 'B';
            return SizedBox(
              width: 120,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        border: Border.all(color: deck ? const Color(0xFFE8C14A) : Colors.white12, width: deck ? 2 : 1)),
                    child: CoverArt(vinyl: e.asVinyl(), radius: 0),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deck ? 'PLATO $tag' : 'COLA $tag',
                            style: TextStyle(fontSize: 9, color: deck ? const Color(0xFFE8C14A) : Colors.white38)),
                        Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
