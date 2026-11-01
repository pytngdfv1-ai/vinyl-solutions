import 'package:flutter/material.dart';

import '../models/vinyl.dart';
import 'cassette_3d.dart';
import 'cover_art.dart';
import 'ring_360.dart';

/// Interior de una biblioteca en anillos 360°: las portadas de frente.
/// Si hay muchas, se apilan varios anillos (desliza hacia arriba o abajo para cambiar).
class LibraryRing extends StatefulWidget {
  const LibraryRing({
    super.key,
    required this.items,
    required this.onPick,
    this.onLongPress,
    this.emptyText = 'No hay nada aquí',
  });

  final List<Vinyl> items;
  final ValueChanged<Vinyl> onPick;
  final ValueChanged<Vinyl>? onLongPress;
  final String emptyText;

  static const perRing = 24;

  @override
  State<LibraryRing> createState() => _LibraryRingState();
}

class _LibraryRingState extends State<LibraryRing> {
  int _ring = 0;

  int get _rings => (widget.items.length / LibraryRing.perRing).ceil();

  List<Vinyl> _slice(int r) {
    final a = r * LibraryRing.perRing;
    final b = (a + LibraryRing.perRing).clamp(0, widget.items.length).toInt();
    return widget.items.sublist(a, b);
  }

  String _label(int r) {
    final s = _slice(r);
    if (s.isEmpty) return '';
    final a = s.first.artist, b = s.last.artist;
    return a == b ? a : '$a – $b';
  }

  void _go(int r) {
    if (r < 0 || r >= _rings || r == _ring) return;
    setState(() => _ring = r);
  }

  void _pickRing() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            for (var r = 0; r < _rings; r++)
              ListTile(
                dense: true,
                leading: Text('${r + 1}', style: const TextStyle(color: Colors.white54)),
                title: Text(_label(r), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: r == _ring ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _go(r);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return Center(child: Text(widget.emptyText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)));
    }
    if (_ring >= _rings) _ring = _rings - 1;
    final slice = _slice(_ring);
    final allCassette = slice.every((v) => v.single || v.cassette);
    final topPad = MediaQuery.of(context).padding.top + 56;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.0,
          colors: [Color(0xFF1B1B22), Color(0xFF050507)],
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) _go(_ring + 1);
          if (v > 250) _go(_ring - 1);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: topPad + (_rings > 1 ? 40 : 0)),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Ring360(
                    key: ValueKey('ring$_ring|${slice.length}'),
                    count: slice.length,
                    aspect: allCassette ? 0.63 : 1.0,
                    itemBuilder: (_, i) {
                      final v = slice[i];
                      return (v.single || v.cassette)
                          ? Cassette3D(vinyl: v)
                          : ClipRRect(borderRadius: BorderRadius.circular(8), child: CoverArt(vinyl: v, radius: 0));
                    },
                    onFront: (i) => widget.onPick(slice[i]),
                    onLongPressFront: widget.onLongPress == null ? null : (i) => widget.onLongPress!(slice[i]),
                    caption: (i) {
                      final v = slice[i];
                      final t = v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;
                      return (t, '${v.artist}${v.year > 0 ? ' · ${v.year}' : ''}');
                    },
                  ),
                ),
              ),
            ),
            if (_rings > 1)
              Positioned(
                top: topPad,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Anillo anterior',
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: _ring > 0 ? () => _go(_ring - 1) : null,
                    ),
                    Flexible(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickRing,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text('Anillo ${_ring + 1}/$_rings · ${_label(_ring)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Anillo siguiente',
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: _ring < _rings - 1 ? () => _go(_ring + 1) : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
