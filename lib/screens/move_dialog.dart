import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/koofr_client.dart';
import '../data/koofr_settings.dart';
import '../data/library_order.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';

/// "Mover a…": mueve el álbum o tema a otra carpeta de la nube (sin borrar ni sobrescribir).
class MoveDialog extends StatefulWidget {
  const MoveDialog({super.key, required this.store, required this.vinyl, required this.account});

  final VinylStore store;
  final Vinyl vinyl;
  final KoofrSettings account;

  @override
  State<MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<MoveDialog> {
  static const _newKey = '\u0000new';

  late final KoofrClient _client = KoofrClient(widget.account);
  final _newName = TextEditingController();
  List<String>? _folders;
  String? _selected;
  bool _wholeArtist = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f = await _client.topFolders();
      if (mounted) setState(() => _folders = f);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudieron leer las carpetas: $e');
    }
  }

  String? get _dest {
    if (_selected == null) return null;
    if (_selected == _newKey) {
      final n = KoofrClient.cleanName(_newName.text);
      return n.isEmpty ? null : n;
    }
    return _selected;
  }

  MovePlan? get _plan {
    final d = _dest;
    return d == null ? null : _client.plan(widget.vinyl, d, wholeArtist: _wholeArtist);
  }

  String _label(List<String> segs) => '${widget.account.folder}/${segs.join('/')}';

  Future<void> _move() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client.execute(plan);
      // Quita de la biblioteca lo movido y detiene la música si era de ahí.
      final ids = <String>[
        for (final it in widget.store.items)
          if (sourceInAccount(it.source, widget.account.id) &&
              it.trackUrls.isNotEmpty &&
              KoofrClient.isUnder(plan.from, _client.relSegments(it.trackUrls.first)))
            it.id,
      ];
      final playing = PlayerService.instance.nowPlaying.value?.id;
      if (playing != null && ids.contains(playing)) await PlayerService.instance.stop();
      await widget.store.removeMany(ids);
      if (mounted) Navigator.of(context).pop(true);
    } on KoofrException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo mover: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    final plan = _plan;
    final folders = _folders;
    return AlertDialog(
      title: Text('Mover "${v.title}" a…', maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (folders == null && _error == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (folders != null) ...[
                for (final f in folders)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: f,
                    groupValue: _selected,
                    title: Text(f),
                    onChanged: _busy ? null : (x) => setState(() => _selected = x),
                  ),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _newKey,
                  groupValue: _selected,
                  title: const Text('Crear carpeta nueva…'),
                  onChanged: _busy ? null : (x) => setState(() => _selected = x),
                ),
                if (_selected == _newKey)
                  TextField(
                    controller: _newName,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Nombre (ej.: Inglés)'),
                  ),
                if (_client.hasArtistFolder(v))
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _wholeArtist,
                    title: const Text('Mover todo el artista'),
                    subtitle: const Text('Todos sus álbumes a la vez'),
                    onChanged: _busy ? null : (x) => setState(() => _wholeArtist = x),
                  ),
                if (plan != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_label(plan.from)}\n→ ${_label(plan.to)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                if (widget.account.split != 'yes')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Al terminar de ordenar, en la cuenta pon "Subcarpetas como bibliotecas" = Sí '
                      'para ver cada carpeta como un cajón.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_busy || plan == null) ? null : _move,
          child: const Text('Mover'),
        ),
      ],
    );
  }
}
