import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/library_settings.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import 'stage_screen.dart';

/// Abre la pantalla del disco (tocadisco).
void openStage(BuildContext context, VinylStore store, Vinyl v) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => StageScreen(store: store, vinyl: v),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Agrega un disco a mano (biblioteca "Manuales").
Future<void> addDisc(BuildContext context, VinylStore store) async {
  final r = await showDialog<(String, String, int)>(
    context: context,
    builder: (_) => const AddDiscDialog(),
  );
  if (r != null) await store.add(artist: r.$1, title: r.$2, year: r.$3);
}

Future<void> showLibrarySettings(BuildContext context) async {
  var value = LibrarySettings.minTracks.toDouble();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Ajustes de biblioteca'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mínimo de temas por álbum: ${value.round()}'),
            const SizedBox(height: 4),
            const Text(
              'Las carpetas con menos temas (singles, temas sueltos) se ignoran '
              'al sincronizar o agregar una carpeta.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Slider(
              value: value,
              min: 1,
              max: 15,
              divisions: 14,
              label: '${value.round()}',
              onChanged: (v) => setLocal(() => value = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) await LibrarySettings.save(value.round());
}

Future<void> confirmClearLibrary(BuildContext context, VinylStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Borrar biblioteca'),
      content: const Text(
        'Se borrarán todos los discos de la app. Tus archivos en Koofr no se tocan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await PlayerService.instance.stop();
    await store.clearAll();
  }
}


class AddDiscDialog extends StatefulWidget {
  const AddDiscDialog();

  @override
  State<AddDiscDialog> createState() => AddDiscDialogState();
}

class AddDiscDialogState extends State<AddDiscDialog> {
  final _artist = TextEditingController();
  final _title = TextEditingController();
  final _year = TextEditingController();

  @override
  void dispose() {
    _artist.dispose();
    _title.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar disco'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _artist, decoration: const InputDecoration(labelText: 'Artista')),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
          TextField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Año'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final a = _artist.text.trim();
            final t = _title.text.trim();
            if (a.isEmpty || t.isEmpty) return;
            Navigator.of(context).pop((a, t, int.tryParse(_year.text.trim()) ?? DateTime.now().year));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
