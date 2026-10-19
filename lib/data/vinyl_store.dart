import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';

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

  /// Reemplaza los discos de una fuente (prefijo de id) por el último escaneo.
  Future<void> replaceSource(String prefix, List<Vinyl> scanned) async {
    final owned = {for (final v in _items) v.id: v.owned};
    final others = _items.where((v) => !v.id.startsWith(prefix)).toList();
    final fresh = [
      for (final v in scanned) v.copyWith(owned: owned[v.id] ?? true),
    ];
    _items = [...fresh, ...others];
    notifyListeners();
    await _save();
  }

  /// Discos de Koofr (ids `dav_`).
  Future<void> replaceRemote(List<Vinyl> scanned) => replaceSource('dav_', scanned);
  Future<void> clearRemote() => replaceSource('dav_', const []);

  /// Discos de archivos locales (ids `loc_`).
  Future<void> replaceLocal(List<Vinyl> scanned) => replaceSource('loc_', scanned);
  Future<void> clearLocal() => replaceSource('loc_', const []);

  Future<void> _save() async {
    await _prefs?.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }
}
