import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/playlists.dart';
import 'app_audio.dart';
import 'dj_engine.dart';

/// Sesión de DJ en vivo que sigue sonando aunque salgas de la pantalla del DJ.
class DjSession {
  static final ValueNotifier<DjEngine?> active = ValueNotifier<DjEngine?>(null);
  static String name = '';

  /// Empieza una sesión nueva (cierra la anterior) con la playlist en orden o aleatoria.
  static Future<DjEngine> begin(Playlist p, {required bool shuffle}) async {
    await stop();
    final q = [...p.entries];
    if (shuffle) q.shuffle(Random());
    final e = DjEngine();
    name = p.name;
    active.value = e;
    AppAudio.instance?.attachDj(e);
    unawaited(e.start(q));
    return e;
  }

  /// Detiene la sesión (si hay una).
  static Future<void> stop() async {
    final e = active.value;
    if (e == null) return;
    active.value = null;
    AppAudio.instance?.detachDj();
    e.shutdown();
  }
}
