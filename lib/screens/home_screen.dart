import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/koofr_settings.dart';
import '../data/library_order.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';
import '../widgets/now_playing_chip.dart';
import 'backup_screen.dart';
import 'crate_screen.dart';
import 'covers_screen.dart';
import 'koofr_screen.dart';
import 'library_actions.dart';
import 'local_screen.dart';

class _Lib {
  const _Lib(this.id, this.name);
  final String id;
  final String name;
}

/// Nombre mostrado de una biblioteca: nunca dice "Koofr".
String _libName(String n) {
  final r = n.replaceAll(RegExp('koofr', caseSensitive: false), 'Nube').trim();
  return r.isEmpty ? 'Nube' : r;
}

class _Chest {
  const _Chest(this.lib, this.singles, this.items);
  final _Lib lib;
  final bool singles;
  final List<Vinyl> items;

  String get label => '${singles ? 'Sueltos' : 'Álbumes'} · ${lib.name}';
}

/// Pantalla principal: un cajón de madera por biblioteca
/// (álbumes y, si hay, temas sueltos).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<_Chest> _chests(List<Vinyl> all) {
    final libs = <_Lib>[];
    List<String> groups(String prefix) => {
          for (final v in all)
            if (v.source != null && v.source!.startsWith(prefix)) v.source!,
        }.toList()
          ..sort();
    for (final acc in KoofrAccounts.list) {
      final gs = groups('${acc.id}:');
      if (gs.isEmpty || all.any((v) => v.source == acc.id)) libs.add(_Lib(acc.id, _libName(acc.name)));
      for (final g in gs) {
        libs.add(_Lib(g, g.substring(acc.id.length + 1)));
      }
    }
    if (all.any((v) => v.source == 'local')) libs.add(const _Lib('local', 'Teléfono'));
    for (final g in groups('local:')) {
      libs.add(_Lib(g, g.substring(6)));
    }
    if (all.any((v) => v.source == null)) libs.add(const _Lib('manual', 'Manuales'));
    final out = <_Chest>[];
    for (final lib in libs) {
      final mine = all.where((v) => libraryOf(v) == lib.id).toList();
      out.add(_Chest(lib, false, mine.where((v) => !v.single).toList()));
      final singles = mine.where((v) => v.single).toList();
      if (singles.isNotEmpty) out.add(_Chest(lib, true, singles));
    }
    return out;
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  void _openChest(_Chest c) => _push(
        CrateScreen(
          store: widget.store,
          source: c.lib.id,
          singles: c.singles,
          title: c.label,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final chests = _chests(widget.store.items);
        return Scaffold(
          backgroundColor: const Color(0xFF0E0E0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0E0E0D),
            title: const Text('VinylSolutions', style: TextStyle(fontWeight: FontWeight.w900)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: ValueListenableBuilder<String?>(
                valueListenable: LibrarySync.busy,
                builder: (_, m, __) =>
                    m == null ? const SizedBox(height: 2) : const LinearProgressIndicator(minHeight: 2),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Agregar',
                onSelected: (v) {
                  switch (v) {
                    case 'koofr':
                      _push(KoofrScreen(store: widget.store));
                    case 'local':
                      _push(LocalScreen(store: widget.store));
                    case 'disc':
                      addDisc(context, widget.store);
                    case 'backup':
                      _push(BackupScreen(store: widget.store));
                    case 'settings':
                      showLibrarySettings(context);
                    case 'clear':
                      confirmClearLibrary(context, widget.store);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'koofr', child: Text('Conectar nube (Koofr)')),
                  PopupMenuItem(value: 'local', child: Text('Carpeta del teléfono')),
                  PopupMenuItem(value: 'disc', child: Text('Agregar disco a mano')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'backup', child: Text('Copia de seguridad')),
                  PopupMenuItem(value: 'settings', child: Text('Ajustes de biblioteca')),
                  PopupMenuItem(value: 'clear', child: Text('Borrar todo')),
                ],
              ),
            ],
          ),
          body: chests.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aún no hay bibliotecas\nToca + y conecta Koofr o elige una carpeta',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.92,
                  children: [
                    for (final c in chests)
                      _CrateTile(
                        label: c.label,
                        count: c.items.length,
                        singles: c.singles,
                        covers: c.items,
                        onTap: () => _openChest(c),
                      ),
                    // Baúl de covers: siempre al final del menú.
                    if (widget.store.items.any((v) => v.cassette))
                      _CabinetTile(
                        covers: widget.store.items.where((v) => v.cassette).toList()
                          ..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase())),
                        onTap: () => _push(CoversScreen(store: widget.store)),
                      ),
                  ],
                ),
          bottomNavigationBar: ValueListenableBuilder<Vinyl?>(
            valueListenable: PlayerService.instance.nowPlaying,
            builder: (_, v, __) => v == null
                ? const SizedBox.shrink()
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      // Row (no Align): Align llenaría toda la pantalla en la barra inferior.
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: NowPlayingChip(
                              onOpen: (v) => openStage(
                                context,
                                widget.store,
                                widget.store.items.firstWhere((e) => e.id == v.id, orElse: () => v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Cajón de madera con discos asomando y el nombre en la tapa.
class _CrateTile extends StatelessWidget {
  const _CrateTile({
    required this.label,
    required this.count,
    required this.singles,
    required this.covers,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool singles;
  final List<Vinyl> covers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final withArt = covers.where((v) => v.coverUrl != null).toList();
    final show = (withArt.isNotEmpty ? withArt : covers).take(4).toList();
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final boxH = w * 0.62;
          final s = w * 0.5;
          return Stack(
            children: [
              // Discos asomando por arriba del cajón.
              for (var i = 0; i < show.length; i++)
                Positioned(
                  left: w * (0.08 + 0.12 * i),
                  top: w * 0.03 + (i.isOdd ? w * 0.015 : 0),
                  width: s,
                  height: s,
                  child: Transform.rotate(
                    angle: (i - 1.5) * 0.035,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 4)],
                      ),
                      child: CoverArt(vinyl: show[i], radius: 2),
                    ),
                  ),
                ),
              if (show.isEmpty)
                Positioned(
                  left: w * 0.2,
                  top: w * 0.05,
                  width: s,
                  height: s,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF1A1A1A)),
                  ),
                ),
              // Frente del cajón.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: boxH,
                child: CustomPaint(
                  painter: _CratePainter(),
                  child: Center(
                    child: Container(
                      width: w * 0.62,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF2),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF2B2118),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            singles ? '$count temas' : '$count discos',
                            style: const TextStyle(color: Color(0xFF6B5846), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Cajón pintado: frente claro con listones de madera a los lados.
class _CratePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5));
    canvas.drawRRect(body.shift(const Offset(0, 3)), Paint()..color = Colors.black54);
    canvas.drawRRect(body, Paint()..color = const Color(0xFFE9E2D3));

    // Listones de madera a los lados y base.
    final wood = Paint()..color = const Color(0xFFB98558);
    final dark = Paint()
      ..color = const Color(0xFF8A5F3A)
      ..strokeWidth = 1;
    final slat = w * 0.1;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, slat, h),
        topLeft: const Radius.circular(5),
        bottomLeft: const Radius.circular(5),
      ),
      wood,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w - slat, 0, slat, h),
        topRight: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      ),
      wood,
    );
    canvas.drawRect(Rect.fromLTWH(0, h - h * 0.09, w, h * 0.09), wood);
    for (var y = h * 0.2; y < h; y += h * 0.2) {
      canvas.drawLine(Offset(0, y), Offset(slat, y), dark);
      canvas.drawLine(Offset(w - slat, y), Offset(w, y), dark);
    }
    // Borde superior del cajón.
    canvas.drawRect(Rect.fromLTWH(slat, 0, w - 2 * slat, h * 0.05), Paint()..color = const Color(0xFFCFC5B1));
  }

  @override
  bool shouldRepaint(covariant _CratePainter old) => false;
}


