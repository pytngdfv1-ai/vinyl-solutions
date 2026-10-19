import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_scanner.dart';
import '../data/vinyl_store.dart';

/// Agrega música guardada en el teléfono (carpeta con FLAC, MP3, etc.).
class LocalScreen extends StatefulWidget {
  const LocalScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  static const _prefKey = 'local_folder';
  String? _folder;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final f = p.getString(_prefKey);
      if (f != null && mounted) setState(() => _folder = f);
    });
  }

  Future<bool> _ensurePermission() async {
    final res = await [Permission.audio, Permission.photos, Permission.storage].request();
    return (res[Permission.audio]?.isGranted ?? false) ||
        (res[Permission.storage]?.isGranted ?? false);
  }

  Future<void> _pick() async {
    if (!await _ensurePermission()) {
      setState(() => _status =
          'Sin permiso para leer audio. Actívalo en Ajustes del teléfono > Apps > VinylSolutions.');
      return;
    }
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    await _scan(dir);
  }

  Future<void> _scan(String dir) async {
    setState(() {
      _busy = true;
      _status = 'Leyendo…';
    });
    try {
      final albums = await LocalScanner.scan(
        dir,
        onProgress: (name) {
          if (mounted) setState(() => _status = 'Leyendo $name…');
        },
      );
      await widget.store.replaceLocal(albums);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, dir);
      if (!mounted) return;
      setState(() {
        _folder = dir;
        _status = albums.isEmpty
            ? 'No encontré audio en esa carpeta.'
            : '${albums.length} álbumes agregados a tu biblioteca.';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'No se pudo leer la carpeta: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    await widget.store.clearLocal();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    if (!mounted) return;
    setState(() {
      _folder = null;
      _status = 'Biblioteca local quitada. Tus archivos no se borraron.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archivos locales')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Elige una carpeta del teléfono con tu música (FLAC, MP3, M4A, OGG…).\n'
            'La app lee las etiquetas del archivo (artista, álbum, portada) y arma los discos.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          if (_folder != null) ...[
            Text('Carpeta: $_folder', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(_folder == null ? 'Elegir carpeta' : 'Elegir otra carpeta'),
            onPressed: _busy ? null : _pick,
          ),
          if (_folder != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Volver a escanear'),
              onPressed: _busy ? null : () => _scan(_folder!),
            ),
            TextButton(
              onPressed: _busy ? null : _remove,
              child: const Text('Quitar biblioteca local'),
            ),
          ],
          const SizedBox(height: 12),
          Text(_status),
        ],
      ),
    );
  }
}
