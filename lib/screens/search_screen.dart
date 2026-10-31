import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import 'library_actions.dart';

/// Buscador general: discos por artista o título, y temas por nombre.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.store});
  final VinylStore store;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _Hit {
  const _Hit(this.v, this.track);
  final Vinyl v;

  /// Índice del tema encontrado (null = el resultado es el disco).
  final int? track;
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  String _q = '';

  static String _n(String s) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    var t = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      t = t.replaceAll(from[i], to[i]);
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  (List<_Hit>, List<_Hit>) _search() {
    final words = _n(_q).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return (const [], const []);
    bool all(String hay) => words.every(hay.contains);
    final discs = <_Hit>[];
    final tracks = <_Hit>[];
    final seen = <String>{};
    for (final v in widget.store.items) {
      if (v.isDivider || !seen.add(v.id)) continue;
      if (all(_n('${v.artist} ${v.title} ${v.genre ?? ''} ${v.year > 0 ? v.year : ''}'))) {
        discs.add(_Hit(v, null));
      }
      for (var i = 0; i < v.tracks.length && tracks.length < 80; i++) {
        if (!v.hasAudio) break;
        if (all(_n('${v.tracks[i]} ${v.artist}'))) tracks.add(_Hit(v, i));
      }
    }
    discs.sort((a, b) => a.v.artist.toLowerCase().compareTo(b.v.artist.toLowerCase()));
    return (discs.take(60).toList(), tracks);
  }

  Future<void> _openTrack(_Hit h) async {
    final audio = PlayerService.instance;
    final i = h.track ?? 0;
    try {
      if (audio.nowPlaying.value?.id == h.v.id) {
        await audio.goTrack(i);
      } else {
        await audio.start(h.v, index: i);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo reproducir: $e')));
    }
    if (mounted) openStage(context, widget.store, h.v);
  }

  @override
  Widget build(BuildContext context) {
    final (discs, tracks) = _search();
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        title: TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar artista, disco o tema',
            border: InputBorder.none,
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _c.clear();
                      _q = '';
                    }),
                  ),
          ),
          onChanged: (t) => setState(() => _q = t),
        ),
      ),
      body: _q.trim().isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Escribe para buscar en toda tu biblioteca.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              ),
            )
          : (discs.isEmpty && tracks.isEmpty)
              ? const Center(child: Text('Sin resultados', style: TextStyle(color: Colors.white60)))
              : ListView(
                  children: [
                    if (discs.isNotEmpty) _head('Discos (${discs.length})'),
                    for (final h in discs)
                      ListTile(
                        leading: SizedBox(width: 48, height: 48, child: CoverArt(vinyl: h.v)),
                        title: Text(h.v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${h.v.artist}${h.v.year > 0 ? ' · ${h.v.year}' : ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => openStage(context, widget.store, h.v),
                      ),
                    if (tracks.isNotEmpty) _head('Temas (${tracks.length})'),
                    for (final h in tracks)
                      ListTile(
                        leading: SizedBox(width: 48, height: 48, child: CoverArt(vinyl: h.v)),
                        title: Text(h.v.tracks[h.track!], maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${h.v.artist} · ${h.v.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () => _openTrack(h),
                      ),
                  ],
                ),
    );
  }

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(color: AppColors.gold, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
      );
}
