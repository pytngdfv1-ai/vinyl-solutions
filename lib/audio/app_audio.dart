import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../data/koofr_settings.dart';
import '../data/playlists.dart';
import '../models/vinyl.dart';
import 'dj_engine.dart';
import 'player_service.dart';

/// Servicio de audio de la app: mantiene la música sonando con la pantalla apagada o la app
/// en segundo plano y muestra los controles en la notificación y en la pantalla de bloqueo.
/// Sirve al reproductor normal y, cuando está abierto, al DJ en vivo.
class AppAudio extends BaseAudioHandler with SeekHandler {
  AppAudio() {
    final ps = PlayerService.instance;
    ps.player.playbackEventStream.listen((_) => _pushMain());
    ps.player.currentIndexStream.listen((_) => _pushItemMain());
    ps.nowPlaying.addListener(_pushItemMain);
  }

  static AppAudio? instance;

  static Future<void> init() async {
    instance = await AudioService.init(
      builder: AppAudio.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'vinyl.solutions.audio',
        androidNotificationChannelName: 'Reproducción',
      ),
    );
  }

  final _ps = PlayerService.instance;
  DjEngine? _dj;
  Timer? _djTimer;

  // ---------- reproductor normal ----------
  AudioProcessingState _map(ProcessingState s) => switch (s) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

  void _pushMain() {
    if (_dj != null) return;
    final p = _ps.player;
    final has = _ps.nowPlaying.value != null;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (p.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: has ? _map(p.processingState) : AudioProcessingState.idle,
      playing: p.playing,
      updatePosition: p.position,
      bufferedPosition: p.bufferedPosition,
      speed: p.speed,
      queueIndex: p.currentIndex,
    ));
  }

  void _pushItemMain() {
    if (_dj != null) return;
    final v = _ps.nowPlaying.value;
    if (v == null) {
      mediaItem.add(null);
      return;
    }
    final i = _ps.player.currentIndex ?? 0;
    mediaItem.add(_item(
      id: '${v.id}#$i',
      title: i < v.tracks.length ? v.tracks[i] : v.title,
      artist: v.artist,
      album: v.title,
      cover: v.coverUrl,
      duration: _ps.player.duration,
    ));
    _pushMain();
  }

  MediaItem _item({
    required String id,
    required String title,
    required String artist,
    required String album,
    String? cover,
    Duration? duration,
  }) {
    Uri? art;
    Map<String, String>? headers;
    if (cover != null && (cover.startsWith('http') || cover.startsWith('file:'))) {
      art = Uri.parse(cover);
      headers = KoofrSettings.headersFor(cover);
    }
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: art,
      artHeaders: headers,
    );
  }

  // ---------- DJ en vivo ----------
  void attachDj(DjEngine e) {
    _dj = e;
    e.addListener(_pushDj);
    _djTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushDj());
    _pushDj();
  }

  void detachDj() {
    _dj?.removeListener(_pushDj);
    _djTimer?.cancel();
    _dj = null;
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
    mediaItem.add(null);
    _pushItemMain();
  }

  void _pushDj() {
    final e = _dj;
    if (e == null) return;
    final dk = e.decks[e.activeDeck];
    final en = dk.entry;
    if (en != null) {
      final cur = mediaItem.value;
      final id = '${en.url}#dj';
      if (cur?.id != id) {
        mediaItem.add(_item(
          id: id,
          title: en.title,
          artist: en.artist,
          album: en.album,
          cover: en.cover,
          duration: dk.player.duration,
        ));
      }
    }
    playbackState.add(PlaybackState(
      controls: [if (e.anyPlaying) MediaControl.pause else MediaControl.play],
      androidCompactActionIndices: const [0],
      processingState: AudioProcessingState.ready,
      playing: e.anyPlaying,
      updatePosition: dk.player.position,
      speed: 1,
    ));
  }

  // ---------- órdenes de la notificación ----------
  @override
  Future<void> play() async {
    if (_dj != null) return _dj!.resumeAll();
    await _ps.player.play();
  }

  @override
  Future<void> pause() async {
    if (_dj != null) return _dj!.pauseAll();
    await _ps.player.pause();
  }

  @override
  Future<void> skipToNext() async {
    if (_dj != null) return;
    await _ps.goTrack((_ps.player.currentIndex ?? 0) + 1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_dj != null) return;
    await _ps.goTrack((_ps.player.currentIndex ?? 0) - 1);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_dj != null) return;
    await _ps.player.seek(position);
  }

  @override
  Future<void> stop() async {
    if (_dj != null) {
      await _dj!.pauseAll();
      return;
    }
    await _ps.stop();
    await super.stop();
  }
}
