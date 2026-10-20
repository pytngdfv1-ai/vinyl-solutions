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

  bool get hasBooklet => booklet.isNotEmpty || pdfs.isNotEmpty;
  bool get hasAudio => trackUrls.isNotEmpty;
  String get yearLabel => year > 0 ? '$year' : '';

  Vinyl copyWith({bool? owned}) => Vinyl(
        id: id,
        title: title,
        artist: artist,
        year: year,
        hue: hue,
        tracks: tracks,
        owned: owned ?? this.owned,
        trackUrls: trackUrls,
        coverUrl: coverUrl,
        booklet: booklet,
        pdfs: pdfs,
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
      );
}
