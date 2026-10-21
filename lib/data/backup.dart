import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/vinyl.dart';
import 'koofr_settings.dart';
import 'library_settings.dart';
import 'library_sync.dart';
import 'vinyl_store.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Copia de seguridad cifrada (AES-256-GCM, clave derivada con PBKDF2).
/// Guarda cuentas de Koofr, ajustes y discos manuales / marcados. La música
/// y las portadas se reconstruyen al sincronizar.
class BackupService {
  static const _iterations = 100000;

  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

  static Future<Uint8List> build(String password, VinylStore store) async {
    final data = {
      'app': 'vinyl_solutions',
      'v': 1,
      'accounts': [for (final a in KoofrAccounts.list) a.toJson()],
      'minTracks': LibrarySettings.minTracks,
      'notOwned': [
        for (final v in store.items)
          if (!v.owned) v.id,
      ],
      'manual': [
        for (final v in store.items)
          if (v.source == null && !v.id.startsWith('dav_')) v.toJson(),
      ],
    };
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: await _key(password, salt),
    );
    final out = {
      'format': 'vinylbackup',
      'v': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(out)));
  }

  /// Restaura la copia y lanza la sincronización. Devuelve un resumen.
  static Future<String> restore(Uint8List bytes, String password, VinylStore store) async {
    Map<String, dynamic> f;
    try {
      f = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (f['format'] != 'vinylbackup') throw const FormatException();
    } catch (_) {
      throw const BackupException('El archivo no es una copia de VinylSolutions');
    }
    List<int> plain;
    try {
      final box = SecretBox(
        base64Decode(f['data'] as String),
        nonce: base64Decode(f['nonce'] as String),
        mac: Mac(base64Decode(f['mac'] as String)),
      );
      plain = await AesGcm.with256bits().decrypt(
        box,
        secretKey: await _key(password, base64Decode(f['salt'] as String)),
      );
    } catch (_) {
      throw const BackupException('Clave incorrecta o archivo dañado');
    }
    final d = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;

    final accounts = [
      for (final j in (d['accounts'] as List? ?? const []))
        KoofrSettings.fromJson(j as Map<String, dynamic>),
    ];
    for (final a in accounts) {
      await KoofrAccounts.upsert(a);
    }
    final min = (d['minTracks'] as num?)?.toInt();
    if (min != null) await LibrarySettings.save(min.clamp(1, 15));
    final manual = [
      for (final j in (d['manual'] as List? ?? const []))
        Vinyl.fromJson(j as Map<String, dynamic>),
    ];
    if (manual.isNotEmpty) await store.restoreManual(manual);
    final notOwned = (d['notOwned'] as List? ?? const []).cast<String>();
    if (notOwned.isNotEmpty) await store.markNotOwned(notOwned);

    // Sincroniza las nubes en segundo plano y reaplica las marcas.
    LibrarySync.syncAll(store).then((_) => store.markNotOwned(notOwned));
    return '${accounts.length} cuentas restauradas. Sincronizando en segundo plano…';
  }
}
