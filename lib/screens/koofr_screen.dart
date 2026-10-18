import 'package:flutter/material.dart';

import '../data/koofr_client.dart';
import '../data/koofr_settings.dart';
import '../data/vinyl_store.dart';

/// Conecta Koofr (WebDAV) y arma la biblioteca con los FLAC de la nube.
class KoofrScreen extends StatefulWidget {
  const KoofrScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<KoofrScreen> createState() => _KoofrScreenState();
}

class _KoofrScreenState extends State<KoofrScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _folder = TextEditingController(text: 'Música');
  bool _busy = false;
  bool _connected = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    KoofrSettings.load().then((s) {
      if (s == null || !mounted) return;
      setState(() {
        _email.text = s.email;
        _folder.text = s.folder;
        _connected = true;
        _status = 'Conectado. Contraseña guardada.';
      });
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    var password = _password.text.trim();
    if (password.isEmpty && _connected) {
      password = (await KoofrSettings.load())?.password ?? '';
    }
    final email = _email.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _status = 'Escribe tu correo y la contraseña de aplicación.');
      return;
    }
    final s = KoofrSettings(
      email: email,
      password: password,
      folder: _folder.text.trim().isEmpty ? 'Música' : _folder.text.trim(),
    );
    setState(() {
      _busy = true;
      _status = 'Conectando…';
    });
    try {
      final client = KoofrClient(s);
      final albums = await client.scan(
        onProgress: (name) {
          if (mounted) setState(() => _status = 'Leyendo $name…');
        },
      );
      await s.save();
      await widget.store.replaceRemote(albums);
      if (!mounted) return;
      setState(() {
        _connected = true;
        _password.clear();
        _status = albums.isEmpty
            ? 'Conectado, pero no encontré audio. ${client.diagnostic}'
            : '${albums.length} álbumes agregados a tu biblioteca.';
      });
    } on KoofrException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = 'No se pudo conectar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await KoofrSettings.clear();
    await widget.store.clearRemote();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _email.clear();
      _password.clear();
      _status = 'Desconectado.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar Koofr')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Estructura en Koofr:\nMúsica / Artista / Álbum / 01 - Pista.flac\n'
            'Agrega cover.jpg en la carpeta del álbum para la carátula.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
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
              helperText: _connected ? 'Déjala vacía para usar la guardada' : null,
            ),
          ),
          TextField(
            controller: _folder,
            decoration: const InputDecoration(labelText: 'Carpeta de música'),
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
            label: Text(_connected ? 'Sincronizar' : 'Guardar y sincronizar'),
            onPressed: _busy ? null : _sync,
          ),
          if (_connected)
            TextButton(
              onPressed: _busy ? null : _disconnect,
              child: const Text('Desconectar'),
            ),
          const SizedBox(height: 12),
          Text(_status),
        ],
      ),
    );
  }
}
