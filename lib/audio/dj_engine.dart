import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/koofr_settings.dart';
import '../data/playlists.dart';
import 'dj_feed.dart';
import 'player_service.dart';
import 'track_analyzer.dart';

class DjDeck {
  final AudioPlayer player = AudioPlayer();
  PlEntry? entry;

  /// -1..1 → ±8 % de velocidad.
  double pitch = 0;
  double get speed => 1 + pitch * 0.08;

  /// Tempo y arranque del tema cargado (AutoDJ).
  TrackInfo? info;

  /// El pitch lo puso el AutoDJ (se va relajando a 0); si lo toca el DJ, deja de relajarse.
  bool synced = false;
}

/// DJ real: dos reproductores a la vez (uno por plato), crossfader con curva de
/// potencia constante, pitch por plato y mezcla automática con solape.
class DjEngine extends ChangeNotifier implements DjFeed {
  final List<DjDeck> decks = [DjDeck(), DjDeck()];
  List<PlEntry> queue = const [];
  int _next = 0;

  double _xf = 0;
  bool autoMix = true;

  /// AutoDJ: analiza el tempo, ordena por tempo, ajusta el siguiente al que suena y salta el silencio inicial.
  bool autoDj = false;
  final List<bool> _loadingDeck = [false, false];
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
    await _load(0, first: true);
    _applyVolumes();
    if (decks[0].entry != null) unawaited(decks[0].player.play());
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
    notifyListeners();
    unawaited(_load(1)); // el plato B se prepara mientras suena A
  }

  Future<void> _load(int d, {int tries = 0, bool first = false}) async {
    final dk = decks[d];
    _loadingDeck[d] = true;
    try {
      dk.info = null;
      dk.synced = false;
      dk.pitch = 0;
      if (_next >= queue.length) {
        dk.entry = null;
        await dk.player.stop();
        notifyListeners();
        return;
      }
      if (autoDj && !first) await _pickByTempo(decks[1 - d]);
      final e = queue[_next++];
      dk.entry = e;
      notifyListeners();
      try {
        final src = e.url.startsWith('file:')
            ? AudioSource.uri(Uri.parse(e.url))
            : LockCachingAudioSource(Uri.parse(e.url), headers: KoofrSettings.headersFor(e.url));
        await dk.player.setAudioSource(src);
        await _applyRate(dk);
      } catch (err) {
        error = 'No se pudo cargar "${e.title}"';
        if (tries < 3) {
          _loadingDeck[d] = false;
          return _load(d, tries: tries + 1);
        }
        dk.entry = null;
      }
      if (autoDj && dk.entry != null) {
        unawaited(TrackAnalyzer.analyze(e.url).then((i) {
          if (dk.entry == e) {
            dk.info = i;
            notifyListeners();
          }
        }));
      }
    } finally {
      _loadingDeck[d] = false;
    }
    notifyListeners();
  }

  /// Entre los próximos temas de la cola elige el de tempo más cercano al que suena y lo pone primero.
  Future<void> _pickByTempo(DjDeck ref) async {
    final ri = ref.info ?? (ref.entry == null ? null : await TrackAnalyzer.analyze(ref.entry!.url));
    if (ri == null || ri.bpm <= 0) return;
    final end = math.min(queue.length, _next + 5);
    if (end - _next < 2) return;
    final cands = queue.sublist(_next, end);
    final infos = await Future.wait([
      for (final c in cands) TrackAnalyzer.analyze(c.url).timeout(const Duration(seconds: 40), onTimeout: () => null),
    ]);
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < cands.length; i++) {
      final b = infos[i]?.bpm ?? 0;
      if (b <= 0) continue;
      final diff = _bpmDistance(ri.bpm, b);
      if (diff < bestDiff - 0.001) {
        bestDiff = diff;
        best = i;
      }
    }
    if (best > 0) {
      final e = queue.removeAt(_next + best);
      queue.insert(_next, e);
    }
  }

  /// Distancia relativa entre tempos (la mitad o el doble cuentan como iguales).
  static double _bpmDistance(double a, double b) {
    var best = double.infinity;
    for (final m in const [0.5, 1.0, 2.0]) {
      best = math.min(best, ((a - b * m).abs() / a));
    }
    return best;
  }

  /// Ajusta el tempo del plato entrante al del que sale y lo arranca donde empieza el sonido.
  Future<void> _prepareIncoming(DjDeck out, DjDeck inc) async {
    if (!autoDj) return;
    final oi = out.info;
    final ii = inc.info;
    if (ii != null) {
      final s = math.max(0, ii.startMs - 150);
      if (s > 0) await inc.player.seek(Duration(milliseconds: s));
    }
    if (oi == null || ii == null || oi.bpm <= 0 || ii.bpm <= 0) return;
    final target = oi.bpm * out.speed;
    for (final m in const [1.0, 0.5, 2.0]) {
      final rate = target / (ii.bpm * m);
      if (rate >= 0.92 && rate <= 1.08) {
        inc.pitch = ((rate - 1) / 0.08).clamp(-1.0, 1.0).toDouble();
        inc.synced = true;
        await _applyRate(inc);
        notifyListeners();
        return;
      }
    }
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
          unawaited(_retire(_mixTo == 1 ? 0 : 1));
        }
        return;
      }
      _relax();
      if (!autoMix) return;
      final active = _xf < 0.5 ? 0 : 1;
      final dk = decks[active];
      final other = decks[1 - active];
      if (_loadingDeck[0] || _loadingDeck[1]) return;
      if (other.entry == null || other.player.playing) return;
      final dur = dk.player.duration?.inMilliseconds ?? 0;
      final pos = dk.player.position.inMilliseconds;
      final fade = fadeSecs * 1000;
      if (_completed(dk) && !dk.player.playing) {
        // Tema muy corto o sin solape: pasa directo al otro plato.
        _xf = active == 0 ? 1 : 0;
        _applyVolumes();
        await _prepareIncoming(dk, other);
        unawaited(other.player.play());
        unawaited(_retire(active));
        return;
      }
      if (dk.player.playing && dur > fade * 2 && dur - pos <= fade) {
        await _prepareIncoming(dk, other);
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
    _loadingDeck[d] = true;
    await decks[d].player.pause();
    decks[d].entry = null;
    notifyListeners();
    await _load(d);
  }

  /// El pitch puesto por el AutoDJ vuelve poco a poco a la velocidad normal del plato que suena.
  void _relax() {
    for (final dk in decks) {
      if (!dk.synced || dk.pitch == 0 || !dk.player.playing) continue;
      final step = 0.0625 * 0.08; // ≈ 0,5 % por segundo
      dk.pitch = dk.pitch.abs() <= step ? 0 : dk.pitch - step * dk.pitch.sign;
      unawaited(_applyRate(dk));
    }
  }

  // ---------- notificación / pantalla bloqueada ----------
  int get activeDeck => _xf < 0.5 ? 0 : 1;
  bool get anyPlaying => decks.any((d) => d.player.playing);
  List<int> _resume = [];

  Future<void> pauseAll() async {
    _resume = [for (var i = 0; i < 2; i++) if (decks[i].player.playing) i];
    for (final d in decks) {
      await d.player.pause();
    }
    notifyListeners();
  }

  Future<void> resumeAll() async {
    final l = _resume.isEmpty ? [activeDeck] : _resume;
    for (final i in l) {
      if (decks[i].entry != null) unawaited(decks[i].player.play());
    }
    notifyListeners();
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
    decks[d].synced = false;
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
    if (!on) autoDj = false;
    notifyListeners();
  }

  void setAutoDj(bool on) {
    autoDj = on;
    if (on) autoMix = true;
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
