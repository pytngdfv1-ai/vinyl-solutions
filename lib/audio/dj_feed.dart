import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/playlists.dart';
import 'player_service.dart';
import 'playlist_player.dart';

/// Lo que la mesa de DJ necesita saber para dibujarse (y, si es interactiva, para recibir toques).
abstract class DjFeed implements Listenable {
  /// Qué tema hay cargado en el plato [d] (0 = izquierdo, 1 = derecho).
  PlEntry? entry(int d);

  /// ¿El disco gira?
  bool spinning(int d);

  /// Velocidad relativa (1 = normal).
  double rate(int d);

  /// ¿El brazo está sobre el disco?
  bool armDown(int d);

  /// Avance del tema (0..1).
  double progress(int d);

  /// Crossfader: 0 = plato izquierdo, 1 = plato derecho.
  double get xf;

  /// Cursor del pitch (-1..1).
  double pitch(int d);

  bool get interactive => false;
  void onPlatter(int d) {}
  void onXf(double v) {}
  void onPitch(int d, double v) {}
}

/// Playlist encadenada normal: los platos se turnan (par → izquierdo, impar → derecho).
class PlaylistFeed extends ChangeNotifier implements DjFeed {
  PlaylistFeed() {
    _sub = PlayerService.instance.player.currentIndexStream.listen((_) => notifyListeners());
    PlaylistPlayer.instance.session.addListener(notifyListeners);
  }

  late final StreamSubscription<int?> _sub;
  final _p = PlayerService.instance.player;

  List<PlEntry> get _list => PlaylistPlayer.instance.session.value?.entries ?? const [];
  int get _ci => _p.currentIndex ?? 0;

  @override
  PlEntry? entry(int d) {
    final i = _ci % 2 == d ? _ci : _ci + 1;
    return i >= 0 && i < _list.length ? _list[i] : null;
  }

  @override
  bool spinning(int d) => _ci % 2 == d && _p.playing;
  @override
  double rate(int d) => 1;
  @override
  bool armDown(int d) => _ci % 2 == d;
  @override
  double progress(int d) {
    if (_ci % 2 != d) return 0;
    final dur = _p.duration?.inMilliseconds ?? 0;
    return dur > 0 ? (_p.position.inMilliseconds / dur).clamp(0.0, 1.0).toDouble() : 0.0;
  }

  @override
  double get xf => _ci % 2 == 0 ? 0 : 1;
  @override
  double pitch(int d) => 0;
  @override
  bool get interactive => false;
  @override
  void onPlatter(int d) {}
  @override
  void onXf(double v) {}
  @override
  void onPitch(int d, double v) {}

  @override
  void dispose() {
    _sub.cancel();
    PlaylistPlayer.instance.session.removeListener(notifyListeners);
    super.dispose();
  }
}
