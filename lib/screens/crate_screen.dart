import 'package:flutter/material.dart';

import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';
import '../widgets/crate_view.dart';
import 'koofr_screen.dart';
import 'local_screen.dart';
import 'stage_screen.dart';

enum _Filter { all, owned }

class CrateScreen extends StatefulWidget {
  const CrateScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<CrateScreen> createState() => _CrateScreenState();
}

class _CrateScreenState extends State<CrateScreen> {
  _Filter _filter = _Filter.all;
  bool _menuOpen = false;

  void _open(Vinyl v) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => StageScreen(store: widget.store, vinyl: v),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _confirmDelete(Vinyl v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar disco'),
        content: Text('¿Quitar "${v.title}" de la biblioteca? Tus archivos en Koofr no se tocan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PlayerService.instance.stopIf(v.id);
      await widget.store.remove(v.id);
    }
  }

  Future<void> _confirmClear() async {
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
      await widget.store.clearAll();
    }
  }

  void _openLocal() {
    setState(() => _menuOpen = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LocalScreen(store: widget.store)),
    );
  }

  void _openKoofr() {
    setState(() => _menuOpen = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => KoofrScreen(store: widget.store)),
    );
  }

  Future<void> _add() async {
    setState(() => _menuOpen = false);
    final r = await showDialog<(String, String, int)>(
      context: context,
      builder: (_) => const _AddDialog(),
    );
    if (r != null) {
      await widget.store.add(artist: r.$1, title: r.$2, year: r.$3);
      if (mounted) setState(() => _filter = _Filter.all);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final all = widget.store.items;
        final items =
            _filter == _Filter.owned ? all.where((e) => e.owned).toList() : all;

        return Scaffold(
          backgroundColor: Colors.black,
          drawer: Drawer(
            backgroundColor: const Color(0xFF161816),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'VinylSolutions',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.album),
                    title: const Text('Catálogo completo'),
                    trailing: _filter == _Filter.all ? const Icon(Icons.check) : null,
                    onTap: () {
                      setState(() => _filter = _Filter.all);
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.collections_bookmark),
                    title: const Text('Mi colección'),
                    trailing: _filter == _Filter.owned ? const Icon(Icons.check) : null,
                    onTap: () {
                      setState(() => _filter = _Filter.owned);
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: const Text('Borrar biblioteca'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _confirmClear();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Carpeta local'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openLocal();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Conectar Koofr'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openKoofr();
                    },
                  ),
                ],
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CrateView(
                  key: ValueKey(_filter),
                  items: items,
                  onPick: _open,
                  onLongPress: _confirmDelete,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _filter == _Filter.owned ? 'Mi colección' : 'Catálogo',
                          style: const TextStyle(
                            color: Color(0xFF5CFF7A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _NowPlaying(
                            onOpen: (v) => _open(
                              widget.store.items.firstWhere((e) => e.id == v.id, orElse: () => v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_menuOpen) ...[
                        _Pill(label: 'Carpeta local', icon: Icons.folder_open, onTap: _openLocal),
                        const SizedBox(height: 8),
                        _Pill(label: 'Conectar Koofr', icon: Icons.cloud_outlined, onTap: _openKoofr),
                        const SizedBox(height: 8),
                        _Pill(label: 'Agregar disco', icon: Icons.add, onTap: _add),
                        const SizedBox(height: 8),
                        _Pill(
                          label: _filter == _Filter.all ? 'Ver mi colección' : 'Ver catálogo',
                          icon: Icons.filter_list,
                          onTap: () => setState(() {
                            _filter = _filter == _Filter.all ? _Filter.owned : _Filter.all;
                            _menuOpen = false;
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FloatingActionButton.small(
                        onPressed: () => setState(() => _menuOpen = !_menuOpen),
                        child: AnimatedRotation(
                          turns: _menuOpen ? 0.125 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mini reproductor: muestra lo que suena mientras buscas otro disco.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.onOpen});

  final ValueChanged<Vinyl> onOpen;

  @override
  Widget build(BuildContext context) {
    final audio = PlayerService.instance;
    final p = audio.player;
    return ValueListenableBuilder<Vinyl?>(
      valueListenable: audio.nowPlaying,
      builder: (_, v, __) {
        if (v == null) return const SizedBox.shrink();
        return Material(
          color: const Color(0xDD1E1E1E),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => onOpen(v),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 2, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 32, height: 32, child: ClipOval(child: CoverArt(vinyl: v, radius: 0))),
                  const SizedBox(width: 8),
                  Flexible(
                    child: StreamBuilder<int?>(
                      stream: p.currentIndexStream,
                      builder: (_, s) {
                        final i = s.data ?? 0;
                        return Text(
                          i < v.tracks.length ? v.tracks[i] : v.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: p.playingStream,
                    initialData: p.playing,
                    builder: (_, s) => IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon((s.data ?? false) ? Icons.pause : Icons.play_arrow),
                      onPressed: () => (s.data ?? false) ? p.pause() : p.play(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC1E1E1E),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(label), const SizedBox(width: 10), Icon(icon, size: 18)],
          ),
        ),
      ),
    );
  }
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
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
