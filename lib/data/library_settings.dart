import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes de la biblioteca (se guardan en el teléfono).
class LibrarySettings {
  /// Mínimo de temas para considerar una carpeta como álbum completo.
  static int minTracks = 5;

  static const _key = 'min_tracks';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      minTracks = p.getInt(_key) ?? 5;
    } catch (_) {}
  }

  static Future<void> save(int value) async {
    minTracks = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_key, value);
    } catch (_) {}
  }
}
