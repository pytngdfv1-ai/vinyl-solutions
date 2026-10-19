import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../data/koofr_settings.dart';
import '../models/vinyl.dart';

/// Reproductor único (streaming FLAC desde Koofr).
class PlayerService {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer player = AudioPlayer();
  String? _loadedId;

  Future<void> load(Vinyl v, {int index = 0}) async {
    if (_loadedId == v.id) {
      await player.seek(Duration.zero, index: index);
      return;
    }
    if (!v.trackUrls[index].startsWith('file:')) await _preflight(v.trackUrls[index]);
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
    await player.setAudioSource(source, initialIndex: index);
    _loadedId = v.id;
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

  Future<void> stop() async {
    _loadedId = null;
    await player.stop();
  }
}
