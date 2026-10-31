class Vinyl {
  const Vinyl({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.hue,
    required this.tracks,
    this.owned = false,
    this.trackUrls = const [],
    this.coverUrl,
    this.booklet = const [],
    this.pdfs = const [],
    this.genre,
    this.source,
    this.single = false,
    this.cassette = false,
    this.lang,
    this.langManual = false,
    this.coverManual = false,
    this.coverLocked = false,
  });

  final String id;
  final String title;
  final String artist;
  final int year;
  final double hue;
  final List<String> tracks;
  final bool owned;

  /// URLs de streaming (una por pista). Vacío = disco sin audio.
  final List<String> trackUrls;
  final String? coverUrl;

  /// Páginas del libreto (imágenes) y PDFs del álbum.
  final List<String> booklet;
  final List<String> pdfs;

  /// Género (el de la nube de origen) y origen: id de cuenta o 'local'.
  final String? genre;
  final String? source;

  /// Tema suelto (single, recopilación) en vez de álbum completo.
  final bool single;

  /// Cover: se reproduce en el casetero y vive en el baúl "Covers".
  final bool cassette;

  /// Idioma: 'en', 'es' o null (= "Sin clasificar").
  final String? lang;

  /// El usuario fijó el idioma / la marca de cover: la clasificación automática no lo toca.
  final bool langManual;
  final bool coverManual;

  /// El usuario eligió o quitó la portada: los re-escaneos no la cambian.
  final bool coverLocked;

  /// Separador generado entre artistas (no es un disco real).
  bool get isDivider => id.startsWith('sep_');

  bool get hasBooklet => booklet.isNotEmpty || pdfs.isNotEmpty;
  bool get hasAudio => trackUrls.isNotEmpty;
  String get yearLabel => year > 0 ? '$year' : '';

  Vinyl copyWith({
    bool? owned,
    String? genre,
    String? source,
    List<String>? tracks,
    List<String>? trackUrls,
    String? coverUrl,
    List<String>? booklet,
    List<String>? pdfs,
    bool? cassette,
    String? lang,
    bool clearLang = false,
    bool? langManual,
    bool? coverManual,
    bool? coverLocked,
    bool clearCover = false,
  }) =>
      Vinyl(
        id: id,
        title: title,
        artist: artist,
        year: year,
        hue: hue,
        tracks: tracks ?? this.tracks,
        owned: owned ?? this.owned,
        trackUrls: trackUrls ?? this.trackUrls,
        coverUrl: clearCover ? null : (coverUrl ?? this.coverUrl),
        booklet: booklet ?? this.booklet,
        pdfs: pdfs ?? this.pdfs,
        genre: genre ?? this.genre,
        source: source ?? this.source,
        single: single,
        cassette: cassette ?? this.cassette,
        lang: clearLang ? null : (lang ?? this.lang),
        langManual: langManual ?? this.langManual,
        coverManual: coverManual ?? this.coverManual,
        coverLocked: coverLocked ?? this.coverLocked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'year': year,
        'hue': hue,
        'tracks': tracks,
        'owned': owned,
        'trackUrls': trackUrls,
        'coverUrl': coverUrl,
        'booklet': booklet,
        'pdfs': pdfs,
        'genre': genre,
        'source': source,
        'single': single,
        'cassette': cassette,
        'lang': lang,
        'langManual': langManual,
        'coverManual': coverManual,
        'coverLocked': coverLocked,
      };

  factory Vinyl.fromJson(Map<String, dynamic> j) => Vinyl(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String,
        year: (j['year'] as num).toInt(),
        hue: (j['hue'] as num).toDouble(),
        tracks: (j['tracks'] as List).cast<String>(),
        owned: j['owned'] as bool? ?? false,
        trackUrls: (j['trackUrls'] as List?)?.cast<String>() ?? const [],
        coverUrl: j['coverUrl'] as String?,
        booklet: (j['booklet'] as List?)?.cast<String>() ?? const [],
        pdfs: (j['pdfs'] as List?)?.cast<String>() ?? const [],
        genre: j['genre'] as String?,
        source: j['source'] as String?,
        single: j['single'] as bool? ?? false,
        cassette: j['cassette'] as bool? ?? false,
        lang: j['lang'] as String?,
        langManual: j['langManual'] as bool? ?? false,
        // Biblioteca anterior: un cover marcado antes era siempre manual.
        coverManual: j['coverManual'] as bool? ?? (j['cassette'] as bool? ?? false),
        coverLocked: j['coverLocked'] as bool? ?? false,
      );
}
