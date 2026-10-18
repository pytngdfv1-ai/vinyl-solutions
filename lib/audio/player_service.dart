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
    final source = ConcatenatingAudioSource(
      children: [
        for (final url in v.trackUrls)
          AudioSource.uri(Uri.parse(url), headers: KoofrSettings.activeHeaders),
      ],
    );
    await player.setAudioSource(source, initialIndex: index);
    _loadedId = v.id;
  }

  Future<void> stop() async {
    _loadedId = null;
    await player.stop();
  }
}
