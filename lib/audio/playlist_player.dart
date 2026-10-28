import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/playlists.dart';
import '../models/vinyl.dart';
import 'player_service.dart';

/// Sesión de playlist en marcha: temas en el orden en que suenan.
class PlSession {
  PlSession(this.name, this.entries, this.shuffled);
  final String name;
  final List<PlEntry> entries;
  final bool shuffled;
}

/// Reproduce una playlist encadenada (un tema detrás de otro, sin pausas),
/// en orden o aleatoria, usando el mismo reproductor de la app.
class PlaylistPlayer {
  PlaylistPlayer._();
  static final PlaylistPlayer instance = PlaylistPlayer._();

  static const idPrefix = 'pl_';
  final ValueNotifier<PlSession?> session = ValueNotifier<PlSession?>(null);

  Future<void> play(Playlist pl, {bool shuffle = false, int start = 0}) async {
    if (pl.entries.isEmpty) return;
    final list = [...pl.entries];
    if (shuffle) list.shuffle(Random());
    final v = Vinyl(
      id: '$idPrefix${pl.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: pl.name,
      artist: shuffle ? 'Playlist · aleatoria' : 'Playlist',
      year: 0,
      hue: list.first.hue,
      tracks: [for (final e in list) e.title],
      trackUrls: [for (final e in list) e.url],
      coverUrl: list.first.cover,
    );
    session.value = PlSession(pl.name, list, shuffle);
    try {
      await PlayerService.instance.start(v, index: start, chain: true);
    } catch (e) {
      session.value = null;
      rethrow;
    }
  }

  /// ¿Lo que suena es una playlist?
  static bool isPlaylist(Vinyl? v) => v != null && v.id.startsWith(idPrefix);
}
