import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/player_service.dart';
import '../data/koofr_settings.dart';
import '../data/library_order.dart';
import '../data/library_sync.dart';
import '../data/vinyl_store.dart';
import 'cover_studio_screen.dart';
import 'upload_dialog.dart';
import '../data/cloud_upload.dart';
import '../models/vinyl.dart';
import '../data/booklet_lite.dart';
import '../data/classifier.dart';
import '../data/cover_color.dart';
import '../data/cover_lookup.dart';
import '../data/koofr_client.dart';
import '../widgets/cassette_deck.dart';
import '../widgets/cover_art.dart';
import '../widgets/turntable.dart';
import '../theme.dart';
import 'booklet_screen.dart';
import 'lyrics_sheet.dart';
import 'move_dialog.dart';

/// Disco sacado de la caja: tornamesa arriba, carátula abajo.
/// Toca la carátula para darla vuelta (pistas), la tornamesa para play/pausa.
class StageScreen extends StatefulWidget {
  const StageScreen({super.key, required this.store, required this.vinyl});

  final VinylStore store;
  final Vinyl vinyl;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  final _audio = PlayerService.instance;
  bool _flipped = false;
  bool _simPlaying = false; // discos sin audio: solo animación
  String? _error;
  Color? _bg; // color de la portada (fondo del reproductor)
  int _page = 0; // página del carrusel (0 = carátula)

  Vinyl get v => widget.vinyl;

  @override
  void initState() {
    super.initState();
    _start();
    _loadBg();
  }

  /// Páginas del libreto para el carrusel: imágenes y versiones livianas de los PDF.
  List<String> _bookletPages() {
    final out = <String>[
      for (final u in v.booklet)
        if (!BookletLite.isLitePage(u)) u,
    ];
    for (final pdf in v.pdfs) {
      final lite = BookletLite.pagesOf(pdf) ?? BookletLite.remotePages(v, pdf);
      if (lite != null) out.addAll(lite);
    }
    return out;
  }

  Future<void> _loadBg() async {
    final c = await CoverColor.of(v.coverUrl);
    final col = c ?? (v.coverUrl == null ? hueColor(v.hue, 0.5, 0.4) : null);
    if (mounted && col != null) setState(() => _bg = CoverColor.background(col));
  }

