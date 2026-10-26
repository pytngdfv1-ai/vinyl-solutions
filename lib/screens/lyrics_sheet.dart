import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/classifier.dart';
import '../data/lyrics.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';

/// Letra del tema que suena: sincronizada (sigue la canción) o en texto plano.
/// Se baja de LRCLIB y queda guardada para verla sin internet.
class LyricsSheet extends StatefulWidget {
  const LyricsSheet({super.key, required this.store, required this.vinyl});

  final VinylStore store;
  final Vinyl vinyl;

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  static const _lineH = 54.0;

  final _audio = PlayerService.instance;
  final _scroll = ScrollController();
  StreamSubscription<int?>? _idxSub;
  Lyrics? _lyrics;
  bool _loading = true;
  int _track = 0;
  int _active = -1;

  Vinyl get v => widget.vinyl;

  @override
  void initState() {
    super.initState();
    _track = _audio.nowPlaying.value?.id == v.id ? (_audio.player.currentIndex ?? 0) : 0;
    _load();
    _idxSub = _audio.player.currentIndexStream.listen((i) {
      if (i != null && i != _track && _audio.nowPlaying.value?.id == v.id) {
        _track = i;
        _load();
      }
    });
  }

  @override
  void dispose() {
    _idxSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _lyrics = null;
      _active = -1;
    });
    final i = _track.clamp(0, v.tracks.length - 1);
    final secs = _audio.nowPlaying.value?.id == v.id ? _audio.player.duration?.inSeconds : null;
    final l = await LyricsService.get(
      v.artist,
      v.tracks[i],
      album: v.single ? null : v.title,
      seconds: secs,
    );
    if (!mounted || i != _track.clamp(0, v.tracks.length - 1)) return;
    setState(() {
      _lyrics = l;
      _loading = false;
    });
    // La letra ayuda a clasificar el idioma de lo que aún no lo tiene.
    if (l != null) {
      final now = widget.store.items.where((e) => e.id == v.id).firstOrNull;
      if (now != null && now.lang == null && !now.langManual) {
        final lang = Classifier.langFromText(l.plain);
        if (lang != null) widget.store.setAutoLang(v.id, lang);
      }
    }
  }

  void _follow(Duration pos, int count) {
    final l = _lyrics;
    if (l == null || !l.hasSynced) return;
    var idx = -1;
    for (var i = 0; i < l.synced.length; i++) {
      if (l.synced[i].at <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _active) {
      _active = idx;
      if (_scroll.hasClients && idx >= 0) {
        final target = (idx * _lineH - _scroll.position.viewportDimension / 2 + _lineH / 2)
            .clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = v.tracks.isEmpty ? v.title : v.tracks[_track.clamp(0, v.tracks.length - 1)];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(v.artist, style: const TextStyle(color: Colors.white60)),
            const Divider(height: 20),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final l = _lyrics;
    if (l == null) {
      return const Center(
        child: Text(
          'No hay letra para este tema\n(o no hay conexión y aún no está guardada)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    if (!l.hasSynced) {
      return SingleChildScrollView(
        child: Text(l.plain, style: const TextStyle(fontSize: 17, height: 1.5)),
      );
    }
    return StreamBuilder<Duration>(
      stream: _audio.player.positionStream,
      builder: (_, snap) {
        _follow(snap.data ?? Duration.zero, l.synced.length);
        return ListView.builder(
          controller: _scroll,
          itemCount: l.synced.length,
          itemExtent: _lineH,
          itemBuilder: (_, i) {
            final on = i == _active;
            return Center(
              child: Text(
                l.synced[i].text.isEmpty ? '♪' : l.synced[i].text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: on ? 20 : 16,
                  fontWeight: on ? FontWeight.w900 : FontWeight.w500,
                  color: on ? Colors.white : Colors.white38,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
