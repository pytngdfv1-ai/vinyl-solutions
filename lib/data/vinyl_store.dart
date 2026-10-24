import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';
import 'library_order.dart';

/// Biblioteca local-first: todo vive en el dispositivo (SharedPreferences).
class VinylStore extends ChangeNotifier {
  static const _key = 'vinyls_v1';

  SharedPreferences? _prefs;
  List<Vinyl> _items = [];

  List<Vinyl> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final c = _prefs!.getString('move_carry_v1');
      if (c != null) {
        _carry = {
          for (final e in (jsonDecode(c) as Map<String, dynamic>).entries)
            e.key: Map<String, dynamic>.from(e.value as Map),
        };
      }
    } catch (_) {}
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        _items = (jsonDecode(raw) as List)
            .map((e) => Vinyl.fromJson(e as Map<String, dynamic>))
            // Elimina los discos de demostración de versiones anteriores.
            .where((v) => !v.id.startsWith('seed_'))
            .toList();
      } catch (_) {
        _items = [];
      }
    }
    notifyListeners();
  }

  Future<void> add({
    required String artist,
    required String title,
    required int year,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _items = [
      Vinyl(
        id: id,
        title: title,
        artist: artist,
        year: year,
        hue: (title.hashCode.abs() % 360).toDouble(),
        tracks: const ['Pista 1', 'Pista 2', 'Pista 3', 'Pista 4'],
        owned: true,
      ),
      ..._items,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> toggleOwned(String id) async {
    _items = [
      for (final v in _items) v.id == id ? v.copyWith(owned: !v.owned) : v,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _items = _items.where((v) => v.id != id).toList();
    notifyListeners();
    await _save();
  }

  /// Datos que se conservan al mover: ruta nueva (relativa) -> {cover, owned, genre}.
  Map<String, Map<String, dynamic>> _carry = {};

  Future<void> addCarry(Map<String, Map<String, dynamic>> m) async {
    _carry = {..._carry, ...m};
    await _prefs?.setString('move_carry_v1', jsonEncode(_carry));
  }

  Future<void> removeMany(Iterable<String> ids) async {
    final s = ids.toSet();
    _items = _items.where((v) => !s.contains(v.id)).toList();
    notifyListeners();
    await _save();
  }

  /// Borra toda la biblioteca guardada en la app.
  Future<void> clearAll() async {
    _items = [];
    notifyListeners();
    await _save();
  }

  bool _fromAccount(Vinyl v, String accountId) =>
      sourceInAccount(v.source, accountId) || (v.source == null && v.id.startsWith('dav_'));

  Vinyl _applyCarry(Vinyl v, Map<String, bool> owned, String? genre, String accountId,
      List<String> used) {
    var r = v.copyWith(owned: owned[v.id] ?? true, genre: genre, source: v.source ?? accountId);
    if (v.trackUrls.isEmpty || _carry.isEmpty) return r;
    final path = Uri.decodeFull(Uri.parse(v.trackUrls.first).removeFragment().path);
    for (final e in _carry.entries) {
      if (path.endsWith('/${e.key}')) {
        used.add(e.key);
        final c = e.value['cover'] as String?;
        r = r.copyWith(
          owned: owned.containsKey(v.id) ? r.owned : (e.value['owned'] as bool? ?? true),
          coverUrl: v.coverUrl ?? c,
        );
        break;
      }
    }
    return r;
  }

  /// Reemplaza los discos de una cuenta de Koofr por el último escaneo.
  Future<void> replaceAccount(String accountId, List<Vinyl> scanned, {String? genre}) async {
    final owned = {for (final v in _items) v.id: v.owned};
    final others = _items.where((v) => !_fromAccount(v, accountId)).toList();
    final used = <String>[];
    final fresh = [
      for (final v in scanned) _applyCarry(v, owned, genre, accountId, used),
    ];
    if (used.isNotEmpty) {
      for (final k in used) {
        _carry.remove(k);
      }
      await _prefs?.setString('move_carry_v1', jsonEncode(_carry));
    }
    _items = [...fresh, ...others];
    notifyListeners();
    await _save();
  }

  Future<void> removeAccount(String accountId) async {
    _items = _items.where((v) => !_fromAccount(v, accountId)).toList();
    notifyListeners();
    await _save();
  }

  /// Agrega (o actualiza) álbumes, por ejemplo de una carpeta local.
  Future<void> addAlbums(List<Vinyl> albums) async {
    final ids = {for (final a in albums) a.id};
    final owned = {for (final v in _items) v.id: v.owned};
    _items = [
      for (final a in albums) a.copyWith(owned: owned[a.id] ?? true, source: a.source ?? 'local'),
      ..._items.where((v) => !ids.contains(v.id)),
    ];
    notifyListeners();
    await _save();
  }

  /// Restaura discos agregados a mano (copia de seguridad).
  Future<void> restoreManual(List<Vinyl> list) async {
    final ids = {for (final v in list) v.id};
    _items = [...list, ..._items.where((v) => !ids.contains(v.id))];
    notifyListeners();
    await _save();
  }

  /// Marca como "no en colección" los discos indicados (copia de seguridad).
  Future<void> markNotOwned(List<String> ids) async {
    final s = ids.toSet();
    _items = [for (final v in _items) s.contains(v.id) ? v.copyWith(owned: false) : v];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }
}
