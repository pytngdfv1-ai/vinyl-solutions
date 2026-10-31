import 'package:flutter/material.dart';

import '../data/playlists.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import 'dj_live_screen.dart';

Future<String?> _askName(BuildContext context, {String initial = '', String title = 'Nombre de la playlist'}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Mi playlist')),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Aceptar')),
      ],
    ),
  );
}

/// Hoja "Agregar a playlist": elige una lista (o crea una nueva) y suma el tema.
Future<void> showAddToPlaylist(BuildContext context, PlEntry e) async {
  final store = Playlists.instance;
  final messenger = ScaffoldMessenger.of(context);
  final pick = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.panel,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('Agregar a playlist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          for (final p in store.lists)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(p.name),
              subtitle: Text('${p.entries.length} tema(s)'),
              onTap: () => Navigator.of(ctx).pop(p.id),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Nueva playlist…'),
            onTap: () => Navigator.of(ctx).pop('\u0000new'),
          ),
        ],
      ),
    ),
  );
  if (pick == null) return;
  var id = pick;
  if (pick == '\u0000new') {
    if (!context.mounted) return;
    final name = await _askName(context);
    if (name == null) return;
    id = (await store.create(name)).id;
  }
  final ok = await store.add(id, e);
  final name = store.lists.where((p) => p.id == id).firstOrNull?.name ?? 'playlist';
  messenger.showSnackBar(SnackBar(content: Text(ok ? '“${e.title}” agregado a $name' : 'Ya estaba en $name')));
}

/// Lista de playlists.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Playlists.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.ink,
        appBar: AppBar(
          backgroundColor: AppColors.ink,
          title: const Text('Playlists'),
          actions: [
            IconButton(
              tooltip: 'Nueva playlist',
              icon: const Icon(Icons.add),
              onPressed: () async {
                final n = await _askName(context);
                if (n != null) await store.create(n);
              },
            ),
          ],
        ),
        body: store.lists.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aún no hay playlists.\nEn un disco, toca el icono de lista junto al tema para agregarlo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            : ListView(
                children: [
                  for (final p in store.lists)
                    ListTile(
                      leading: p.entries.isEmpty
                          ? const Icon(Icons.queue_music, size: 40)
                          : SizedBox(width: 48, height: 48, child: CoverArt(vinyl: p.entries.first.asVinyl())),
                      title: Text(p.name),
                      subtitle: Text('${p.entries.length} tema(s)'),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => PlaylistScreen(id: p.id))),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Una playlist: temas, reproducir en orden o aleatorio.
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.id});
  final String id;

  /// Siempre en el DJ en vivo: dos platos que se mezclan.
  Future<void> _play(BuildContext context, Playlist p, {required bool shuffle}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DjLiveScreen(playlist: p, shuffle: shuffle)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Playlists.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final p = store.lists.where((x) => x.id == id).firstOrNull;
        if (p == null) return const Scaffold(body: Center(child: Text('Playlist eliminada')));
        return Scaffold(
          backgroundColor: AppColors.ink,
          appBar: AppBar(
            backgroundColor: AppColors.ink,
            title: Text(p.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'rename') {
                    final n = await _askName(context, initial: p.name, title: 'Renombrar');
                    if (n != null) await store.rename(p.id, n);
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('¿Borrar "${p.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Borrar')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.delete(p.id);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(value: 'delete', child: Text('Borrar playlist')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Aleatorio'),
                        onPressed: p.entries.isEmpty ? null : () => _play(context, p, shuffle: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('En orden'),
                        onPressed: p.entries.isEmpty ? null : () => _play(context, p, shuffle: false),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: p.entries.isEmpty
                    ? const Center(child: Text('Sin temas', style: TextStyle(color: Colors.white60)))
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: p.entries.length,
                        onReorder: (a, b) => store.move(p.id, a, b > a ? b - 1 : b),
                        itemBuilder: (_, i) {
                          final e = p.entries[i];
                          return Dismissible(
                            key: ValueKey('${p.id}_${e.url}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red.shade900,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete),
                            ),
                            onDismissed: (_) => store.removeAt(p.id, i),
                            child: ListTile(
                              leading: SizedBox(width: 44, height: 44, child: CoverArt(vinyl: e.asVinyl())),
                              title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${e.artist} · ${e.album}', maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
