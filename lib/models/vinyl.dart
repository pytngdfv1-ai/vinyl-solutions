class Vinyl {
  const Vinyl({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.hue,
    required this.tracks,
    this.owned = false,
  });

  final String id;
  final String title;
  final String artist;
  final int year;
  final double hue;
  final List<String> tracks;
  final bool owned;

  Vinyl copyWith({bool? owned}) => Vinyl(
        id: id,
        title: title,
        artist: artist,
        year: year,
        hue: hue,
        tracks: tracks,
        owned: owned ?? this.owned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'year': year,
        'hue': hue,
        'tracks': tracks,
        'owned': owned,
      };

  factory Vinyl.fromJson(Map<String, dynamic> j) => Vinyl(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String,
        year: (j['year'] as num).toInt(),
        hue: (j['hue'] as num).toDouble(),
        tracks: (j['tracks'] as List).cast<String>(),
        owned: j['owned'] as bool? ?? false,
      );
}
