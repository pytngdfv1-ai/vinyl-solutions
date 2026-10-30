import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/vinyl_store.dart';

/// Exportar e importar la configuración (cuentas, ajustes) en un archivo cifrado.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String _status = '';

  Future<String?> _ask(String title, {bool confirm = false}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    String? error;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: a,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Clave de la copia'),
              ),
              if (confirm)
                TextField(
                  controller: b,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Repite la clave'),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (a.text.length < 4) {
                  setLocal(() => error = 'Mínimo 4 caracteres');
                } else if (confirm && a.text != b.text) {
                  setLocal(() => error = 'Las claves no coinciden');
                } else {
                  Navigator.of(ctx).pop(a.text);
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
    a.dispose();
    b.dispose();
    return r;
  }

  Future<void> _export() async {
    final pw = await _ask('Clave para cifrar la copia', confirm: true);
    if (pw == null) return;
    setState(() {
      _busy = true;
      _status = 'Cifrando…';
    });
    try {
      final bytes = await BackupService.build(pw, widget.store);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: 'MiBiblioteca.vinylbackup',
        bytes: bytes,
      );
      if (mounted) {
        setState(() => _status = path == null ? 'Cancelado.' : 'Copia guardada. Guarda también tu clave.');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'No se pudo exportar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    final pw = await _ask('Clave de la copia');
    if (pw == null) return;
    setState(() {
      _busy = true;
      _status = 'Descifrando…';
    });
    try {
      final msg = await BackupService.restore(bytes, pw, widget.store);
      if (mounted) setState(() => _status = msg);
    } on BackupException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = 'No se pudo importar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Guarda tus cuentas de Koofr (con contraseña, cifradas con la clave que elijas), '
            'los ajustes y los discos agregados a mano en un archivo.\n\n'
            'Al importarla, la app restaura las cuentas y sincroniza sola. '
            'La música no se guarda: sigue en tus nubes. Las carpetas del teléfono '
            'se vuelven a agregar desde "Carpeta del teléfono".',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Exportar copia'),
            onPressed: _busy ? null : _export,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Importar copia'),
            onPressed: _busy ? null : _import,
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(_status),
        ],
      ),
    );
  }
}
