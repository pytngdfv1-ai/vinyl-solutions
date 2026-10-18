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
    if (raw == null) {
      _items = _seed();
      await _save();
    } else {
      try {
        _items = (jsonDecode(raw) as List)
            .map((e) => Vinyl.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _items = _seed();
        await _save();
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

  Future<void> _save() async {
    await _prefs?.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  static List<Vinyl> _seed() {
    const data = [
      ['Luna Roja', 'Neón en la Lluvia', 1978],
      ['The Static Hearts', 'Midnight Radio', 1983],
      ['Dúo Cobalto', 'Mareas', 1971],
      ['Velvet Engine', 'Carretera 66', 1975],
      ['Aurora Sur', 'Canto de Sal', 1989],
      ['Los Faroles', 'Noches de Vinilo', 1969],
      ['Paper Satellites', 'Orbit Lines', 1994],
      ['Mariana Ojeda', 'Casa Abierta', 1981],
      ['Brass & Bones', 'Late Shift', 1973],
      ['Cielo Eléctrico', 'Voltaje', 1986],
      ['Opal Garden', 'Slow Bloom', 1992],
      ['Tango Cósmico', 'Bandoneón 2000', 1999],
      ['Grey Harbor', 'Foghorn', 1977],
      ['Rosa Marea', 'Sur', 1984],
      ['Night Courier', 'Last Train', 1980],
      ['Ámbar', 'Tiempo Lento', 1972],
    ];
    const pool = [
      'Intro', 'Luces de Ciudad', 'Marea Alta', 'Sin Prisa', 'Domingo',
      'Cinta Rota', 'Autopista', 'Eco', 'Medianoche', 'Último Tren',
    ];
    return [
      for (var i = 0; i < data.length; i++)
        Vinyl(
          id: 'seed_$i',
          artist: data[i][0] as String,
          title: data[i][1] as String,
          year: data[i][2] as int,
          hue: (i * 23.0) % 360,
          tracks: [for (var k = 0; k < 8; k++) pool[(i + k * 3) % pool.length]],
          owned: i % 3 == 0,
        ),
    ];
  }
}