/// Mueble de madera para cassettes (ranuras horizontales, 3 columnas):
/// solo se ven los cassettes que hay; las demás ranuras quedan vacías.
class _CabinetTile extends StatelessWidget {
  const _CabinetTile({required this.covers, required this.onTap});

  final List<Vinyl> covers;
  final VoidCallback onTap;

  static const _cols = 3;
  static const _rows = 8;

  static const _papers = <(Color, Color)>[
    (Color(0xFFEFE6D2), Color(0xFF1B1B1B)),
    (Color(0xFF16161A), Color(0xFFE8B84A)),
    (Color(0xFF7FA3BF), Color(0xFF10202E)),
    (Color(0xFFC4452F), Color(0xFFFFF2E0)),
    (Color(0xFF1C2B4A), Color(0xFFF2F2F2)),
    (Color(0xFFE8C14A), Color(0xFF1A1A1A)),
    (Color(0xFF3F6B4A), Color(0xFFF4EFE3)),
    (Color(0xFFD9D9D6), Color(0xFF2A2A2A)),
  ];

  Widget _slot(int i) {
    final has = i < covers.length;
    final v = has ? covers[i] : null;
    final pair = has ? _papers[(v!.hue ~/ 45) % _papers.length] : null;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.2, horizontal: 1.5),
        decoration: BoxDecoration(
          color: has ? const Color(0xFF111112) : const Color(0xFF2A1C12),
          borderRadius: BorderRadius.circular(1.5),
          border: Border(
            bottom: BorderSide(color: has ? Colors.black : const Color(0xFFC79A66), width: 1.2),
          ),
        ),
        child: has
            ? Row(
                children: [
                  Container(width: 4, color: pair!.$1.withOpacity(0.9)),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 1.2, horizontal: 1.5),
                      color: pair.$1,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 3),
                      child: Text(
                        v!.artist.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: pair.$2,
                          fontSize: 6.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 4, color: const Color(0xFF2A2A2C)),
                ],
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 26,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF9C6B3F), Color(0xFF6B4527)],
                ),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 5, offset: Offset(0, 3))],
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                color: const Color(0xFF1A110B),
                child: Row(
                  children: [
                    for (var c = 0; c < _cols; c++) ...[
                      if (c > 0) Container(width: 3, color: const Color(0xFF8A5B33)),
                      Expanded(
                        child: Column(
                          children: [for (var r = 0; r < _rows; r++) _slot(c * _rows + r)],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            height: 36,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Covers',
                      style: TextStyle(
                          color: Color(0xFF2B2118), fontWeight: FontWeight.w900, fontSize: 12)),
                  Text('${covers.length} cassettes',
                      style: const TextStyle(color: Color(0xFF6B5846), fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
