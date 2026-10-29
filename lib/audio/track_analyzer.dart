import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/koofr_settings.dart';

/// Tempo y primer instante con sonido de un tema.
class TrackInfo {
  const TrackInfo(this.bpm, this.startMs);

  /// 0 = no se pudo detectar.
  final double bpm;
  final int startMs;
}

/// Analiza el inicio de los temas (Android: decodifica con MediaCodec) y recuerda el resultado.
class TrackAnalyzer {
  static const _ch = MethodChannel('vinyl/analyze');
  static const _prefKey = 'track_info_v1';
  static const _maxBytes = 12 * 1024 * 1024;
  static Map<String, TrackInfo>? _cache;
  static final Map<String, Future<TrackInfo?>> _running = {};

  static Future<void> _load() async {
    if (_cache != null) return;
    _cache = {};
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefKey);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          final l = v as List;
          _cache![k] = TrackInfo((l[0] as num).toDouble(), (l[1] as num).toInt());
        });
      }
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, jsonEncode({for (final e in _cache!.entries) e.key: [e.value.bpm, e.value.startMs]}));
    } catch (_) {}
  }

  /// Resultado ya conocido (sin analizar).
  static TrackInfo? known(String url) => _cache?[url];

  static Future<TrackInfo?> analyze(String url) async {
    if (!Platform.isAndroid) return null;
    await _load();
    final c = _cache![url];
    if (c != null) return c;
    return _running[url] ??= _run(url).whenComplete(() => _running.remove(url));
  }

  static Future<TrackInfo?> _run(String url) async {
    File? tmp;
    try {
      String path;
      if (url.startsWith('file:')) {
        path = Uri.parse(url).toFilePath();
      } else {
        final dir = await getTemporaryDirectory();
        tmp = File('${dir.path}/an_${url.hashCode.toUnsigned(32)}.bin');
        await _download(url, tmp);
        path = tmp.path;
      }
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('analyze', {'path': path}).timeout(const Duration(seconds: 60));
      if (r == null) return null;
      final info = TrackInfo((r['bpm'] as num).toDouble(), (r['startMs'] as num).toInt());
      _cache![url] = info;
      await _save();
      return info;
    } catch (_) {
      return null;
    } finally {
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  /// Baja solo el comienzo del archivo (el resto no hace falta para analizar).
  static Future<void> _download(String url, File out) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url).replace(fragment: ''))
        ..headers.addAll({...(KoofrSettings.headersFor(url) ?? const {}), 'Range': 'bytes=0-${_maxBytes - 1}'});
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 && res.statusCode != 206) throw Exception('HTTP ${res.statusCode}');
      final sink = out.openWrite();
      var total = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        total += chunk.length;
        if (total >= _maxBytes) break;
      }
      await sink.close();
    } finally {
      client.close();
    }
  }
}
