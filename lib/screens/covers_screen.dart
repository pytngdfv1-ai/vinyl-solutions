import 'package:flutter/material.dart';

import '../data/cajon.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/now_playing_chip.dart';
import 'library_actions.dart' show openStage;

String _name(Vinyl v) => v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;

/// Baúl "Covers": estantería con un cassette (de canto) por cada cover marcado.
class CoversScreen extends StatelessWidget {
  const CoversScreen({super.key, required this.store, required this.cajon});

  final VinylStore store;
  final Cajon cajon;

  static const _perRow = 12;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final list = store.items.where(cajon.matches).toList()
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
            title: Text(cajon.name, style: const TextStyle(fontWeight: FontWeight.w900)),
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
            height: 168,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < perRow; i++)
                  Expanded(
                    child: i < items.length
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0.6),
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

/// Lomo de cassette real: plástico negro, papel de color con el nombre
/// en vertical y las marcas "STEREO" abajo. Delgado, como en la estantería.
class _Spine extends StatelessWidget {
  const _Spine({required this.vinyl, required this.onTap});

  final Vinyl vinyl;
  final VoidCallback onTap;

  // (papel, tinta) como los lomos de verdad.
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

  @override
  Widget build(BuildContext context) {
    final pair = _papers[(vinyl.hue ~/ 45) % _papers.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1.5),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A2A2C), Color(0xFF0E0E0F), Color(0xFF1C1C1E)],
          ),
          border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
        ),
        child: Column(
          children: [
            // Marca arriba (logo de la casetera).
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 4, 3, 3),
              child: Container(height: 5, decoration: BoxDecoration(color: pair.$1.withOpacity(0.85), borderRadius: BorderRadius.circular(1))),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: pair.$1,
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(pair.$1, Colors.white, 0.12)!,
                      pair.$1,
                      Color.lerp(pair.$1, Colors.black, 0.18)!,
                    ],
                  ),
                ),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        '${vinyl.artist} – ${_name(vinyl)}'.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: pair.$2,
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Rayitas de "STEREO" y el icono del cassette abajo.
            const SizedBox(height: 3),
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 3), color: Colors.white24),
            const SizedBox(height: 2),
            Container(height: 4, width: 8, decoration: BoxDecoration(border: Border.all(color: Colors.white38, width: 0.6))),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
