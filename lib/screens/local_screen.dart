import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/library_settings.dart';
import '../data/local_scanner.dart';
import '../data/vinyl_store.dart';

/// Agrega a la biblioteca una carpeta de música del teléfono.
class LocalScreen extends StatefulWidget {
  const LocalScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _requestAll() async {
    final r = await Permission.manageExternalStorage.request();
    if (!mounted) return;
    setState(() => _status = r.isGranted
        ? 'Acceso concedido. Elige la carpeta otra vez.'
        : 'Sin acceso a todos los archivos.');
  }

  Future<bool> _ensureAccess() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final res = await [Permission.audio, Permission.photos, Permission.storage].request();
    return res.values.any((s) => s.isGranted);
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _status = 'Pidiendo permiso…';
    });
    try {
      if (!await _ensureAccess()) {
        setState(() => _status = 'Necesito permiso para leer tu música.');
        return;
      }
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) {
        setState(() => _status = '');
        return;
      }
      setState(() => _status = 'Leyendo carpeta…');
      final scanner = LocalScanner();
      final reuse = {
        for (final v in widget.store.items)
          if ((v.source ?? '').startsWith('local')) v.id: v,
      };
      final result = await scanner.scan(
        path,
        reuse: reuse,
        onProgress: (n) {
          if (mounted) setState(() => _status = 'Leyendo $n…');
        },
      );
      await widget.store.addAlbums(result.albums);
      if (!mounted) return;
      setState(() => _status = result.albums.isEmpty
          ? 'No encontré álbumes completos. ${scanner.diagnostic}\n'
              '${result.summary(LibrarySettings.minTracks)}\n'
              'Si hay música en la carpeta, toca "Permitir acceso a todos los archivos".'
          : result.summary(LibrarySettings.minTracks));
    } on LocalException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = 'No se pudo leer la carpeta: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carpeta local')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Elige una carpeta de tu teléfono con tu música.\n'
            'Cada carpeta con audio es un álbum y su carpeta padre es el artista. '
            'Agrega cover.jpg en el álbum para la carátula.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: const Text('Elegir carpeta'),
            onPressed: _busy ? null : _pick,
          ),
          TextButton(
            onPressed: _busy ? null : _requestAll,
            child: const Text('Permitir acceso a todos los archivos'),
          ),
          const SizedBox(height: 12),
          Text(_status),
        ],
      ),
    );
  }
}
