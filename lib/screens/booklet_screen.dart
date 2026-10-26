import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../data/booklet_lite.dart';
import '../data/fetch_bytes.dart';
import '../data/images_to_pdf.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';

/// Libreto del álbum: páginas (imágenes) y PDFs, todo dentro de la app.
class BookletScreen extends StatelessWidget {
  const BookletScreen({super.key, required this.vinyl, this.store});

  final Vinyl vinyl;
  final VinylStore? store;

  static String _name(String url) {
    var n = Uri.parse(url).pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'PDF');
    try {
      n = Uri.decodeComponent(n);
    } catch (_) {}
    return n.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  }

  @override
  Widget build(BuildContext context) {
    // Las páginas livianas guardadas junto a un PDF se muestran en la pestaña de ese PDF.
    final images = [for (final u in vinyl.booklet) if (!BookletLite.isLitePage(u)) u];
    final tabs = <String>[
      if (images.isNotEmpty) 'Imágenes (${images.length})',
      for (final p in vinyl.pdfs) _name(p),
    ];
    final views = <Widget>[
      if (images.isNotEmpty) _ImagesTab(vinyl: vinyl, store: store, urls: images),
      for (final p in vinyl.pdfs) _PdfTab(url: p, remote: BookletLite.remotePages(vinyl, p)),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text('Libreto · ${vinyl.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: tabs.length > 1
              ? TabBar(isScrollable: true, tabs: [for (final t in tabs) Tab(text: t)])
              : null,
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: views,
        ),
      ),
    );
  }
}

/// Pestaña de imágenes: visor y botón para crear un PDF con ellas.
class _ImagesTab extends StatefulWidget {
  const _ImagesTab({required this.vinyl, required this.store, required this.urls});

  final Vinyl vinyl;
  final VinylStore? store;
  final List<String> urls;

  @override
  State<_ImagesTab> createState() => _ImagesTabState();
}

class _ImagesTabState extends State<_ImagesTab> with AutomaticKeepAliveClientMixin {
  String? _progress;
  String? _msg;

  @override
  bool get wantKeepAlive => true;

  Future<void> _makePdf() async {
    setState(() {
      _msg = null;
      _progress = 'Preparando…';
    });
    try {
      final bytes = await ImagesToPdf.build(
        widget.urls,
        onProgress: (d, t) {
          if (mounted) setState(() => _progress = '$d / $t');
        },
      );
      final url = await ImagesToPdf.saveInAlbumFolder(widget.vinyl, bytes);
      await widget.store?.addPdf(widget.vinyl.id, url);
      final name = Uri.decodeFull(Uri.parse(url).pathSegments.last);
      if (mounted) {
        setState(() => _msg = 'PDF creado en la carpeta del disco: $name');
      }
    } catch (e) {
      if (mounted) setState(() => _msg = 'No se pudo crear el PDF: $e');
    }
    if (mounted) setState(() => _progress = null);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (_progress != null) ...[
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('Creando PDF… $_progress'),
              ] else
                TextButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Crear PDF con estas imágenes'),
                  onPressed: _makePdf,
                ),
            ],
          ),
        ),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_msg!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        Expanded(child: _Pages(urls: widget.urls)),
      ],
    );
  }
}

/// Imágenes del libreto: desliza para cambiar de página, pellizca para ampliar.
class _Pages extends StatefulWidget {
  const _Pages({required this.urls});

  final List<String> urls;

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    const broken = Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48));
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: buildCoverImage(
                widget.urls[i],
                cacheWidth: 1600,
                fit: BoxFit.contain,
                fallback: broken,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('${_page + 1} / ${widget.urls.length}'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Un PDF del álbum: se puede ver el original o su versión liviana (imágenes WebP).
class _PdfTab extends StatefulWidget {
  const _PdfTab({required this.url, this.remote});

  final String url;

  /// Páginas livianas ya guardadas junto al PDF (hechas en otro equipo).
  final List<String>? remote;

  @override
  State<_PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<_PdfTab> with AutomaticKeepAliveClientMixin {
  PdfControllerPinch? _ctl;
  String? _error;
  String? _progress; // "3 / 12" mientras convierte
  int _liteBytes = 0;

  @override
  bool get wantKeepAlive => true;

  List<String>? get _pages => BookletLite.pagesOf(widget.url) ?? widget.remote;
  bool get _lite => _pages != null && BookletLite.preferLite(widget.url);

  @override
  void initState() {
    super.initState();
    _afterChange();
  }

  Future<void> _afterChange() async {
    if (BookletLite.pagesOf(widget.url) != null) {
      final n = await BookletLite.sizeOf(widget.url);
      if (mounted) setState(() => _liteBytes = n);
    }
    if (!_lite) await _loadPdf();
  }

  Future<void> _loadPdf() async {
    if (_ctl != null) return;
    try {
      final bytes = await fetchBytes(widget.url);
      if (!mounted) return;
      setState(() => _ctl = PdfControllerPinch(document: PdfDocument.openData(bytes)));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir el PDF: $e');
    }
  }

  Future<void> _convert() async {
    setState(() {
      _error = null;
      _progress = 'Preparando…';
    });
    try {
      await BookletLite.convert(
        widget.url,
        onProgress: (d, t) {
          if (mounted) setState(() => _progress = '$d / $t');
        },
      );
      _liteBytes = await BookletLite.sizeOf(widget.url);
      _error = BookletLite.lastNote;
    } catch (e) {
      _error = 'No se pudo convertir: $e';
    }
    if (mounted) setState(() => _progress = null);
  }

  Future<void> _setLite(bool v) async {
    await BookletLite.setUseLite(widget.url, v);
    if (mounted) setState(() {});
    if (!v) await _loadPdf();
  }

  Future<void> _remove() async {
    await BookletLite.remove(widget.url);
    if (mounted) setState(() => _liteBytes = 0);
    await _loadPdf();
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  String _mb(int b) => '${(b / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hasLite = _pages != null;
    final hasLocal = BookletLite.pagesOf(widget.url) != null;
    final useLite = _lite;
    final c = _ctl;

    Widget body;
    if (useLite) {
      body = _Pages(urls: _pages!);
    } else if (_error != null && c == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    } else if (c == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = PdfViewPinch(
        controller: c,
        onDocumentError: (e) {
          if (mounted) setState(() => _error = 'No se pudo abrir el PDF: $e');
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (_progress != null) ...[
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('Convirtiendo… $_progress'),
              ] else if (hasLite) ...[
                Expanded(
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      const ButtonSegment(value: false, label: Text('PDF original')),
                      ButtonSegment(value: true, label: Text(hasLocal ? 'Liviana · ${_mb(_liteBytes)}' : 'Liviana (nube)')),
                    ],
                    selected: {useLite},
                    onSelectionChanged: (s) => _setLite(s.first),
                  ),
                ),
                if (hasLocal)
                  IconButton(
                    tooltip: 'Quitar versión liviana',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _remove,
                  ),
              ] else
                TextButton.icon(
                  icon: const Icon(Icons.compress),
                  label: const Text('Convertir a versión liviana'),
                  onPressed: _convert,
                ),
              if (_error != null && c != null) const Icon(Icons.error_outline, color: Colors.redAccent),
            ],
          ),
        ),
        if (_error != null && (c != null || useLite))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        Expanded(child: body),
      ],
    );
  }
}
