import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/cloud_upload.dart';
import '../data/koofr_client.dart';
import '../data/koofr_settings.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';

/// "Subir a la nube…": copia la carpeta del álbum (o el tema) del teléfono a la nube,
/// sin pisar archivos, y conserva portada, idioma y demás datos del disco.
class UploadDialog extends StatefulWidget {
  const UploadDialog({super.key, required this.store, required this.vinyl});
  final VinylStore store;
  final Vinyl vinyl;

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<UploadDialog> {
  static const _newKey = '\u0000new';
  late KoofrSettings _acct = KoofrAccounts.list.first;
  List<String>? _folders;
  String? _selected;
  final _newName = TextEditingController();
  bool _deleteLocal = false;
  bool _busy = false;
  String _msg = '';
  double _p = 0;
  String? _error;

  bool get _split => _acct.split == 'yes';

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _folders = null;
      _selected = null;
      _error = null;
    });
    if (!_split) {
      setState(() => _folders = const []);
      return;
    }
    try {
      final f = await KoofrClient(_acct).topFolders();
      if (mounted) setState(() => _folders = f);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudieron leer las carpetas: $e');
    }
  }

  String? get _dest {
    if (!_split) return null;
    if (_selected == _newKey) {
      final n = KoofrClient.cleanName(_newName.text);
      return n.isEmpty ? null : n;
    }
    return _selected;
  }

  bool get _ready => !_busy && _folders != null && (!_split || _dest != null);

  Future<void> _go() async {
    final v = widget.vinyl;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await CloudUpload.run(v, _acct, dest: _dest, onProgress: (m, p) {
        if (mounted) {
          setState(() {
            _msg = m;
            _p = p;
          });
        }
      });
      // Conserva lo que no se puede recuperar al releer la nube.
      final c = v.coverUrl;
      await widget.store.addCarry({
        r.firstKey: {
          'cover': c != null && !c.contains('koofr.net') ? c : null,
          'owned': v.owned,
          'cassette': v.cassette,
          'coverManual': v.coverManual,
          'lang': v.lang,
          'langManual': v.langManual,
        },
      });
      var note = '${r.uploaded} archivo(s) subidos${r.skipped > 0 ? ', ${r.skipped} ya estaban' : ''}';
      if (_deleteLocal) {
        try {
          await CloudUpload.deleteLocal(v);
        } catch (e) {
          note += '. No se pudo borrar la copia del teléfono: $e';
        }
      }
      final playing = PlayerService.instance.nowPlaying.value?.id;
      if (playing == v.id) await PlayerService.instance.stop();
      await widget.store.removeMany([v.id]);
      LibrarySync.refresh(_acct, widget.store);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
      }
    } on KoofrException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo subir: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    final folders = _folders;
    final dir = _split && _dest == null ? null : CloudUpload.targetDir(v, _dest).join('/');
    return AlertDialog(
      title: Text('Subir "${v.title}" a la nube', maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (KoofrAccounts.list.length > 1)
                DropdownButton<KoofrSettings>(
                  isExpanded: true,
                  value: _acct,
                  items: [
                    for (final a in KoofrAccounts.list) DropdownMenuItem(value: a, child: Text(a.name)),
                  ],
                  onChanged: _busy
                      ? null
                      : (a) {
                          if (a == null) return;
                          _acct = a;
                          _loadFolders();
                        },
                ),
              if (folders == null && _error == null)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              if (_split && folders != null) ...[
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
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Nombre (ej.: Inglés)'),
                  ),
              ],
              if (dir != null && folders != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('→ ${_acct.folder}/$dir',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              if (folders != null)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _deleteLocal,
                  title: const Text('Borrar la copia del teléfono'),
                  subtitle: const Text('Solo después de subir; si no, queda duplicado'),
                  onChanged: _busy ? null : (x) => setState(() => _deleteLocal = x),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              if (_busy) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _p == 0 ? null : _p),
                Text(_msg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: _ready ? _go : null, child: const Text('Subir')),
      ],
    );
  }
}
