import 'package:flutter/material.dart';

import '../data/koofr_client.dart';
import '../data/koofr_settings.dart';

/// Crea una carpeta nueva en la nube: eliges la cuenta, entras a la carpeta y le pones nombre.
class NewCloudFolderDialog extends StatefulWidget {
  const NewCloudFolderDialog({super.key});

  @override
  State<NewCloudFolderDialog> createState() => _NewCloudFolderDialogState();
}

class _NewCloudFolderDialogState extends State<NewCloudFolderDialog> {
  late KoofrSettings _acct = KoofrAccounts.list.first;
  final _name = TextEditingController();
  List<String> _path = [];
  List<String>? _folders;
  bool _busy = false;
  String? _error;
  String? _ok;

  KoofrClient get _client => KoofrClient(_acct);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _folders = null;
      _error = null;
    });
    try {
      final f = await _client.subfolders(_path);
      if (mounted) setState(() => _folders = f);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudieron leer las carpetas: $e');
    }
  }

  Future<void> _create() async {
    final n = KoofrClient.cleanName(_name.text);
    if (n.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      await _client.ensureDir([..._path, n]);
      _name.clear();
      _ok = 'Carpeta “$n” creada';
      await _load();
    } on KoofrException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo crear: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = _folders;
    return AlertDialog(
      title: const Text('Carpeta nueva en la nube'),
      content: SizedBox(
        width: double.maxFinite,
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
                        _path = [];
                        _load();
                      },
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Subir un nivel',
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: _busy || _path.isEmpty
                      ? null
                      : () {
                          _path = _path.sublist(0, _path.length - 1);
                          _load();
                        },
                ),
                Expanded(
                  child: Text('${_acct.folder}${_path.isEmpty ? '' : '/${_path.join('/')}'}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            SizedBox(
              height: 180,
              child: folders == null
                  ? Center(child: _error == null ? const CircularProgressIndicator() : const SizedBox())
                  : folders.isEmpty
                      ? const Center(child: Text('Sin subcarpetas', style: TextStyle(color: Colors.white54)))
                      : ListView(
                          children: [
                            for (final f in folders)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.folder_outlined, size: 20),
                                title: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: _busy
                                    ? null
                                    : () {
                                        _path = [..._path, f];
                                        _load();
                                      },
                              ),
                          ],
                        ),
            ),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nombre de la carpeta nueva'),
            ),
            if (_ok != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_ok!, style: const TextStyle(color: Colors.greenAccent))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        FilledButton(
          onPressed: _busy || KoofrClient.cleanName(_name.text).isEmpty ? null : _create,
          child: const Text('Crear aquí'),
        ),
      ],
    );
  }
}
