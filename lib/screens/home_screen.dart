import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/cajon.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import 'cover_studio_screen.dart';
import 'duplicates_screen.dart';
import '../models/vinyl.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/now_playing_chip.dart';
import 'backup_screen.dart';
import 'crate_screen.dart';
import 'covers_screen.dart';
import 'koofr_screen.dart';
import 'library_actions.dart';
import 'local_screen.dart';

/// Pantalla principal: un cajón de madera por biblioteca
/// (álbumes y, si hay, temas sueltos).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  void _openCajon(Cajon c) {
    if (c.kind == CajonKind.covers || c.kind == CajonKind.singles) {
      _push(CoversScreen(store: widget.store, cajon: c));
    } else {
      _push(CrateScreen(store: widget.store, cajon: c, title: c.name));
    }
  }

  /// Mantén pulsado un cajón para cambiarle el nombre (vacío = nombre de fábrica).
  Future<void> _rename(Cajon c) async {
    final ctrl = TextEditingController(text: c.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del cajón'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: c.defaultName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (name == null) return;
    await ChestNames.set(c, name);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final all = widget.store.items;
        final cajones = [
          for (final c in Cajon.all)
            if (all.any(c.matches)) c,
        ];
        return Scaffold(
          backgroundColor: AppColors.ink,
          appBar: AppBar(
            backgroundColor: AppColors.ink,
            title: const Text('VinylSolutions'),
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
                    case 'dups':
                      _push(DuplicatesScreen(store: widget.store));
                    case 'studio':
                      _push(CoverStudioScreen(store: widget.store));
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
                  PopupMenuItem(value: 'dups', child: Text('Duplicados')),
                  PopupMenuItem(value: 'studio', child: Text('Cover Studio (portadas y PDF)')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'backup', child: Text('Copia de seguridad')),
                  PopupMenuItem(value: 'settings', child: Text('Ajustes de biblioteca')),
                  PopupMenuItem(value: 'clear', child: Text('Borrar todo')),
                ],
              ),
            ],
          ),
          body: cajones.isEmpty
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
                    for (final c in cajones)
                      if (c.kind == CajonKind.covers || c.kind == CajonKind.singles)
                        _CabinetTile(
                          label: c.name,
                          covers: all.where(c.matches).toList()
                            ..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase())),
                          onTap: () => _openCajon(c),
                          onLongPress: () => _rename(c),
                        )
                      else
                        _CrateTile(
                          label: c.name,
                          count: all.where(c.matches).length,
                          singles: c.kind == CajonKind.singles,
                          covers: all.where(c.matches).toList(),
                          onTap: () => _openCajon(c),
                          onLongPress: () => _rename(c),
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
    this.onLongPress,
  });

  final String label;
  final int count;
  final bool singles;
  final List<Vinyl> covers;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final withArt = covers.where((v) => v.coverUrl != null).toList();
    final show = (withArt.isNotEmpty ? withArt : covers).take(4).toList();
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                              fontFamily: titleFont,
                              color: Color(0xFF2B2118),
                              fontSize: 13,
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
  const _CabinetTile({
    required this.label,
    required this.covers,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final List<Vinyl> covers;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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
      onLongPress: onLongPress,
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
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: titleFont, color: Color(0xFF2B2118), fontSize: 13)),
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
