import 'package:flutter/material.dart';

import 'data/vinyl_store.dart';
import 'screens/crate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = VinylStore();
  await store.load();
  runApp(VinylApp(store: store));
}

class VinylApp extends StatelessWidget {
  const VinylApp({super.key, required this.store});

  final VinylStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VinylSolutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE53935),
      ),
      home: CrateScreen(store: store),
    );
  }
}
