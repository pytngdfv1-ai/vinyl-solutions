import 'package:flutter/material.dart';

import '../data/koofr_client.dart';
import '../data/koofr_settings.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';

/// Agrega o edita una cuenta de Koofr y la sincroniza.
class KoofrAccountScreen extends StatefulWidget {
  const KoofrAccountScreen({super.key, required this.store, this.account});

  final VinylStore store;
  final KoofrSettings? account;

  @override
  State<KoofrAccountScreen> createState() => _KoofrAccountScreenState();
}

class _KoofrAccountScreenState extends State<KoofrAccountScreen> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _genre = TextEditingController(text: widget.account?.genre ?? '');
  late final _email = TextEditingController(text: widget.account?.email ?? '');
  final _password = TextEditingController();
  late final _folder = TextEditingController(text: widget.account?.folder ?? 'Música');
  late String _split = widget.account?.split ?? 'auto';
  bool _busy = false;
  String _status = '';

  bool get _editing => widget.account != null;

  @override
  void dispose() {
    _name.dispose();
    _genre.dispose();
    _email.dispose();
    _password.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final password = _password.text.trim().isEmpty
        ? (widget.account?.password ?? '')
        : _password.text.trim();
    final email = _email.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _status = 'Escribe tu correo y la contraseña de aplicación.');
      return;
    }
    final s = KoofrSettings(
      id: widget.account?.id ?? KoofrAccounts.newId(),
      name: _name.text.trim().isEmpty ? 'Koofr' : _name.text.trim(),
      genre: _genre.text.trim(),
      email: email,
      password: password,
      folder: _folder.text.trim().isEmpty ? 'Música' : _folder.text.trim(),
      split: _split,
    );
    setState(() {
      _busy = true;
      _status = 'Conectando…';
    });
    try {
      final summary = await LibrarySync.syncAccount(
        s,
        widget.store,
        onProgress: (n) {
          if (mounted) setState(() => _status = 'Leyendo $n…');
        },
      );
      if (!mounted) return;
      setState(() {
        _password.clear();
        _status = summary;
      });
    } on KoofrException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = 'No se pudo conectar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final a = widget.account!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text('Se quitan "${a.name}" y sus álbumes de la app. Tus archivos en Koofr no se tocan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await KoofrAccounts.remove(a.id);
    await widget.store.removeAccount(a.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar cuenta' : 'Agregar cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre de la nube (ej.: Rock)'),
          ),
          TextField(
            controller: _genre,
            decoration: const InputDecoration(labelText: 'Género (opcional, para filtrar)'),
          ),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo de Koofr'),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña de aplicación',
              helperText: _editing ? 'Déjala vacía para usar la guardada' : null,
            ),
          ),
          TextField(
            controller: _folder,
            decoration: const InputDecoration(labelText: 'Carpeta de música'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _split,
            decoration: const InputDecoration(
              labelText: 'Subcarpetas como bibliotecas',
              helperText: 'Ej.: Música/Inglés y Música/Español → un cajón para cada una',
            ),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Automático')),
              DropdownMenuItem(value: 'yes', child: Text('Sí, cada subcarpeta es una biblioteca')),
              DropdownMenuItem(value: 'no', child: Text('No, una sola biblioteca')),
            ],
            onChanged: (v) => setState(() => _split = v ?? 'auto'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_editing ? 'Guardar y sincronizar' : 'Conectar y sincronizar'),
            onPressed: _busy ? null : _sync,
          ),
          if (_editing)
            TextButton(
              onPressed: _busy ? null : _delete,
              child: const Text('Eliminar cuenta'),
            ),
          const SizedBox(height: 12),
          Text(_status),
        ],
      ),
    );
  }
}
