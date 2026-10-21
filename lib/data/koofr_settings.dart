import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Una cuenta de Koofr (WebDAV). Las contraseñas se guardan cifradas.
class KoofrSettings {
  const KoofrSettings({
    this.id = 'main',
    this.name = 'Koofr',
    this.genre = '',
    required this.email,
    required this.password,
    this.folder = 'Música',
    this.baseUrl = 'https://app.koofr.net/dav/Koofr',
    this.split = 'auto',
  });

  final String id;
  final String name;
  final String genre;
  final String email;
  final String password;
  final String folder;
  final String baseUrl;

  /// ¿Cada subcarpeta de la carpeta raíz es una biblioteca? 'auto' | 'yes' | 'no'.
  final String split;

  KoofrSettings copyWith({String? split}) => KoofrSettings(
        id: id,
        name: name,
        genre: genre,
        email: email,
        password: password,
        folder: folder,
        baseUrl: baseUrl,
        split: split ?? this.split,
      );

  Map<String, String> get headers => {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$email:$password'))}',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genre': genre,
        'email': email,
        'password': password,
        'folder': folder,
        'split': split,
      };

  factory KoofrSettings.fromJson(Map<String, dynamic> j) => KoofrSettings(
        id: j['id'] as String? ?? 'main',
        name: j['name'] as String? ?? 'Koofr',
        genre: j['genre'] as String? ?? '',
        email: j['email'] as String,
        password: j['password'] as String,
        folder: j['folder'] as String? ?? 'Música',
        split: j['split'] as String? ?? 'auto',
      );

  /// Solo se envían credenciales a servidores de Koofr (nunca a terceros).
  static bool isKoofrUrl(String url) =>
      (Uri.tryParse(url)?.host ?? '').endsWith('koofr.net');

  /// Cabeceras por cuenta. La URL lleva el id de la cuenta en el fragmento
  /// (`#k=<id>`), que no se envía al servidor.
  static final Map<String, Map<String, String>> headersById = {};

  static String tag(String url, String accountId) =>
      Uri.parse(url).replace(fragment: 'k=$accountId').toString();

  /// Cabeceras de autenticación para esta URL (null si no es de Koofr).
  static Map<String, String>? headersFor(String url) {
    if (!isKoofrUrl(url)) return null;
    final f = Uri.tryParse(url)?.fragment ?? '';
    final id = f.startsWith('k=') ? f.substring(2) : null;
    if (id != null && headersById.containsKey(id)) return headersById[id];
    return headersById.values.isEmpty ? null : headersById.values.first;
  }
}

/// Lista de cuentas guardadas en el teléfono.
class KoofrAccounts {
  static List<KoofrSettings> list = [];
  static const _storage = FlutterSecureStorage();
  static const _key = 'koofr_accounts';

  static String newId() => 'k${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  static Future<void> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        list = [
          for (final j in jsonDecode(raw) as List)
            KoofrSettings.fromJson(j as Map<String, dynamic>),
        ];
      } else {
        // Migra la cuenta única de versiones anteriores.
        final e = await _storage.read(key: 'koofr_email');
        final p = await _storage.read(key: 'koofr_password');
        if (e != null && p != null) {
          final f = await _storage.read(key: 'koofr_folder');
          list = [KoofrSettings(email: e, password: p, folder: f ?? 'Música')];
          await _persist();
        }
      }
    } catch (_) {
      list = [];
    }
    _refresh();
  }

  static Future<void> upsert(KoofrSettings a) async {
    final i = list.indexWhere((x) => x.id == a.id);
    list = [...list];
    if (i >= 0) {
      list[i] = a;
    } else {
      list.add(a);
    }
    await _persist();
    _refresh();
  }

  static Future<void> remove(String id) async {
    list = list.where((a) => a.id != id).toList();
    await _persist();
    _refresh();
  }

  static Future<void> _persist() =>
      _storage.write(key: _key, value: jsonEncode([for (final a in list) a.toJson()]));

  static void _refresh() {
    KoofrSettings.headersById
      ..clear()
      ..addAll({for (final a in list) a.id: a.headers});
  }
}
