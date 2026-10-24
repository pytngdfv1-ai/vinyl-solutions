import 'package:flutter/material.dart';

import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/now_playing_chip.dart';
import 'library_actions.dart' show openStage;

String _name(Vinyl v) => v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;

/// Baúl "Covers": estantería con un cassette (de canto) por cada cover marcado.
class CoversScreen extends StatelessWidget {
  const CoversScreen({super.key, required this.store});

  final VinylStore store;

  static const _perRow = 7;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final list = store.items.where((v) => v.cassette && !v.isDivider).toList()
          ..sort((a, b) {
            String k(Vinyl v) {
              var s = v.artist.toLowerCase().trim();
              if (s.startsWith('the ')) s = s.substring(4);
              return s;
            }

            final c = k(a).compareTo(k(b));
            return c != 0 ? c : _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
          });
        final rows = <List<Vinyl>>[
          for (var i = 0; i < list.length; i += _perRow)
            list.sublist(i, i + _perRow > list.length ? list.length : i + _perRow),
        ];
        return Scaffold(
          backgroundColor: const Color(0xFF0E0E0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0E0E0D),
            title: const Text('Covers', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                tooltip: 'Menú principal',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
          body: list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aún no hay covers\nAbre un tema, toca ⓘ y activa "Es un cover"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _Shelf(
                    items: rows[i],
                    perRow: _perRow,
                    onTap: (v) => openStage(context, store, v),
                  ),
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: NowPlayingChip(
                      onOpen: (v) => openStage(
                        context,
                        store,
                        store.items.firstWhere((e) => e.id == v.id, orElse: () => v),
                      ),
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

class _Shelf extends StatelessWidget {
  const _Shelf({required this.items, required this.perRow, required this.onTap});

  final List<Vinyl> items;
  final int perRow;
  final void Function(Vinyl) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < perRow; i++)
                  Expanded(
                    child: i < items.length
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: _Spine(vinyl: items[i], onTap: () => onTap(items[i])),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB98558), Color(0xFF7A5232)],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 3))],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lomo de cassette: color según el disco y "Artista – Tema" en vertical.
class _Spine extends StatelessWidget {
  const _Spine({required this.vinyl, required this.onTap});

  final Vinyl vinyl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = HSLColor.fromAHSL(1, vinyl.hue % 360, 0.55, 0.42).toColor();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.white24, width: 0.6),
        ),
        child: Column(
          children: [
            Container(height: 6, color: tint),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
                color: const Color(0xFFF4EFE3),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '${vinyl.artist} – ${_name(vinyl)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(height: 6, color: tint),
          ],
        ),
      ),
    );
  }
}
