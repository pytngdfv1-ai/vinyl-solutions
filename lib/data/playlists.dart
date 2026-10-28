import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';

/// Un tema dentro de una playlist (con lo necesario para sonar y mostrarse solo).
class PlEntry {
  const PlEntry({
    required this.url,
    required this.title,
    required this.artist,
    required this.album,
    required this.vinylId,
    this.cover,
    this.hue = 0,
  });

  final String url;
  final String title;
  final String artist;
  final String album;
  final String vinylId;
  final String? cover;
  final double hue;

  factory PlEntry.of(Vinyl v, int i) {
    final idx = i.clamp(0, v.trackUrls.length - 1).toInt();
    return PlEntry(
      url: v.trackUrls[idx],
      title: idx < v.tracks.length ? v.tracks[idx] : v.title,
      artist: v.artist,
      album: v.title,
      vinylId: v.id,
      cover: v.coverUrl,
      hue: v.hue,
    );
  }

  /// Disco "de mentira" para dibujar la portada del tema.
  Vinyl asVinyl() => Vinyl(
        id: vinylId,
        title: album,
        artist: artist,
        year: 0,
        hue: hue,
        tracks: [title],
        coverUrl: cover,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'artist': artist,
        'album': album,
        'vinylId': vinylId,
        'cover': cover,
        'hue': hue,
      };

  factory PlEntry.fromJson(Map<String, dynamic> j) => PlEntry(
        url: j['url'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        album: j['album'] as String? ?? '',
        vinylId: j['vinylId'] as String? ?? '',
        cover: j['cover'] as String?,
        hue: (j['hue'] as num?)?.toDouble() ?? 0,
      );
}

class Playlist {
  Playlist(this.id, this.name, this.entries);
  final String id;
  String name;
  final List<PlEntry> entries;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': [for (final e in entries) e.toJson()],
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        j['id'] as String,
        j['name'] as String? ?? 'Playlist',
        [for (final e in (j['entries'] as List? ?? const [])) PlEntry.fromJson(e as Map<String, dynamic>)],
      );
}

/// Playlists guardadas en el dispositivo.
class Playlists extends ChangeNotifier {
  Playlists._();
  static final Playlists instance = Playlists._();
  static const _key = 'playlists_v1';

  SharedPreferences? _prefs;
  List<Playlist> _lists = [];
  List<Playlist> get lists => List.unmodifiable(_lists);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(_key);
      if (raw != null) {
        _lists = [for (final j in jsonDecode(raw) as List) Playlist.fromJson(j as Map<String, dynamic>)];
      }
    } catch (_) {
      _lists = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs?.setString(_key, jsonEncode([for (final p in _lists) p.toJson()]));
  }

  List<Map<String, dynamic>> export() => [for (final p in _lists) p.toJson()];

  Future<void> import(List<dynamic> data) async {
    for (final j in data) {
      final p = Playlist.fromJson(j as Map<String, dynamic>);
      if (_lists.every((x) => x.id != p.id)) _lists.add(p);
    }
    await _save();
  }

  Future<Playlist> create(String name) async {
    final p = Playlist(DateTime.now().microsecondsSinceEpoch.toString(), name.trim().isEmpty ? 'Playlist' : name.trim(), []);
    _lists.add(p);
    await _save();
    return p;
  }

  Future<void> rename(String id, String name) async {
    for (final p in _lists) {
      if (p.id == id && name.trim().isNotEmpty) p.name = name.trim();
    }
    await _save();
  }

  Future<void> delete(String id) async {
    _lists.removeWhere((p) => p.id == id);
    await _save();
  }

  /// Agrega un tema (si ya está en la lista, no lo repite).
  Future<bool> add(String id, PlEntry e) async {
    for (final p in _lists) {
      if (p.id == id) {
        if (p.entries.any((x) => x.url == e.url)) return false;
        p.entries.add(e);
        await _save();
        return true;
      }
    }
    return false;
  }

  Future<void> removeAt(String id, int i) async {
    for (final p in _lists) {
      if (p.id == id && i >= 0 && i < p.entries.length) p.entries.removeAt(i);
    }
    await _save();
  }

  Future<void> move(String id, int from, int to) async {
    for (final p in _lists) {
      if (p.id == id && from >= 0 && from < p.entries.length) {
        final e = p.entries.removeAt(from);
        p.entries.insert(to.clamp(0, p.entries.length).toInt(), e);
      }
    }
    await _save();
  }
}
