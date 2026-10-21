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

  /// Borra toda la biblioteca guardada en la app.
  Future<void> clearAll() async {
    _items = [];
    notifyListeners();
    await _save();
  }

  bool _fromAccount(Vinyl v, String accountId) =>
      sourceInAccount(v.source, accountId) || (v.source == null && v.id.startsWith('dav_'));

  /// Reemplaza los discos de una cuenta de Koofr por el último escaneo.
  Future<void> replaceAccount(String accountId, List<Vinyl> scanned, {String? genre}) async {
    final owned = {for (final v in _items) v.id: v.owned};
    final others = _items.where((v) => !_fromAccount(v, accountId)).toList();
    final fresh = [
      for (final v in scanned)
        v.copyWith(owned: owned[v.id] ?? true, genre: genre, source: v.source ?? accountId),
    ];
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
