import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/cloud_upload.dart';
import '../data/duplicates.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../theme.dart';

/// Álbumes o temas sueltos repetidos: sugiere qué copia conservar y quita las demás.
class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key, required this.store});
  final VinylStore store;

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  late List<DupGroup> _groups = Duplicates.find(widget.store.items);
  final Map<String, String> _keep = {}; // grupo → id de la copia que se conserva
  String? _busy;

  String _keepId(DupGroup g) => _keep[g.key] ?? Duplicates.keep(g).id;

  Future<void> _clean(DupGroup g) async {
    final keepId = _keepId(g);
    final drop = [for (final v in g.copies) if (v.id != keepId) v];
    final cloud = drop.where((v) => !CloudUpload.isLocal(v)).toList();
    final hasLocal = drop.any(CloudUpload.isLocal);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quitar ${drop.length} copia(s) de "${g.first.title}"'),
        content: Text([
          if (cloud.isNotEmpty) 'Nube: puedes moverlas a la carpeta "_duplicados" (recomendado) o borrarlas.',
          if (hasLocal) 'Teléfono: las copias locales se borran.',
          'Borrar no se puede deshacer.',
        ].join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          if (cloud.isNotEmpty)
            FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop('trash'), child: const Text('Mover a _duplicados')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop('delete'), child: const Text('Borrar')),
        ],
      ),
    );
    if (choice == null) return;
    setState(() => _busy = 'Quitando copias…');
    final removed = <String>[];
    final accounts = <String, dynamic>{};
    String? error;
    for (final v in drop) {
      try {
        await Duplicates.remove(v, trash: choice == 'trash');
        removed.add(v.id);
        final a = Duplicates.account(v);
        if (a != null) accounts[a.id] = a;
      } catch (e) {
        error = '$e';
      }
    }
    // Si la copia que se queda no tiene portada y la quitada sí, se la pasa.
    final kept = g.copies.firstWhere((v) => v.id == keepId);
    if (kept.coverUrl == null) {
      final c = drop.where((v) => removed.contains(v.id) && v.coverUrl != null).firstOrNull?.coverUrl;
      if (c != null && !c.contains('koofr.net')) await widget.store.setCover(kept.id, c);
    }
    final playing = PlayerService.instance.nowPlaying.value?.id;
    if (playing != null && removed.contains(playing)) await PlayerService.instance.stop();
    await widget.store.removeMany(removed);
    for (final a in accounts.values) {
      LibrarySync.refresh(a, widget.store);
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      _groups = Duplicates.find(widget.store.items);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null ? '${removed.length} copia(s) quitadas' : 'Error: $error'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(backgroundColor: AppColors.ink, title: Text('Duplicados (${_groups.length})')),
      body: Column(
        children: [
          if (_busy != null) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _groups.isEmpty
                ? const Center(
                    child: Text('No hay duplicados', style: TextStyle(color: Colors.white60)),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final g in _groups) _card(g),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(DupGroup g) {
    final keepId = _keepId(g);
    return Card(
      color: AppColors.panel,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${g.first.artist} — ${g.first.title}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Chip(
                  label: Text(g.exact ? 'Exacto' : 'Parecido', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(g.first.single ? 'Tema suelto' : 'Álbum', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            for (final v in g.copies)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: v.id,
                groupValue: keepId,
                onChanged: _busy != null ? null : (x) => setState(() => _keep[g.key] = x!),
                title: Text(Duplicates.where(v), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                subtitle: Text(_info(v), style: const TextStyle(fontSize: 11)),
                secondary: Text(v.id == keepId ? 'Conservar' : 'Quitar',
                    style: TextStyle(color: v.id == keepId ? AppColors.gold : Colors.redAccent, fontSize: 12)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Quitar las otras'),
                onPressed: _busy != null ? null : () => _clean(g),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _info(Vinyl v) => [
        '${v.tracks.length} pista(s)',
        if (v.coverUrl != null) 'portada',
        if (v.pdfs.isNotEmpty) 'PDF',
        if (v.booklet.isNotEmpty) 'libreto',
      ].join(' · ');
}
