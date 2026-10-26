import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';

enum CajonKind { albums, singles, covers, unclassified }

/// Un cajón del menú principal: tipo + idioma ("Álbumes en inglés"…).
class Cajon {
  const Cajon(this.kind, this.lang);

  final CajonKind kind;

  /// 'en', 'es' o null (solo "Sin clasificar").
  final String? lang;

  String get key => '${kind.name}_${lang ?? 'x'}';

  String get defaultName {
    final l = lang == 'en' ? 'inglés' : 'español';
    switch (kind) {
      case CajonKind.albums:
        return 'Álbumes en $l';
      case CajonKind.singles:
        return 'Temas sueltos en $l';
      case CajonKind.covers:
        return 'Covers en $l';
      case CajonKind.unclassified:
        return 'Sin clasificar';
    }
  }

  /// Nombre editable por el usuario (o el de fábrica).
  String get name => ChestNames.of(this);

  /// Un cover va solo a su cajón de covers; lo que no tiene idioma, a "Sin clasificar".
  bool matches(Vinyl v) {
    if (v.isDivider) return false;
    if (kind == CajonKind.unclassified) return v.lang == null;
    if (v.lang != lang) return false;
    switch (kind) {
      case CajonKind.covers:
        return v.cassette;
      case CajonKind.singles:
        return !v.cassette && v.single;
      case CajonKind.albums:
        return !v.cassette && !v.single;
      case CajonKind.unclassified:
        return false;
    }
  }

  static const all = <Cajon>[
    Cajon(CajonKind.albums, 'en'),
    Cajon(CajonKind.albums, 'es'),
    Cajon(CajonKind.singles, 'en'),
    Cajon(CajonKind.singles, 'es'),
    Cajon(CajonKind.unclassified, null),
    Cajon(CajonKind.covers, 'en'),
    Cajon(CajonKind.covers, 'es'),
  ];
}

/// Nombres de cajones editados por el usuario (se guardan en el teléfono).
class ChestNames {
  static const _prefix = 'chest_name_';
  static final Map<String, String> _names = {};

  static String of(Cajon c) => _names[c.key] ?? c.defaultName;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final c in Cajon.all) {
        final n = p.getString('$_prefix${c.key}');
        if (n != null && n.trim().isNotEmpty) _names[c.key] = n.trim();
      }
    } catch (_) {}
  }

  /// Texto vacío = vuelve al nombre de fábrica.
  static Future<void> set(Cajon c, String name) async {
    final n = name.trim();
    if (n.isEmpty) {
      _names.remove(c.key);
    } else {
      _names[c.key] = n;
    }
    try {
      final p = await SharedPreferences.getInstance();
      if (n.isEmpty) {
        await p.remove('$_prefix${c.key}');
      } else {
        await p.setString('$_prefix${c.key}', n);
      }
    } catch (_) {}
  }
}
