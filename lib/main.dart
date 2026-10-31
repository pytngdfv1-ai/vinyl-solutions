import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio/app_audio.dart';
import 'audio/dj_session.dart';
import 'audio/player_service.dart';
import 'data/booklet_lite.dart';
import 'data/cajon.dart';
import 'data/discogs.dart';
import 'data/koofr_settings.dart';
import 'data/library_settings.dart';
import 'data/library_sync.dart';
import 'data/playlists.dart';
import 'data/vinyl_store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = VinylStore();
  await store.load();
  await LibrarySettings.load();
  await ChestNames.load();
  await Discogs.load();
  await BookletLite.load();
  await KoofrAccounts.load();
  await Playlists.instance.load();
  try {
    await AppAudio.init();
  } catch (_) {}
  PlayerService.beforeStart = DjSession.stop;
  runApp(VinylApp(store: store));
  // Android 13+: permiso para mostrar los controles en la notificación.
  Permission.notification.request();
  // Sincroniza las nubes al abrir (en segundo plano).
  LibrarySync.syncAll(store);
}

class VinylApp extends StatelessWidget {
  const VinylApp({super.key, required this.store});

  final VinylStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Biblioteca',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(store: store),
    );
  }
}