  Future<void> _start() async {
    if (!v.hasAudio) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) setState(() => _simPlaying = true);
      return;
    }
    // Si este disco ya está sonando, la reproducción continúa sin tocarla.
    if (_audio.nowPlaying.value?.id == v.id) return;
    // Si otro disco está sonando, no lo interrumpas: solo se cambia al elegir un tema.
    if (_audio.nowPlaying.value != null && _audio.player.playing) return;
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await _ensureLoaded();
  }

  Future<bool> _ensureLoaded({int index = 0}) async {
    if (_audio.nowPlaying.value?.id == v.id) return true;
    try {
      await _audio.start(v, index: index);
      return _audio.nowPlaying.value?.id == v.id;
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo reproducir: $e');
      return false;
    }
  }

  // La música NO se detiene al cerrar esta pantalla.

  /// Tornamesa para discos; casetero para los covers.
  Widget _vis({required bool playing, double progress = 0, int trackIndex = 0}) {
    // Covers y temas sueltos se reproducen en el casetero.
    if (v.cassette || v.single) {
      final i = trackIndex.clamp(0, math.max(0, v.tracks.length - 1)).toInt();
      final t = v.tracks.isEmpty ? v.title : v.tracks[i];
      return CassetteDeck(
        vinyl: v,
        playing: playing,
        progress: progress,
        trackIndex: i,
        label: '$t – ${v.artist}',
        onPlay: _play,
        onPause: _pause,
        onPrev: _prev,
        onNext: _next,
        onEject: () => Navigator.of(context).pop(),
      );
    }
    return Turntable(
      vinyl: v,
      playing: playing,
      progress: progress,
      trackIndex: trackIndex,
      trackCount: v.tracks.length,
      single: v.single,
    );
  }

  Future<void> _play() async {
    if (!v.hasAudio) {
      setState(() => _simPlaying = true);
      return;
    }
    if (_audio.nowPlaying.value?.id != v.id) {
      await _ensureLoaded();
      return;
    }
    await _audio.player.play();
  }

  Future<void> _pause() async {
    if (!v.hasAudio) {
      setState(() => _simPlaying = false);
      return;
    }
    if (_audio.nowPlaying.value?.id == v.id) await _audio.player.pause();
  }

  Widget _turntable() {
    if (!v.hasAudio) {
      return _vis(playing: _simPlaying);
    }
    final p = _audio.player;
    return ValueListenableBuilder<Vinyl?>(
      valueListenable: _audio.nowPlaying,
      builder: (_, np, __) {
        if (np?.id != v.id) {
          return _vis(playing: false);
        }
        return StreamBuilder<bool>(
          stream: p.playingStream,
          initialData: p.playing,
          builder: (_, ps) => StreamBuilder<int?>(
            stream: p.currentIndexStream,
            initialData: p.currentIndex,
            builder: (_, ix) => StreamBuilder<Duration>(
              stream: p.positionStream,
              builder: (_, pos) {
                final dur = p.duration?.inMilliseconds ?? 0;
                final cur = (pos.data ?? Duration.zero).inMilliseconds;
                final prog = dur > 0 ? (cur / dur).clamp(0.0, 1.0).toDouble() : 0.0;
                return _vis(
                  playing: ps.data ?? false,
                  progress: prog,
                  trackIndex: ix.data ?? 0,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggle() async {
    if (!v.hasAudio) {
      setState(() => _simPlaying = !_simPlaying);
      return;
    }
    if (_audio.nowPlaying.value?.id != v.id) {
      await _ensureLoaded();
      return;
    }
    final p = _audio.player;
    p.playing ? p.pause() : p.play();
  }

  Future<void> _playTrack(int i) async {
    if (_audio.nowPlaying.value?.id == v.id) {
      await _audio.goTrack(i);
    } else {
      await _ensureLoaded(index: i); // carga el disco directamente en ese tema
    }
  }

  void _prev() => _audio.goTrack((_audio.player.currentIndex ?? 0) - 1);
  void _next() => _audio.goTrack((_audio.player.currentIndex ?? 0) + 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bg ?? AppColors.ink, AppColors.ink],
            stops: const [0.0, 0.85],
          ),
        ),
        child: SafeArea(
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    tooltip: 'Menú principal',
                    icon: const Icon(Icons.home_outlined),
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                  const Spacer(),
                  if (v.hasBooklet)
                    IconButton(
                      tooltip: 'Libreto',
                      icon: const Icon(Icons.menu_book),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => BookletScreen(vinyl: v, store: widget.store)),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Letra',
                    icon: const Icon(Icons.lyrics_outlined),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF161816),
                      builder: (_) => LyricsSheet(store: widget.store, vinyl: v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF161816),
                      builder: (_) => DetailSheet(store: widget.store, vinyl: v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _toggle,
                child: _turntable(),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final s = math.min(c.maxWidth - 32, c.maxHeight - 8);
                  return Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _flipped = !_flipped),
                      child: SizedBox(
                        width: s,
                        height: s,
                        child: Hero(
                          tag: 'cover-${v.id}',
                          child: _FlipCover(
                            vinyl: v,
                            flipped: _flipped,
                            onTrack: _playTrack,
                            front: _Carousel(
                              vinyl: v,
                              pages: _bookletPages(),
                              initial: _page,
                              onPage: (i) => _page = i,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ValueListenableBuilder<Vinyl?>(
              valueListenable: _audio.nowPlaying,
              builder: (_, np, __) => np != null && np.id != v.id && v.hasAudio
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Sigue sonando: ${np.title}. Toca un tema o play para cambiar.',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _Controls(
              vinyl: v,
              audio: _audio,
              onToggle: _toggle,
              onPrev: _prev,
              onNext: _next,
              simPlaying: _simPlaying,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.vinyl,
    required this.audio,
    required this.onToggle,
    required this.onPrev,
    required this.onNext,
    required this.simPlaying,
  });

  final Vinyl vinyl;
  final PlayerService audio;
  final VoidCallback onToggle;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool simPlaying;

  @override
  Widget build(BuildContext context) {
    final p = audio.player;
    final v = vinyl;
    return ValueListenableBuilder<Vinyl?>(
      valueListenable: audio.nowPlaying,
      builder: (context, np, _) {
        final active = np?.id == v.id;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            children: [
              if (v.hasAudio)
                active
                    ? StreamBuilder<Duration>(
                        stream: p.positionStream,
                        builder: (_, s) {
                          final dur = p.duration ?? Duration.zero;
                          final maxMs = dur.inMilliseconds.toDouble();
                          final pos = (s.data ?? Duration.zero).inMilliseconds.toDouble();
                          return Slider(
                            value: maxMs > 0 ? pos.clamp(0.0, maxMs).toDouble() : 0,
                            max: maxMs > 0 ? maxMs : 1,
                            onChanged: (x) => p.seek(Duration(milliseconds: x.round())),
                          );
                        },
                      )
                    : const Slider(value: 0, onChanged: null),
              Row(
                children: [
                  Expanded(
                    child: v.hasAudio && active
                        ? StreamBuilder<int?>(
                            stream: p.currentIndexStream,
                            builder: (_, s) {
                              final i = s.data ?? 0;
                              final t = i < v.tracks.length ? v.tracks[i] : v.title;
                              return _Info(title: t, sub: '${v.artist} · ${v.title}');
                            },
                          )
                        : _Info(title: v.title, sub: '${v.artist}  ${v.yearLabel}'),
                  ),
                  if (v.hasAudio) ...[
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: active ? onPrev : null,
                    ),
                    StreamBuilder<bool>(
                      stream: p.playingStream,
                      initialData: p.playing,
                      builder: (_, s) => IconButton.filled(
                        iconSize: 30,
                        icon: Icon(active && (s.data ?? false) ? Icons.pause : Icons.play_arrow),
                        onPressed: onToggle,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: active ? onNext : null,
                    ),
                  ] else
                    IconButton.filled(
                      iconSize: 30,
                      icon: Icon(simPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: onToggle,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.title, required this.sub});
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: titleFont, fontSize: 19),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60),
        ),
      ],
    );
  }
}

/// Carátula + páginas del libreto: desliza hacia el costado para pasar de página,
/// pellizca para ampliar. Al tocar, se da vuelta la tapa (lista de temas).
class _Carousel extends StatefulWidget {
  const _Carousel({
    required this.vinyl,
    required this.pages,
    required this.initial,
    required this.onPage,
  });

  final Vinyl vinyl;
  final List<String> pages;
  final int initial;
  final ValueChanged<int> onPage;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  late final PageController _ctl;
  late int _i;

  int get _count => 1 + widget.pages.length;

  @override
  void initState() {
    super.initState();
    _i = widget.initial.clamp(0, _count - 1);
    _ctl = PageController(initialPage: _i);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return CoverArt(vinyl: widget.vinyl);
    const broken = Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48));
    return Stack(
      children: [
        PageView.builder(
          controller: _ctl,
          itemCount: _count,
          onPageChanged: (i) {
            widget.onPage(i);
            setState(() => _i = i);
          },
          itemBuilder: (_, i) {
            if (i == 0) return CoverArt(vinyl: widget.vinyl);
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ColoredBox(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: buildCoverImage(
                      widget.pages[i - 1],
                      cacheWidth: 1400,
                      fit: BoxFit.contain,
                      fallback: broken,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _i == 0 ? 'Carátula · desliza ▸' : '${_i + 1} / $_count',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlipCover extends StatelessWidget {
  const _FlipCover({
    required this.vinyl,
    required this.flipped,
    required this.onTrack,
    required this.front,
  });

  final Vinyl vinyl;
  final bool flipped;
  final ValueChanged<int> onTrack;

  /// Cara de adelante: la carátula y, deslizando, las páginas del libreto.
  final Widget front;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: flipped ? 1 : 0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) {
        final back = v > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(v * math.pi),
          child: back
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: _Back(vinyl: vinyl, onTrack: onTrack),
                )
              : front,
        );
      },
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.vinyl, required this.onTrack});
  final Vinyl vinyl;
  final ValueChanged<int> onTrack;

  @override
  Widget build(BuildContext context) {
    // Covers: hoja como la etiqueta del cassette, con letra a mano alzada.
    final hand = vinyl.cassette;
    const ink = Color(0xFF1F3C88);
    final base = hand
        ? const TextStyle(fontFamily: 'cursive', color: ink, fontWeight: FontWeight.w700, fontSize: 15)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: hand ? const Color(0xFFF7F3EA) : hueColor(vinyl.hue, 0.25, 0.12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hand ? vinyl.artist : vinyl.artist.toUpperCase(),
              style: hand
                  ? base!.copyWith(fontSize: 19)
                  : const TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.w700),
            ),
            Text(
              vinyl.title,
              style: hand ? base!.copyWith(fontWeight: FontWeight.w500, fontSize: 14) : const TextStyle(color: Colors.white70),
            ),
            Divider(height: 20, color: hand ? const Color(0x663B63C4) : null),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: vinyl.tracks.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () => onTrack(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: hand
                        ? const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0x553B63C4), width: 0.8)))
                        : null,
                    child: Text('${i + 1}.  ${vinyl.tracks[i]}', style: base),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ficha del disco: colección, lista de pistas y eliminar.
class DetailSheet extends StatelessWidget {
  const DetailSheet({super.key, required this.store, required this.vinyl});

  final VinylStore store;
  final Vinyl vinyl;

  /// Cuenta de Koofr a la que pertenece el disco (null si es local o manual).
  static KoofrSettings? _cloudAccount(Vinyl v) {
    for (final a in KoofrAccounts.list) {
      if (sourceInAccount(v.source, a.id)) return a;
    }
    return null;
  }

  /// Tras cambiar el idioma: si la nube tiene una carpeta de ese idioma
  /// (Inglés / Español), ofrece mover también la carpeta del disco. Solo si aceptas.
  Future<void> _offerMove(BuildContext context, Vinyl v, String lang) async {
    final acct = _cloudAccount(v);
    if (acct == null || v.trackUrls.isEmpty) return;
    try {
      final client = KoofrClient(acct);
      final tops = await client.topFolders();
      final target = tops.where((f) => Classifier.langFromName(f) == lang).firstOrNull;
      final rel = client.relSegments(v.trackUrls.first);
      if (target == null || rel.isEmpty || rel.first == target) return;
      if (!context.mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Mover también en la nube?'),
          content: Text('Hay una carpeta "$target". Puedo mover la carpeta del disco ahí; '
              'si no, solo cambia la etiqueta en la app y tus archivos no se tocan.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Solo etiqueta')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Mover')),
          ],
        ),
      );
      if (yes != true || !context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => MoveDialog(store: store, vinyl: v, account: acct, initial: target),
      );
      if (ok == true && context.mounted) {
        LibrarySync.refresh(acct, store);
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (_) {
      // Sin conexión: el idioma ya quedó guardado en la app.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final v = store.items.firstWhere((e) => e.id == vinyl.id, orElse: () => vinyl);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.cassette ? v.artist : v.artist.toUpperCase(),
                  style: v.cassette
                      ? const TextStyle(fontFamily: 'cursive', color: Color(0xFF9DB8FF), fontSize: 20, fontWeight: FontWeight.w700)
                      : const TextStyle(color: Colors.white60, letterSpacing: 1.4),
                ),
                Text(
                  v.title,
                  style: v.cassette
                      ? const TextStyle(fontFamily: 'cursive', color: Color(0xFFBFD0FF), fontSize: 28, fontWeight: FontWeight.w700)
                      : const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                Text(v.yearLabel, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(v.owned ? Icons.check : Icons.add),
                        label: Text(v.owned ? 'En colección' : 'Agregar'),
                        onPressed: () => store.toggleOwned(v.id),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                        onPressed: () {
                          PlayerService.instance.stopIf(v.id);
                          store.remove(v.id);
                          Navigator.of(context)
                            ..pop()
                            ..pop();
                        },
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Es un cover (reproducir en cassette)'),
                  value: v.cassette,
                  onChanged: (on) async {
                    String? cover;
                    if (on && v.coverUrl == null) {
                      // Busca la portada del cover (tema + artista) en internet.
                      try {
                        cover = (await CoverLookup.find(
                          artist: v.artist,
                          albums: [v.title],
                          tracks: v.tracks,
                          trackFirst: true,
                        ))
                            ?.url;
                      } catch (_) {}
                    }
                    await store.setCassette(v.id, on, coverUrl: cover);
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('IDIOMA', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final o in const [('en', 'Inglés'), ('es', 'Español')])
                            ChoiceChip(
                              label: Text(o.$2),
                              selected: v.lang == o.$1 && v.langManual,
                              onSelected: (_) async {
                                await store.setLang(v.id, o.$1);
                                if (context.mounted) await _offerMove(context, v, o.$1);
                              },
                            ),
                          ChoiceChip(
                            label: Text(v.langManual ? 'Automático' : (v.lang == null ? 'Sin clasificar' : 'Automático')),
                            selected: !v.langManual,
                            onSelected: (_) => store.setLang(v.id, null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.image_search),
                    label: const Text('Buscar portada / PDF'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CoverStudioScreen(store: store, target: v)),
                    ),
                  ),
                ),
                if (CloudUpload.isLocal(v) && KoofrAccounts.list.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Subir a la nube…'),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => UploadDialog(store: store, vinyl: v),
                        );
                        if (ok == true && context.mounted) {
                          Navigator.of(context)
                            ..pop()
                            ..pop();
                        }
                      },
                    ),
                  ),
                ],
                if (_cloudAccount(v) != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: const Text('Mover a…'),
                      onPressed: () async {
                        final acct = _cloudAccount(v)!;
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => MoveDialog(store: store, vinyl: v, account: acct),
                        );
                        if (ok == true && context.mounted) {
                          LibrarySync.refresh(acct, store);
                          Navigator.of(context)
                            ..pop()
                            ..pop();
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('LISTA DE PISTAS', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: v.tracks.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text('${i + 1}'),
                      title: Text(
                        v.tracks[i],
                        style: v.cassette
                            ? const TextStyle(fontFamily: 'cursive', color: Color(0xFFBFD0FF), fontSize: 18, fontWeight: FontWeight.w700)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
