import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credenciales de Koofr (WebDAV). Se guardan cifradas en el teléfono.
class KoofrSettings {
  const KoofrSettings({
    required this.email,
    required this.password,
    this.folder = 'Música',
    this.baseUrl = 'https://app.koofr.net/dav/Koofr',
  });

  final String email;
  final String password;
  final String folder;
  final String baseUrl;

  /// Cabeceras activas para audio e imágenes (se llena al iniciar la app).
  static Map<String, String> activeHeaders = {};

  static const _storage = FlutterSecureStorage();

  Map<String, String> get headers => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$email:$password'))}',
      };

  static Future<KoofrSettings?> load() async {
    try {
      final e = await _storage.read(key: 'koofr_email');
      final p = await _storage.read(key: 'koofr_password');
      if (e == null || p == null) return null;
      final f = await _storage.read(key: 'koofr_folder');
      return KoofrSettings(email: e, password: p, folder: f ?? 'Música');
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    await _storage.write(key: 'koofr_email', value: email);
    await _storage.write(key: 'koofr_password', value: password);
    await _storage.write(key: 'koofr_folder', value: folder);
    activeHeaders = headers;
  }

  static Future<void> clear() async {
    await _storage.delete(key: 'koofr_email');
    await _storage.delete(key: 'koofr_password');
    await _storage.delete(key: 'koofr_folder');
    activeHeaders = {};
  }
}
