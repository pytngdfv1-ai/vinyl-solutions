import 'dart:convert';

import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/koofr_client.dart';
import '../data/koofr_settings.dart';
import '../data/library_order.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';

/// Edita los nombres de un disco o tema: artista, título y cada tema.
/// En la nube puede renombrar también la carpeta del álbum.
class EditNamesDialog extends StatefulWidget {
  const EditNamesDialog({super.key, required this.store, required this.vinyl, this.account});

  final VinylStore store;
  final Vinyl vinyl;
  final KoofrSettings? account;

  @override
  State<EditNamesDialog> createState() => _EditNamesDialogState();
}

class _EditNamesDialogState extends State<EditNamesDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.vinyl.title);
  late final TextEditingController _artist = TextEditingController(text: widget.vinyl.artist);
  late final List<TextEditingController> _tracks = [
    for (final t in widget.vinyl.tracks) TextEditingController(text: t),
  ];
  bool _renameFolder = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    for (final c in _tracks) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canRenameFolder => widget.account != null && !widget.vinyl.single && widget.vinyl.trackUrls.isNotEmpty;

  Future<void> _save() async {
    final v = widget.vinyl;
    final title = _title.text.trim();
    final artist = _artist.text.trim();
    if (title.isEmpty || artist.isEmpty) {
      setState(() => _error = 'El título y el artista no pueden quedar vacíos');
      return;
    }
    final tracks = [for (final c in _tracks) c.text.trim().isEmpty ? '-' : c.text.trim()];
    // Un tema suelto: el título es el nombre del tema.
    if (v.single && tracks.isNotEmpty) tracks[0] = title;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.editNames(v.id, title: title, artist: artist, tracks: tracks);
      var moved = false;
      if (_renameFolder && _canRenameFolder && title != v.title) {
        moved = await _renameInCloud(title);
      }
      if (mounted) Navigator.of(context).pop(moved ? 'moved' : 'saved');
    } on KoofrException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Renombra la carpeta del álbum en la nube y deja la biblioteca al día.
  Future<bool> _renameInCloud(String title) async {
    final v = widget.vinyl;
    final acct = widget.account!;
    final client = KoofrClient(acct);
    final rel = client.relSegments(v.trackUrls.first);
    final from = rel.sublist(0, rel.length - 1);
    final to = await client.renameDir(from, title);
    if (to.join('/') == from.join('/')) return false;

    final carry = <String, Map<String, dynamic>>{};
    final ids = <String>[];
    for (final it in widget.store.items) {
      if (!sourceInAccount(it.source, acct.id) || it.trackUrls.isEmpty) continue;
      final r = client.relSegments(it.trackUrls.first);
      if (!KoofrClient.isUnder(from, r)) continue;
      ids.add(it.id);
      final c = it.coverUrl;
      final keep = c != null && !c.contains('koofr.net');
      carry[[...to, ...r.sublist(from.length)].join('/')] = {
        'cover': keep ? c : null,
        'owned': it.owned,
        'cassette': it.cassette,
        'coverManual': it.coverManual,
        'lang': it.lang,
        'langManual': it.langManual,
      };
    }
    await widget.store.addCarry(carry);
    final newId = 'dav_${acct.id}_${base64Url.encode(utf8.encode(to.join('/')))}';
    if (v.id.startsWith('dav_${acct.id}_')) await widget.store.moveEdit(v.id, newId, dropTitle: true);
    final playing = PlayerService.instance.nowPlaying.value?.id;
    if (playing != null && ids.contains(playing)) await PlayerService.instance.stop();
    await widget.store.removeMany(ids);
    LibrarySync.refresh(acct, widget.store);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    return AlertDialog(
      title: const Text('Editar nombres'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _artist, decoration: const InputDecoration(labelText: 'Artista')),
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: v.single ? 'Tema' : 'Álbum'),
              ),
              if (_canRenameFolder)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _renameFolder,
                  title: const Text('Renombrar también la carpeta en la nube'),
                  subtitle: const Text('Los demás cambios quedan en la app'),
                  onChanged: _busy ? null : (x) => setState(() => _renameFolder = x),
                ),
              if (!v.single && _tracks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('TEMAS', style: TextStyle(color: Colors.white60, fontSize: 12)),
                for (var i = 0; i < _tracks.length; i++)
                  TextField(
                    controller: _tracks[i],
                    decoration: InputDecoration(prefixText: '${i + 1}.  ', isDense: true),
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
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Guardar')),
      ],
    );
  }
}
