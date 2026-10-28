import 'package:flutter/material.dart';

import '../data/cover_studio.dart';
import '../data/studio_save.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../theme.dart';

/// Cover Studio: busca carátulas, contraportadas, discos, libretos y PDFs en internet
/// y los guarda en la carpeta del disco (nube o almacenamiento local).
class CoverStudioScreen extends StatefulWidget {
  const CoverStudioScreen({super.key, required this.store, this.target});

  final VinylStore store;

  /// Disco al que se guardará lo descargado (null = se pregunta al guardar).
  final Vinyl? target;

  @override
  State<CoverStudioScreen> createState() => _CoverStudioScreenState();
}

class _CoverStudioScreenState extends State<CoverStudioScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final TextEditingController _artist = TextEditingController(text: widget.target?.artist ?? '');
  late final TextEditingController _album = TextEditingController(text: widget.target?.title ?? '');
  Vinyl? _target;
  List<StudioAlbum> _albums = const [];
  List<StudioPdf> _pdfs = const [];
  bool _loading = false;
  String? _busy;
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    _target = widget.target;
    if (widget.target != null) _search();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _search() async {
    final a = _artist.text.trim();
    final b = _album.text.trim();
    if (a.isEmpty && b.isEmpty) return _msg('Escribe un artista o un álbum');
    FocusScope.of(context).unfocus();
    final id = ++_searchId;
    setState(() {
      _loading = true;
      _albums = const [];
      _pdfs = const [];
    });
    CoverStudio.searchPdfs(a, b).then((p) {
      if (mounted && id == _searchId) setState(() => _pdfs = p);
    });
    final r = await CoverStudio.search(a, b);
    if (!mounted || id != _searchId) return;
    setState(() {
      _albums = r;
      _loading = false;
    });
  }

  /// Disco donde guardar: el recibido o uno elegido de la biblioteca.
  Future<Vinyl?> _need() async {
    if (_target != null) return _target;
    final t = await showDialog<Vinyl>(
      context: context,
      builder: (_) => _PickDisc(store: widget.store, artist: _artist.text, album: _album.text),
    );
    if (t != null) setState(() => _target = t);
    return t;
  }

  Future<void> _saveImages(List<StudioImage> imgs, {bool asCover = false}) async {
    final v = await _need();
    if (v == null || imgs.isEmpty) return;
    var ok = 0;
    for (var i = 0; i < imgs.length; i++) {
      final img = imgs[i];
      setState(() => _busy = 'Guardando ${i + 1}/${imgs.length}…');
      try {
        final bytes = await CoverStudio.imageBytes(img);
        if (bytes == null) continue;
        await StudioSave.image(widget.store, v, bytes,
            label: img.label + (imgs.length > 1 ? ' ${i + 1}' : ''), type: img.type, asCover: asCover);
        ok++;
      } catch (e) {
        _msg('Error: $e');
      }
    }
    if (mounted) setState(() => _busy = null);
    _msg(ok == 0
        ? 'No se pudo guardar'
        : asCover
            ? 'Portada guardada en la carpeta de “${v.title}”'
            : '$ok imagen(es) guardadas en la carpeta de “${v.title}”');
  }

  Future<void> _savePdf(StudioFile f) async {
    final v = await _need();
    if (v == null) return;
    setState(() => _busy = 'Descargando PDF…');
    try {
      final bytes = await CoverStudio.fileBytes(f.url);
      if (bytes == null) {
        _msg('No se pudo descargar el PDF');
      } else {
        final ok = await StudioSave.pdf(widget.store, v, bytes, f.name);
        _msg(ok ? 'PDF guardado en la carpeta de “${v.title}”' : 'Este disco no tiene carpeta');
      }
    } catch (e) {
      _msg('Error: $e');
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _open(StudioAlbum a) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _AlbumPage(album: a, onSave: _saveImages, target: () => _target),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        title: const Text('Cover Studio'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Carátulas'),
            Tab(text: 'PDFs / Libretos${_pdfs.isEmpty ? '' : ' (${_pdfs.length})'}'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              children: [
                TextField(
                  controller: _artist,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Artista', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _album,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration:
                            const InputDecoration(labelText: 'Álbum o tema', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(onPressed: _search, icon: const Icon(Icons.search), label: const Text('Buscar')),
                  ],
                ),
                if (_target != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Guarda en: ${_target!.artist} — ${_target!.title}',
                          style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
          if (_busy != null) ...[
            const LinearProgressIndicator(minHeight: 2),
            Padding(padding: const EdgeInsets.all(4), child: Text(_busy!, style: const TextStyle(fontSize: 12))),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_albumsTab(), _pdfsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _albumsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_albums.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Busca un artista o álbum en iTunes, Deezer y MusicBrainz.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78),
      itemCount: _albums.length,
      itemBuilder: (_, i) {
        final a = _albums[i];
        return InkWell(
          onTap: () => _open(a),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox.expand(child: _Thumb(a.thumb)),
                ),
              ),
              const SizedBox(height: 4),
              Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${a.artist}${a.year.isEmpty ? '' : ' · ${a.year}'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _pdfsTab() {
    if (_pdfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loading ? 'Buscando en Internet Archive…' : 'Sin PDFs. Haz una búsqueda.',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final p in _pdfs)
          Card(
            color: AppColors.panel,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (p.creator.isNotEmpty) Text(p.creator, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  for (final f in p.files)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: f.size > 0 ? Text(_size(f.size)) : null,
                      trailing: FilledButton.tonal(
                        onPressed: _busy != null ? null : () => _savePdf(f),
                        child: const Text('Guardar'),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _size(int n) => n > 1048576 ? '${(n / 1048576).toStringAsFixed(1)} MB' : '${(n / 1024).round().clamp(1, 1 << 30)} KB';
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.url);
  final String url;
  @override
  Widget build(BuildContext context) => url.isEmpty
      ? const ColoredBox(color: AppColors.panel)
      : Image.network(url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.panel, child: Icon(Icons.album, color: Colors.white24)));
}

/// Imágenes de un álbum: elige y guarda en la carpeta del disco.
class _AlbumPage extends StatefulWidget {
  const _AlbumPage({required this.album, required this.onSave, required this.target});
  final StudioAlbum album;
  final Future<void> Function(List<StudioImage>, {bool asCover}) onSave;
  final Vinyl? Function() target;

  @override
  State<_AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<_AlbumPage> {
  final Set<String> _sel = {};
  String _filter = 'all';
  bool _loading = false;

  StudioAlbum get a => widget.album;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    setState(() => _loading = true);
    await CoverStudio.loadEditions(a);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final imgs = [for (final i in a.images) if (_filter == 'all' || i.type == _filter) i];
    const types = ['front', 'back', 'medium', 'booklet', 'other'];
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(backgroundColor: AppColors.ink, title: Text(a.title, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final t in ['all', ...types])
                  if (t == 'all' || a.images.any((i) => i.type == t))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(t == 'all' ? 'Todas (${a.images.length})' : StudioImage.labels[t]!),
                        selected: _filter == t,
                        onSelected: (_) => setState(() => _filter = t),
                      ),
                    ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: imgs.isEmpty
                ? Center(
                    child: Text(_loading ? 'Buscando ediciones…' : 'No hay imágenes de este tipo.',
                        style: const TextStyle(color: Colors.white60)))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: imgs.length,
                    itemBuilder: (_, i) {
                      final im = imgs[i];
                      final on = _sel.contains(im.id);
                      return GestureDetector(
                        onTap: () => setState(() => on ? _sel.remove(im.id) : _sel.add(im.id)),
                        onLongPress: () => showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(im.urls.last))),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: _Thumb(im.thumb)),
                            if (on)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.gold, width: 3), borderRadius: BorderRadius.circular(8)),
                              ),
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: Colors.black54,
                                child: Text('${im.label}${im.edition.isEmpty ? '' : ' · ${im.edition}'}',
                                    style: const TextStyle(fontSize: 10)),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: IconButton(
                                tooltip: 'Usar como portada',
                                icon: const Icon(Icons.star_border, color: AppColors.gold),
                                onPressed: () => widget.onSave([im], asCover: true),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  if (a.hasMore)
                    TextButton(onPressed: _loading ? null : _more, child: const Text('+ ediciones')),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: Text('Guardar en la carpeta (${_sel.length})'),
                    onPressed: _sel.isEmpty
                        ? null
                        : () => widget.onSave([for (final i in a.images) if (_sel.contains(i.id)) i]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Elige un disco de la biblioteca (sugiere los que coinciden con la búsqueda).
class _PickDisc extends StatefulWidget {
  const _PickDisc({required this.store, required this.artist, required this.album});
  final VinylStore store;
  final String artist;
  final String album;
  @override
  State<_PickDisc> createState() => _PickDiscState();
}

class _PickDiscState extends State<_PickDisc> {
  late final TextEditingController _q = TextEditingController(text: '${widget.artist} ${widget.album}'.trim());

  @override
  Widget build(BuildContext context) {
    final q = _q.text.toLowerCase().trim();
    final list = [
      for (final v in widget.store.items)
        if (!v.isDivider && v.hasAudio && (q.isEmpty || '${v.artist} ${v.title}'.toLowerCase().contains(q))) v,
    ].take(40).toList();
    return AlertDialog(
      title: const Text('¿En qué disco guardar?'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(controller: _q, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Buscar disco')),
            Expanded(
              child: ListView(
                children: [
                  for (final v in list)
                    ListTile(
                      dense: true,
                      title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(v.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(context).pop(v),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))],
    );
  }
}
