import '../models/vinyl.dart';

/// Clasificación automática: idioma (en / es) y covers.
/// Todo local y sin internet; lo dudoso queda en null ("Sin clasificar").
class Classifier {
  /// Etiqueta de idioma del archivo (ID3 TLAN, Vorbis LANGUAGE): eng, en, spa, es…
  static String? langFromTag(String? t) {
    if (t == null) return null;
    final s = t.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'en' || s.startsWith('eng') || s.startsWith('en-') || s.startsWith('en_') || s == 'english' || s == 'inglés' || s == 'ingles') {
      return 'en';
    }
    if (s == 'es' || s.startsWith('spa') || s.startsWith('es-') || s.startsWith('es_') || s == 'español' || s == 'espanol' || s == 'spanish' || s == 'castellano') {
      return 'es';
    }
    return null;
  }

  /// Nombre de la carpeta de categoría ("cuenta:Inglés") → idioma.
  static String? langFromSource(String? source) {
    if (source == null) return null;
    final i = source.indexOf(':');
    if (i < 0) return null;
    return langFromName(source.substring(i + 1));
  }

  static String? langFromName(String name) {
    final s = _fold(name);
    if (RegExp(r'ingles|english|\bing\b|\ben\b').hasMatch(s)) return 'en';
    if (RegExp(r'espanol|spanish|castellano|\besp\b|\bes\b').hasMatch(s)) return 'es';
    return null;
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');

  // Palabras con peso 2 (muy típicas) y 1 (típicas). Se evitan las ambiguas (me, no, a, la, in).
  static const _en2 = {
    'the', 'you', 'your', "i'm", "don't", "can't", "it's", 'with', 'of', 'and', 'my', 'we', 'that', 'this', 'what', 'when', 'from', 'are', 'was', 'love', 'baby', 'girl', 'boy', 'night', 'heart', 'down', 'up', 'out', 'over', 'into', 'all', 'one', 'for', 'to', 'on', 'is', 'be', 'not', 'just', 'like', 'know', 'time', 'life', 'world', 'fire', 'rain', 'dream', 'dreams', 'blue', 'black', 'red', 'live', 'home', 'again',
  };
  static const _es2 = {
    'el', 'los', 'las', 'del', 'que', 'mi', 'tu', 'tus', 'mis', 'por', 'para', 'con', 'una', 'un', 'y', 'te', 'yo', 'amor', 'vida', 'noche', 'corazón', 'corazon', 'sin', 'como', 'cómo', 'hoy', 'ayer', 'mañana', 'manana', 'cielo', 'tiempo', 'mundo', 'fuego', 'lluvia', 'sueño', 'sueños', 'mujer', 'hombre', 'niña', 'nina', 'volver', 'quiero', 'eres', 'soy', 'estoy', 'siempre', 'nunca', 'todo', 'todos', 'más', 'mas', 'entre', 'sobre', 'cuando', 'donde', 'dónde', 'pero', 'si', 'se', 'al', 'es', 'esta', 'está', 'este',
  };
  static const _strong = {
    'the', 'you', 'your', "i'm", "don't", "can't", "it's", 'with', 'of', 'my', 'that', 'this', 'what',
    'el', 'los', 'las', 'del', 'que', 'tu', 'tus', 'mis', 'por', 'para', 'con', 'una', 'yo', 'amor', 'corazón', 'corazon', 'quiero', 'eres', 'soy', 'estoy', 'siempre', 'nunca', 'cuando', 'pero',
  };

  /// Idioma por texto (letra, o título + artista). null si hay duda.
  static String? langFromText(String text) {
    final lower = text.toLowerCase();
    var es = 0;
    var en = 0;
    // Signos y letras exclusivas del español.
    es += RegExp('[ñ¿¡]').allMatches(lower).length.clamp(0, 3) * 2;
    es += RegExp('[áéíóú]').allMatches(lower).length.clamp(0, 3);
    final words = RegExp(r"[a-záéíóúñü']+").allMatches(lower).map((m) => m[0]!);
    for (final w in words) {
      final wt = _strong.contains(w) ? 2 : 1;
      if (_en2.contains(w) && !_es2.contains(w)) en += wt;
      if (_es2.contains(w) && !_en2.contains(w)) es += wt;
    }
    final win = es > en ? es : en;
    final lose = es > en ? en : es;
    if (win < 2 || win < lose * 2) return null;
    return es > en ? 'es' : 'en';
  }

  static final _coverRe = RegExp(
    r'\bcovers?\b|\bversi[oó]n\s+(de|del|by)\b|\(\s*[^)]*\bcover\b[^)]*\)',
    caseSensitive: false,
  );

  /// ¿El texto (carpeta, archivo o título) indica que es un cover?
  static bool isCover(String text) => _coverRe.hasMatch(text);

  /// Idioma de un disco ya construido, sin etiquetas (carpeta de categoría o texto).
  static String? detectLang(Vinyl v) =>
      langFromSource(v.source) ?? langFromText('${v.title} ${v.tracks.join(' ')} ${v.artist}');

  static bool detectCover(Vinyl v) {
    final path = v.trackUrls.isEmpty
        ? ''
        : Uri.decodeFull(Uri.parse(v.trackUrls.first).removeFragment().path);
    return isCover('${v.title} ${v.tracks.join(' ')} $path');
  }

  static String artistKey(String artist) => _fold(artist).replaceAll(RegExp(r'[^a-z0-9]'), '');
}
