import 'package:flutter/material.dart';

import '../data/koofr_settings.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import 'koofr_account_screen.dart';

/// Lista de nubes (cuentas de Koofr). Todas forman una sola biblioteca.
class KoofrScreen extends StatefulWidget {
  const KoofrScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<KoofrScreen> createState() => _KoofrScreenState();
}

class _KoofrScreenState extends State<KoofrScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _open([KoofrSettings? a]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KoofrAccountScreen(store: widget.store, account: a),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _syncAll() async {
    setState(() {
      _busy = true;
      _status = 'Sincronizando…';
    });
    final lines = <String>[];
    for (final a in List.of(KoofrAccounts.list)) {
      if (mounted) setState(() => _status = 'Sincronizando ${a.name}…');
      try {
        final r = await LibrarySync.syncAccount(a, widget.store);
        lines.add('${a.name}: ${r.split('\n').first}');
      } catch (e) {
        lines.add('${a.name}: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = lines.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts = KoofrAccounts.list;
    return Scaffold(
      appBar: AppBar(title: const Text('Nubes (Koofr)')),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Agrega las cuentas que quieras. Todas se unen en una sola biblioteca '
              'y se sincronizan al abrir la app. Ponle un género a cada nube para filtrar.\n'
              'Estructura: Música / Artista / Álbum / 01 - Pista.flac',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Aún no hay cuentas.'),
              ),
            for (final a in accounts)
              Card(
                color: const Color(0xFF1B1D1B),
                child: ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(a.genre.isEmpty ? a.name : '${a.name} · ${a.genre}'),
                  subtitle: Text(
                    '${a.email}\n'
                    '${widget.store.items.where((v) => v.source == a.id).length} álbumes',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(a),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar cuenta'),
              onPressed: _busy ? null : () => _open(),
            ),
            if (accounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sincronizar todas'),
                  onPressed: _busy ? null : _syncAll,
                ),
              ),
            const SizedBox(height: 12),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
