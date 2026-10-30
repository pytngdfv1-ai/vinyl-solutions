import 'package:flutter/material.dart';

import '../data/manual_content.dart';
import '../theme.dart';

/// Acerca de: presentación de la app y manual de uso.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

const _orange = Color(0xFFFF8A3D);
const _line = Color(0xFF2A2D2A);
const _muted = Color(0xFFA8A99F);
const _text = Color(0xFFD9D5C8);

const _icons = <String, IconData>{
  'arrow_forward': Icons.arrow_forward,
  'view_agenda_outlined': Icons.view_agenda_outlined,
  'album': Icons.album,
  'info_outline': Icons.info_outline,
  'search': Icons.search,
  'menu_book': Icons.menu_book_outlined,
  'playlist_add': Icons.playlist_add,
  'graphic_eq': Icons.graphic_eq,
  'cloud_outlined': Icons.cloud_outlined,
  'lock_outline': Icons.lock_outline,
  'help_outline': Icons.help_outline,
};

class _AboutScreenState extends State<AboutScreen> {
  final _keys = {for (final s in manualSections) s.id: GlobalKey()};
  final _ctrls = {for (final s in manualSections) s.id: ExpansionTileController()};

  Future<void> _go(String id) async {
    for (final e in _ctrls.entries) {
      if (e.key == id) {
        e.value.expand();
      } else if (e.value.isExpanded) {
        e.value.collapse();
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final ctx = _keys[id]?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.02);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(backgroundColor: AppColors.ink, title: const Text('Acerca de')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in manualSections)
                        ActionChip(
                          label: Text(s.title, style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.panel,
                          side: const BorderSide(color: _line),
                          onPressed: () => _go(s.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (final s in manualSections) _section(s),
                  const SizedBox(height: 16),
                  const Center(
                    child: Column(
                      children: [
                        Text('Mi Biblioteca', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('Hecha para escuchar con calma.', style: TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    Widget pill(String a, String b) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(99)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: a, style: const TextStyle(color: _muted)),
            TextSpan(text: b, style: const TextStyle(color: _orange, fontWeight: FontWeight.w600)),
          ]), style: const TextStyle(fontSize: 12)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 64, height: 64, child: CustomPaint(painter: _DiscPainter())),
        const SizedBox(height: 14),
        const Text('Mi Biblioteca', style: TextStyle(fontFamily: titleFont, fontSize: 36, height: 1.05)),
        const SizedBox(height: 6),
        const Text('Tu música en discos, cassettes y mesas de DJ. Todo vive en tu dispositivo.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          pill('Versión ', '1.0'),
          pill('', 'Manual de uso'),
          pill('', 'Sin cuenta, sin anuncios'),
        ]),
      ],
    );
  }

  Widget _section(ManualSection s) {
    return Padding(
      key: _keys[s.id],
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            controller: _ctrls[s.id],
            initiallyExpanded: s.id == 'inicio',
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            iconColor: _muted,
            collapsedIconColor: _muted,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _orange.withOpacity(.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(_icons[s.icon] ?? Icons.info_outline, color: _orange, size: 20),
            ),
            title: Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            subtitle: Text(s.subtitle, style: const TextStyle(fontSize: 13, color: _muted)),
            children: [for (final b in s.blocks) _block(b)],
          ),
        ),
      ),
    );
  }

  Widget _block(ManualBlock b) {
    const body = TextStyle(color: _text, fontSize: 15, height: 1.5);
    switch (b.kind) {
      case 'h':
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(b.text.toUpperCase(),
              style: const TextStyle(color: _orange, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
        );
      case 'ul':
      case 'ol':
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < b.items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.kind == 'ol')
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 10, top: 1),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                          child: Text('${i + 1}',
                              style: const TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 10, top: 8),
                          child: CircleAvatar(radius: 2.5, backgroundColor: _orange),
                        ),
                      Expanded(child: _rich(b.items[i], body)),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'tip':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1D201D),
            border: Border(left: BorderSide(color: _orange, width: 3)),
            borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
          ),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${b.title} ', style: const TextStyle(color: _orange, fontWeight: FontWeight.w700)),
            TextSpan(text: b.text),
          ]), style: const TextStyle(color: Color(0xFFF4EFE3), fontSize: 14, height: 1.45)),
        );
      case 'table':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Table(
            columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(2.4)},
            border: const TableBorder(horizontalInside: BorderSide(color: _line), bottom: BorderSide(color: _line)),
            children: [
              for (var r = 0; r < b.rows.length; r++)
                TableRow(children: [
                  for (final c in b.rows[r])
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: r == 0
                          ? Text(c.toUpperCase(),
                              style: const TextStyle(color: _muted, fontSize: 11, letterSpacing: .8))
                          : _rich(c, const TextStyle(color: _text, fontSize: 14, height: 1.4)),
                    ),
                ]),
            ],
          ),
        );
      default:
        return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: _rich(b.text, body));
    }
  }

  /// **negrita**, ~~cursiva~~ y [[botón]].
  Widget _rich(String s, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|~~(.+?)~~|\[\[(.+?)\]\]');
    var i = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > i) spans.add(TextSpan(text: s.substring(i, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF4EFE3))));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF1D201D),
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(m.group(3)!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF4EFE3))),
          ),
        ));
      }
      i = m.end;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i)));
    return Text.rich(TextSpan(children: spans), style: base);
  }
}

class _DiscPainter extends CustomPainter {
  const _DiscPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r + 5, Paint()..color = AppColors.panel);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B0B0A));
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0x14FFFFFF);
    for (var q = r * 0.34; q < r * 0.95; q += 3) {
      canvas.drawCircle(c, q, g);
    }
    canvas.drawCircle(c, r * 0.27, Paint()..color = _orange);
    canvas.drawCircle(c, r * 0.06, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => false;
}
