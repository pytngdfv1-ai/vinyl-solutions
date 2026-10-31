import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';
import 'cover_studio_screen.dart';

/// Discos sin portada o sin PDF: lista de pendientes para completar con Cover Studio.
class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key, required this.store});
  final VinylStore store;

  /// Cuántos pendientes hay (sin contar los ignorados).
  static Future<int> count(VinylStore store) async {
    final ig = await _loadIgnored();
    return store.items.where((v) => _missing(v) != _Miss.none && !ig.contains(v.id)).length;
  }

  static Future<Set<String>> _loadIgnored() async {
    try {
      final p = await SharedPreferences.getInstance();
      final r = p.getString('pending_ignored_v1');
      return r == null ? {} : (jsonDecode(r) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

enum _Miss { none, cover, pdf, both }

_Miss _missing(Vinyl v) {
  if (v.isDivider || v.id.startsWith('sep_')) return _Miss.none;
  final noCover = v.coverUrl == null;
  final noPdf = !v.single && !v.hasBooklet;
  if (noCover && noPdf) return _Miss.both;
  if (noCover) return _Miss.cover;
  if (noPdf) return _Miss.pdf;
  return _Miss.none;
}

class _PendingScreenState extends State<PendingScreen> {
  Set<String> _ignored = {};
  bool _showIgnored = false;
  _Miss? _filter;

  @override
  void initState() {
    super.initState();
    PendingScreen._loadIgnored().then((s) {
      if (mounted) setState(() => _ignored = s);
    });
  }

  Future<void> _toggle(String id) async {
    setState(() => _ignored.contains(id) ? _ignored.remove(id) : _ignored.add(id));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('pending_ignored_v1', jsonEncode(_ignored.toList()));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendientes'),
        actions: [
          IconButton(
            tooltip: _showIgnored ? 'Ocultar ignorados' : 'Ver ignorados',
            icon: Icon(_showIgnored ? Icons.visibility : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _showIgnored = !_showIgnored),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final all = [
            for (final v in widget.store.items)
              if (_missing(v) != _Miss.none) v,
          ];
          bool isIg(Vinyl v) => _ignored.contains(v.id);
          final list = [
            for (final v in all)
              if ((_showIgnored || !isIg(v)) &&
                  (_filter == null ||
                      _missing(v) == _filter ||
                      (_filter == _Miss.cover && _missing(v) == _Miss.both) ||
                      (_filter == _Miss.pdf && _missing(v) == _Miss.both)))
                v,
          ]..sort((a, b) => '${a.artist} ${a.title}'.toLowerCase().compareTo('${b.artist} ${b.title}'.toLowerCase()));
          final noCover = all.where((v) => v.coverUrl == null && !isIg(v)).length;
          final noPdf = all.where((v) => !v.single && !v.hasBooklet && !isIg(v)).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(label: const Text('Todos'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                    ChoiceChip(
                        label: Text('Sin portada ($noCover)'),
                        selected: _filter == _Miss.cover,
                        onSelected: (_) => setState(() => _filter = _Miss.cover)),
                    ChoiceChip(
                        label: Text('Sin PDF ($noPdf)'),
                        selected: _filter == _Miss.pdf,
                        onSelected: (_) => setState(() => _filter = _Miss.pdf)),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Nada pendiente 🎉', style: TextStyle(color: Colors.white60)))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final v = list[i];
                          final m = _missing(v);
                          return ListTile(
                            leading: SizedBox(width: 48, height: 48, child: CoverArt(vinyl: v, radius: 4)),
                            title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${v.artist} · ${switch (m) {
                                _Miss.both => 'sin portada ni PDF',
                                _Miss.cover => 'sin portada',
                                _ => 'sin PDF',
                              }}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isIg(v) ? Colors.white38 : Colors.white60),
                            ),
                            trailing: IconButton(
                              tooltip: isIg(v) ? 'Dejar de ignorar' : 'Ignorar',
                              icon: Icon(isIg(v) ? Icons.undo : Icons.close, size: 20),
                              onPressed: () => _toggle(v.id),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => CoverStudioScreen(store: widget.store, target: v)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
