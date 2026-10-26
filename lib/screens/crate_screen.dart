import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/cajon.dart';
import '../data/library_names.dart';
import '../data/library_order.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/now_playing_chip.dart';
import '../widgets/crate_view.dart';
import 'koofr_screen.dart';
import 'local_screen.dart';
import 'library_actions.dart';

enum _Filter { all, owned }

class CrateScreen extends StatefulWidget {
  const CrateScreen({
    super.key,
    required this.store,
    required this.cajon,
    required this.title,
  });

  final VinylStore store;

  /// Cajón (tipo + idioma) y su título.
  final Cajon cajon;
  final String title;

  @override
  State<CrateScreen> createState() => _CrateScreenState();
}

class _CrateScreenState extends State<CrateScreen> {
  _Filter _filter = _Filter.all;
  bool _menuOpen = false;
  String? _genre;
  String? _lib; // biblioteca de origen (filtro dentro del cajón)

  void _open(Vinyl v) {
    if (v.isDivider) return;
    openStage(context, widget.store, v);
  }

  Future<void> _confirmDelete(Vinyl v) async {
    if (v.isDivider) return;
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

  Future<void> _openSettings() => showLibrarySettings(context);

  Future<void> _confirmClear() => confirmClearLibrary(context, widget.store);

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

  String _chipLabel() {
    var label = widget.title;
    if (_filter == _Filter.owned) label += ' · Mi colección';
    if (_genre != null) label += ' · $_genre';
    if (_lib != null) label += ' · ${libraryLabel(_lib!)}';
    return label;
  }

  /// Filtro por género.
  List<Widget> _filterTiles(List<Vinyl> all) {
    final genres = <String>{
      for (final v in all)
        if ((v.genre ?? '').isNotEmpty) v.genre!,
    }.toList()
      ..sort();
    void pick(String? g) {
      setState(() => _genre = g);
      Navigator.of(context).pop();
    }

    return [
      if (genres.isNotEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
          child: Text('FILTRAR', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      if (_genre != null)
        ListTile(
          dense: true,
          leading: const Icon(Icons.clear_all),
          title: const Text('Quitar filtro'),
          onTap: () => pick(null),
        ),
      for (final g in genres)
        ListTile(
          dense: true,
          leading: const Icon(Icons.label_outline),
          title: Text('Género: $g'),
          trailing: _genre == g ? const Icon(Icons.check) : null,
          onTap: () => pick(g),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final all = widget.store.items;
        final mine = all.where(widget.cajon.matches).toList();
        final libs = {for (final e in mine) libraryOf(e)}.toList()..sort();
        if (_lib != null && !libs.contains(_lib)) _lib = null;
        var filtered = _lib == null ? mine : mine.where((e) => libraryOf(e) == _lib).toList();
        if (_filter == _Filter.owned) filtered = filtered.where((e) => e.owned).toList();
        if (_genre != null) filtered = filtered.where((e) => e.genre == _genre).toList();
        final items = widget.cajon.kind == CajonKind.unclassified
            ? [...arrange(filtered), ...arrange(filtered, singles: true)]
            : arrange(filtered, singles: widget.cajon.kind == CajonKind.singles);

        return Scaffold(
          backgroundColor: Colors.black,
          drawer: Drawer(
            backgroundColor: const Color(0xFF161816),
            child: SafeArea(
              child: ListView(
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
                  if (libs.length > 1) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
                      child: Text('BIBLIOTECA', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.all_inbox_outlined),
                      title: const Text('Todas'),
                      trailing: _lib == null ? const Icon(Icons.check) : null,
                      onTap: () {
                        setState(() => _lib = null);
                        Navigator.of(context).pop();
                      },
                    ),
                    for (final l in libs)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(libraryLabel(l)),
                        trailing: _lib == l ? const Icon(Icons.check) : null,
                        onTap: () {
                          setState(() => _lib = l);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                  ..._filterTiles(mine),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Ajustes de biblioteca'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openSettings();
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
                  key: ValueKey('$_filter|$_genre|$_lib'),
                  emptyText: 'No hay nada en "${widget.title}"',
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
                      IconButton(
                        tooltip: 'Menú principal',
                        icon: const Icon(Icons.home_outlined),
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _chipLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF5CFF7A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: NowPlayingChip(
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
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: LibrarySync.busy,
                    builder: (_, m, __) => m == null
                        ? const SizedBox.shrink()
                        : const LinearProgressIndicator(minHeight: 2),
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

