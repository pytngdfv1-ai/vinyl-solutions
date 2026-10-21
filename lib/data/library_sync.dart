import 'package:flutter/foundation.dart';

import 'koofr_client.dart';
import 'koofr_settings.dart';
import 'library_order.dart';
import 'library_settings.dart';
import 'vinyl_store.dart';

/// Sincronización de las cuentas de Koofr con la biblioteca.
class LibrarySync {
  /// Mensaje mientras se sincroniza en segundo plano (null = inactivo).
  static final ValueNotifier<String?> busy = ValueNotifier<String?>(null);
  static bool _running = false;

  /// Sincroniza una cuenta y devuelve un resumen. Lanza si no puede conectar.
  static Future<String> syncAccount(
    KoofrSettings a,
    VinylStore store, {
    void Function(String)? onProgress,
    bool keepIfEmpty = false,
  }) async {
    final client = KoofrClient(a);
    final reuse = {
      for (final v in store.items)
        if (sourceInAccount(v.source, a.id)) v.id: v,
    };
    final result = await client.scan(onProgress: onProgress, reuse: reuse);
    if (result.albums.isEmpty && keepIfEmpty) return 'Sin cambios';
    // Si detectó carpetas por categoría (Inglés / Español…), lo recuerda.
    await KoofrAccounts.upsert(client.detectedSplit == true ? a.copyWith(split: 'yes') : a);
    await store.replaceAccount(
      a.id,
      result.albums,
      genre: a.genre.trim().isEmpty ? null : a.genre.trim(),
    );
    final min = LibrarySettings.minTracks;
    return result.albums.isEmpty
        ? 'Conectado, pero no encontré álbumes completos. ${client.diagnostic}\n${result.summary(min)}'
        : result.summary(min);
  }

  /// Sincroniza todas las cuentas guardadas (al abrir la app).
  static Future<void> syncAll(VinylStore store) async {
    if (_running || KoofrAccounts.list.isEmpty) return;
    _running = true;
    try {
      for (final a in List.of(KoofrAccounts.list)) {
        busy.value = 'Sincronizando ${a.name}…';
        try {
          await syncAccount(a, store, keepIfEmpty: true);
        } catch (_) {
          // Sin conexión o contraseña cambiada: se conserva lo guardado.
        }
      }
    } finally {
      _running = false;
      busy.value = null;
    }
  }
}
