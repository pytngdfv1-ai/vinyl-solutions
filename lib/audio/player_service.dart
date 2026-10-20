import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../data/koofr_settings.dart';
import '../models/vinyl.dart';

/// Reproductor único. La música sigue sonando aunque se cierre la pantalla
/// del disco (para buscar otro en la biblioteca).
class PlayerService {
  PlayerService._() {
    player.currentIndexStream.listen(_onIndex);
    player.processingStateStream.listen((st) {
      if (st == ProcessingState.completed) _onCompleted();
    });
  }
  static final PlayerService instance = PlayerService._();

  final AudioPlayer player = AudioPlayer();

  /// Disco cargado en el reproductor (null = nada).
  final ValueNotifier<Vinyl?> nowPlaying = ValueNotifier<Vinyl?>(null);

  String? _loadedId;
  int _lastIndex = 0;
  bool _changing = false;
  bool _loading = false;

  /// Carga el disco y empieza a sonar. Si ya está cargado, no hace nada.
  Future<void> start(Vinyl v) async {
    if (_loadedId == v.id || _loading) return;
    _loading = true;
    try {
      if (!v.trackUrls.first.startsWith('file:')) await _preflight(v.trackUrls.first);
      // LockCachingAudioSource descarga desde Dart (con credenciales) y sirve
      // el audio al reproductor; evita fallos de autenticación en redirecciones.
      final source = ConcatenatingAudioSource(
        children: [
          for (final url in v.trackUrls)
            url.startsWith('file:')
                ? AudioSource.uri(Uri.parse(url))
                : LockCachingAudioSource(Uri.parse(url), headers: KoofrSettings.activeHeaders),
        ],
      );
      _changing = false;
      _lastIndex = 0;
      await player.setAudioSource(source, initialIndex: 0);
      _loadedId = v.id;
      nowPlaying.value = v;
      unawaited(player.play());
    } finally {
      _loading = false;
    }
  }

  /// Comprueba que Koofr responde antes de reproducir (mensaje claro si falla).
  Future<void> _preflight(String url) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers.addAll({...KoofrSettings.activeHeaders, 'Range': 'bytes=0-1'});
      final res = await client.send(req).timeout(const Duration(seconds: 20));
      await res.stream.listen((_) {}).cancel();
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw Exception('Koofr respondió ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Cambio manual: el brazo vuelve al reposo, cambia el tema y baja de nuevo.
  Future<void> goTrack(int i) async {
    final v = nowPlaying.value;
    if (v == null || _changing || i < 0 || i >= v.trackUrls.length) return;
    _changing = true;
    await player.pause(); // el brazo se levanta
    await Future.delayed(const Duration(milliseconds: 900));
    _lastIndex = i;
    await player.seek(Duration.zero, index: i);
    await Future.delayed(const Duration(milliseconds: 300));
    _changing = false;
    unawaited(player.play()); // el brazo baja al borde exterior
  }

  /// El reproductor pasó solo al siguiente tema: repite la animación.
  void _onIndex(int? i) {
    if (i == null) return;
    final prev = _lastIndex;
    _lastIndex = i;
    if (_loadedId == null || prev == i || _changing) return;
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    _changing = true;
    await player.pause();
    await Future.delayed(const Duration(milliseconds: 900));
    await player.seek(Duration.zero);
    await Future.delayed(const Duration(milliseconds: 300));
    _changing = false;
    unawaited(player.play());
  }

  /// Terminó el último tema: el brazo vuelve al reposo.
  Future<void> _onCompleted() async {
    if (_changing || _loadedId == null) return;
    _changing = true;
    await player.pause();
    _lastIndex = 0;
    await player.seek(Duration.zero, index: 0);
    _changing = false;
  }

  Future<void> stop() async {
    _loadedId = null;
    _changing = false;
    nowPlaying.value = null;
    await player.stop();
  }

  /// Detiene la música si el disco indicado es el que suena.
  Future<void> stopIf(String id) async {
    if (nowPlaying.value?.id == id) await stop();
  }
}
