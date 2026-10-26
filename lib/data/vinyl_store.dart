import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';
import 'booklet_lite.dart';
import 'classifier.dart';
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
    try {
      final a = _prefs!.getString('artist_lang_v1');
      if (a != null) _artistLang = Map<String, String>.from(jsonDecode(a) as Map);
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
    // Biblioteca guardada antes de la clasificación: se clasifica en segundo plano.
    unawaited(reclassify());
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

  /// Marca / desmarca un disco como cover (casetero).
  Future<void> setCassette(String id, bool on, {String? coverUrl}) async {
    _items = [
      for (final v in _items)
        v.id == id
            ? v.copyWith(cassette: on, coverManual: true, coverUrl: v.coverUrl ?? coverUrl)
            : v,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> markCassette(List<String> ids) async {
    final s = ids.toSet();
    _items = [
      for (final v in _items)
        s.contains(v.id) ? v.copyWith(cassette: true, coverManual: true) : v,
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
  /// Recuerda por artista el idioma que el usuario eligió: artista -> 'en' | 'es'.
  Map<String, String> _artistLang = {};

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

  /// Aplica lo que el usuario fijó a mano (idioma, cover) y el idioma recordado por artista.
  Vinyl _keepManual(Vinyl v, Vinyl? old) {
    var r = v;
    if (old != null && old.langManual) {
      r = r.copyWith(lang: old.lang, langManual: true);
    } else {
      final a = _artistLang[Classifier.artistKey(v.artist)];
      if (a != null) r = r.copyWith(lang: a);
    }
    if (old != null && old.coverManual) {
      r = r.copyWith(cassette: old.cassette, coverManual: true);
    }
    return r;
  }

  Vinyl _applyCarry(Vinyl v, Vinyl? old, Map<String, bool> owned, String? genre,
      String accountId, List<String> used) {
    var r = _keepManual(
        v.copyWith(owned: owned[v.id] ?? true, genre: genre, source: v.source ?? accountId), old);
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
        if (e.value['coverManual'] == true) {
          r = r.copyWith(cassette: e.value['cassette'] == true, coverManual: true);
        }
        if (e.value['langManual'] == true && e.value['lang'] is String) {
          r = r.copyWith(lang: e.value['lang'] as String, langManual: true);
        }
        break;
      }
    }
    return r;
  }

  /// Reemplaza los discos de una cuenta de Koofr por el último escaneo.
  Future<void> replaceAccount(String accountId, List<Vinyl> scanned, {String? genre}) async {
    final owned = {for (final v in _items) v.id: v.owned};
    final oldById = {for (final v in _items) v.id: v};
    final others = _items.where((v) => !_fromAccount(v, accountId)).toList();
    final used = <String>[];
    final fresh = [
      for (final v in scanned) _applyCarry(v, oldById[v.id], owned, genre, accountId, used),
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
    unawaited(BookletLite.autoConvert(() => _items));
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
    final oldById = {for (final v in _items) v.id: v};
    _items = [
      for (final a in albums)
        _keepManual(
            a.copyWith(owned: owned[a.id] ?? true, source: a.source ?? 'local'), oldById[a.id]),
      ..._items.where((v) => !ids.contains(v.id)),
    ];
    notifyListeners();
    await _save();
    unawaited(BookletLite.autoConvert(() => _items));
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

  /// Agrega un PDF al libreto del disco (por ejemplo, uno creado desde las imágenes).
  Future<void> addPdf(String id, String url) async {
    _items = [
      for (final v in _items)
        if (v.id == id && !v.pdfs.contains(url)) v.copyWith(pdfs: [...v.pdfs, url]) else v,
    ];
    notifyListeners();
    await _save();
  }

  /// El usuario fija el idioma de un disco (null = volver a automático).
  /// Se recuerda por artista y se aplica a sus demás discos no corregidos a mano.
  Future<void> setLang(String id, String? lang) async {
    final cur = _items.where((v) => v.id == id).firstOrNull;
    if (cur == null) return;
    final key = Classifier.artistKey(cur.artist);
    if (lang == null) {
      _artistLang.remove(key);
      _items = [
        for (final v in _items)
          if (v.id == id)
            v.copyWith(langManual: false, lang: Classifier.detectLang(v), clearLang: Classifier.detectLang(v) == null)
          else
            v,
      ];
    } else {
      _artistLang[key] = lang;
      _items = [
        for (final v in _items)
          if (v.id == id)
            v.copyWith(lang: lang, langManual: true)
          else if (!v.langManual && Classifier.artistKey(v.artist) == key)
            v.copyWith(lang: lang)
          else
            v,
      ];
    }
    notifyListeners();
    await _prefs?.setString('artist_lang_v1', jsonEncode(_artistLang));
    await _save();
  }

  /// Idioma deducido automáticamente (p. ej. de la letra). No toca lo fijado a mano.
  Future<void> setAutoLang(String id, String lang) async {
    final cur = _items.where((v) => v.id == id).firstOrNull;
    if (cur == null || cur.langManual || cur.lang != null) return;
    _items = [for (final v in _items) v.id == id ? v.copyWith(lang: lang) : v];
    notifyListeners();
    await _save();
  }

  /// Clasifica en segundo plano lo que aún no tiene idioma (sin bloquear la interfaz)
  /// y detecta covers por el nombre. Nunca toca lo corregido a mano.
  Future<void> reclassify() async {
    final changes = <String, ({String? lang, bool? cover})>{};
    var n = 0;
    for (final v in List.of(_items)) {
      if (v.isDivider) continue;
      String? lang;
      if (!v.langManual && v.lang == null) {
        lang = _artistLang[Classifier.artistKey(v.artist)] ?? Classifier.detectLang(v);
      }
      final cover = !v.coverManual && !v.cassette && Classifier.detectCover(v) ? true : null;
      if (lang != null || cover != null) changes[v.id] = (lang: lang, cover: cover);
      if (++n % 60 == 0) await Future<void>.delayed(Duration.zero);
    }
    if (changes.isEmpty) return;
    _items = [
      for (final v in _items)
        if (changes[v.id] != null)
          v.copyWith(lang: changes[v.id]!.lang, cassette: changes[v.id]!.cover)
        else
          v,
    ];
    notifyListeners();
    await _save();
  }

  /// Copia de seguridad: idiomas fijados a mano, idioma por artista y covers manuales.
  Map<String, dynamic> classExport() => {
        'langs': {
          for (final v in _items)
            if (v.langManual && v.lang != null) v.id: v.lang,
        },
        'artistLang': _artistLang,
        'coverManual': {
          for (final v in _items)
            if (v.coverManual) v.id: v.cassette,
        },
      };

  Future<void> classImport(Map<String, dynamic> d) async {
    final langs = Map<String, String>.from((d['langs'] as Map?) ?? const {});
    final cm = Map<String, bool>.from((d['coverManual'] as Map?) ?? const {});
    _artistLang = {..._artistLang, ...Map<String, String>.from((d['artistLang'] as Map?) ?? const {})};
    _items = [
      for (final v in _items)
        v.copyWith(
          lang: langs[v.id],
          langManual: langs.containsKey(v.id) ? true : null,
          cassette: cm[v.id],
          coverManual: cm.containsKey(v.id) ? true : null,
        ),
    ];
    notifyListeners();
    await _prefs?.setString('artist_lang_v1', jsonEncode(_artistLang));
    await _save();
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }
}
