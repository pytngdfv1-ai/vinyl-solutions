import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/koofr_settings.dart';
import '../data/playlists.dart';
import 'dj_feed.dart';
import 'player_service.dart';

class DjDeck {
  final AudioPlayer player = AudioPlayer();
  PlEntry? entry;

  /// -1..1 → ±8 % de velocidad.
  double pitch = 0;
  double get speed => 1 + pitch * 0.08;
}

/// DJ real: dos reproductores a la vez (uno por plato), crossfader con curva de
/// potencia constante, pitch por plato y mezcla automática con solape.
class DjEngine extends ChangeNotifier implements DjFeed {
  final List<DjDeck> decks = [DjDeck(), DjDeck()];
  List<PlEntry> queue = const [];
  int _next = 0;

  double _xf = 0;
  bool autoMix = true;
  int fadeSecs = 8;
  String? error;

  bool _mixing = false;
  double _mixFrom = 0, _mixTo = 0;
  DateTime _mixStart = DateTime.now();
  Timer? _timer;
  bool _busy = false;

  /// Próximo tema de la cola que aún no está en ningún plato.
  int get nextIndex => _next;

  Future<void> start(List<PlEntry> q) async {
    await PlayerService.instance.stop(); // silencia el reproductor normal
    queue = q;
    _next = 0;
    _xf = 0;
    await _load(0);
    await _load(1);
    _applyVolumes();
    if (decks[0].entry != null) unawaited(decks[0].player.play());
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
    notifyListeners();
  }

  Future<void> _load(int d, {int tries = 0}) async {
    final dk = decks[d];
    if (_next >= queue.length) {
      dk.entry = null;
      await dk.player.stop();
      notifyListeners();
      return;
    }
    final e = queue[_next++];
    dk.entry = e;
    try {
      final src = e.url.startsWith('file:')
          ? AudioSource.uri(Uri.parse(e.url))
          : LockCachingAudioSource(Uri.parse(e.url), headers: KoofrSettings.headersFor(e.url));
      await dk.player.setAudioSource(src);
      await _applyRate(dk);
    } catch (err) {
      error = 'No se pudo cargar "${e.title}"';
      if (tries < 3) return _load(d, tries: tries + 1); // salta ese tema
      dk.entry = null;
    }
    notifyListeners();
  }

  Future<void> _applyRate(DjDeck dk) async {
    await dk.player.setSpeed(dk.speed);
    await dk.player.setPitch(dk.speed); // como un plato de vinilo: cambia velocidad y tono
  }

  void _applyVolumes() {
    final a = math.cos(_xf * math.pi / 2);
    final b = math.sin(_xf * math.pi / 2);
    decks[0].player.setVolume(a.clamp(0.0, 1.0).toDouble());
    decks[1].player.setVolume(b.clamp(0.0, 1.0).toDouble());
  }

  bool _completed(DjDeck d) => d.player.processingState == ProcessingState.completed;

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      if (_mixing) {
        final t = (DateTime.now().difference(_mixStart).inMilliseconds / (fadeSecs * 1000)).clamp(0.0, 1.0).toDouble();
        _xf = _mixFrom + (_mixTo - _mixFrom) * t;
        _applyVolumes();
        if (t >= 1) {
          _mixing = false;
          await _retire(_mixTo == 1 ? 0 : 1);
        }
        return;
      }
      if (!autoMix) return;
      final active = _xf < 0.5 ? 0 : 1;
      final dk = decks[active];
      final other = decks[1 - active];
      if (other.entry == null || other.player.playing) return;
      final dur = dk.player.duration?.inMilliseconds ?? 0;
      final pos = dk.player.position.inMilliseconds;
      final fade = fadeSecs * 1000;
      if (_completed(dk) && !dk.player.playing) {
        // Tema muy corto o sin solape: pasa directo al otro plato.
        _xf = active == 0 ? 1 : 0;
        _applyVolumes();
        unawaited(other.player.play());
        await _retire(active);
        return;
      }
      if (dk.player.playing && dur > fade * 2 && dur - pos <= fade) {
        unawaited(other.player.play());
        _mixing = true;
        _mixFrom = _xf;
        _mixTo = active == 0 ? 1 : 0;
        _mixStart = DateTime.now();
      }
    } finally {
      _busy = false;
    }
  }

  /// El plato [d] terminó su parte: se detiene y carga el siguiente tema de la cola.
  Future<void> _retire(int d) async {
    await decks[d].player.pause();
    await _load(d);
  }

  // ---------- mandos ----------
  Future<void> toggle(int d) async {
    final dk = decks[d];
    if (dk.entry == null) return;
    if (dk.player.playing) {
      await dk.player.pause();
    } else {
      if (_completed(dk)) await dk.player.seek(Duration.zero);
      unawaited(dk.player.play());
    }
    notifyListeners();
  }

  Future<void> cue(int d) async {
    await decks[d].player.pause();
    await decks[d].player.seek(Duration.zero);
    notifyListeners();
  }

  void setPitch(int d, double v) {
    decks[d].pitch = v.clamp(-1.0, 1.0).toDouble();
    unawaited(_applyRate(decks[d]));
    notifyListeners();
  }

  void setXf(double v) {
    _mixing = false; // el DJ toma el control
    _xf = v.clamp(0.0, 1.0).toDouble();
    _applyVolumes();
  }

  void setAuto(bool on) {
    autoMix = on;
    notifyListeners();
  }

  void setFade(int s) {
    fadeSecs = s;
    notifyListeners();
  }

  // ---------- DjFeed ----------
  @override
  PlEntry? entry(int d) => decks[d].entry;
  @override
  bool spinning(int d) => decks[d].entry != null && decks[d].player.playing && !_completed(decks[d]);
  @override
  double rate(int d) => decks[d].speed;
  @override
  bool armDown(int d) =>
      decks[d].entry != null && (decks[d].player.playing || decks[d].player.position.inMilliseconds > 800);
  @override
  double progress(int d) {
    final dur = decks[d].player.duration?.inMilliseconds ?? 0;
    return dur > 0 ? (decks[d].player.position.inMilliseconds / dur).clamp(0.0, 1.0).toDouble() : 0.0;
  }

  @override
  double get xf => _xf;
  @override
  double pitch(int d) => decks[d].pitch;
  @override
  bool get interactive => true;
  @override
  void onPlatter(int d) => toggle(d);
  @override
  void onXf(double v) => setXf(v);
  @override
  void onPitch(int d, double v) => setPitch(d, v);

  @override
  void dispose() {
    _timer?.cancel();
    for (final d in decks) {
      d.player.dispose();
    }
    super.dispose();
  }
}
