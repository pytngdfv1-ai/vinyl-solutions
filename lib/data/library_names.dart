import 'koofr_settings.dart';

/// Nombre mostrado de una biblioteca de origen: nunca dice "Koofr".
String niceName(String n) {
  final r = n.replaceAll(RegExp('koofr', caseSensitive: false), 'Nube').trim();
  return r.isEmpty ? 'Nube' : r;
}

/// Etiqueta de una biblioteca: id de cuenta, 'cuenta:Grupo', 'local', 'local:Grupo' o 'manual'.
String libraryLabel(String id) {
  if (id == 'local') return 'Teléfono';
  if (id == 'manual') return 'Manuales';
  if (id.startsWith('local:')) return id.substring(6);
  for (final a in KoofrAccounts.list) {
    if (id == a.id) return niceName(a.name);
    if (id.startsWith('${a.id}:')) return id.substring(a.id.length + 1);
  }
  return id;
}
