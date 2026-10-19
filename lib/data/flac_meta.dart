import 'dart:convert';
import 'dart:typed_data';

/// Lee [length] bytes desde [start]; null si no se pudo.
typedef RangeReader = Future<Uint8List?> Function(int start, int length);

class FlacMeta {
  String? artist;
  String? albumArtist;
  String? album;
  String? date;
  Uint8List? picture;
  String? pictureMime;
}

/// Envuelve un lector con un búfer para evitar muchas lecturas pequeñas.
RangeReader buffered(RangeReader raw, {int chunk = 262144}) {
  var bufStart = -1;
  Uint8List? buf;
  return (start, length) async {
    final b = buf;
    if (b != null && start >= bufStart && start + length <= bufStart + b.length) {
      return Uint8List.sublistView(b, start - bufStart, start - bufStart + length);
    }
    final want = length > chunk ? length : chunk;
    final d = await raw(start, want);
    if (d == null) return null;
    bufStart = start;
    buf = d;
    final end = length < d.length ? length : d.length;
    return Uint8List.sublistView(d, 0, end);
  };
}

/// Lee etiquetas (artista, álbum, año) y la carátula incrustada de un FLAC.
Future<FlacMeta?> readFlacMeta(RangeReader read, {int maxPicture = 8 * 1024 * 1024}) async {
  try {
    final head = await read(0, 4);
    if (head == null || head.length < 4 || String.fromCharCodes(head) != 'fLaC') return null;
    var pos = 4;
    final m = FlacMeta();
    for (var i = 0; i < 40; i++) {
      final h = await read(pos, 4);
      if (h == null || h.length < 4) break;
      final last = (h[0] & 0x80) != 0;
      final type = h[0] & 0x7F;
      final len = (h[1] << 16) | (h[2] << 8) | h[3];
      pos += 4;
      if (type == 4 && len < 1024 * 1024) {
        final d = await read(pos, len);
        if (d != null) _comments(d, m);
      } else if (type == 6 && len <= maxPicture) {
        final d = await read(pos, len);
        if (d != null) _picture(d, m);
      }
      pos += len;
      if (last) break;
    }
    return m;
  } catch (_) {
    return null;
  }
}

void _comments(Uint8List d, FlacMeta m) {
  final b = ByteData.sublistView(d);
  var o = 0;
  final vendor = b.getUint32(o, Endian.little);
  o += 4 + vendor;
  final n = b.getUint32(o, Endian.little);
  o += 4;
  for (var i = 0; i < n && o + 4 <= d.length; i++) {
    final l = b.getUint32(o, Endian.little);
    o += 4;
    if (o + l > d.length) break;
    final s = utf8.decode(d.sublist(o, o + l), allowMalformed: true);
    o += l;
    final eq = s.indexOf('=');
    if (eq < 0) continue;
    final k = s.substring(0, eq).toUpperCase();
    final v = s.substring(eq + 1).trim();
    if (v.isEmpty) continue;
    switch (k) {
      case 'ARTIST':
        m.artist ??= v;
      case 'ALBUMARTIST':
      case 'ALBUM ARTIST':
        m.albumArtist ??= v;
      case 'ALBUM':
        m.album ??= v;
      case 'DATE':
      case 'YEAR':
        m.date ??= v;
    }
  }
}

void _picture(Uint8List d, FlacMeta m) {
  final b = ByteData.sublistView(d);
  var o = 0;
  final type = b.getUint32(o);
  o += 4;
  final ml = b.getUint32(o);
  o += 4;
  final mime = utf8.decode(d.sublist(o, o + ml), allowMalformed: true);
  o += ml;
  final dl = b.getUint32(o);
  o += 4 + dl;
  o += 16; // ancho, alto, profundidad, colores
  final len = b.getUint32(o);
  o += 4;
  if (o + len > d.length) return;
  if (m.picture == null || type == 3) {
    m.picture = Uint8List.fromList(d.sublist(o, o + len));
    m.pictureMime = mime;
  }
}
