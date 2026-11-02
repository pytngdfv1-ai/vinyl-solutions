import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/vinyl.dart';
import '../data/tilt.dart';
import 'cassette_body.dart';

/// Casetero en modo oscuro: tapa de vidrio y un cassette realista
/// (carcasa transparente, etiqueta con renglones, carretes con dientes,
/// cinta que pasa de un carrete al otro, rodillos y tornillos) más las
/// teclas mecánicas REW / PLAY / PAUSE / F.F / EJECT.
class CassetteDeck extends StatefulWidget {
  const CassetteDeck({
    super.key,
    required this.vinyl,
    required this.playing,
    required this.label,
    this.progress = 0,
    this.trackIndex = 0,
    this.onPlay,
    this.onPause,
    this.onPrev,
    this.onNext,
    this.onEject,
    this.bayKey,
    this.hideCassette = false,
  });

  /// Llave de la ranura (para animar la inserción / expulsión) y ocultar el cassette mientras tanto.
  final GlobalKey? bayKey;
  final bool hideCassette;

  final Vinyl vinyl;
  final bool playing;

  /// Texto de la etiqueta: "Tema – Artista".
  final String label;
  final double progress;
  final int trackIndex;
  final VoidCallback? onPlay, onPause, onPrev, onNext, onEject;

  @override
  State<CassetteDeck> createState() => _CassetteDeckState();
}

class _CassetteDeckState extends State<CassetteDeck> with SingleTickerProviderStateMixin {
  final _st = ReelState();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  // Radios (en alturas del cassette): la cinta avanza a velocidad constante,
  // así que el carrete con menos cinta gira más rápido.
  static const _rMax = 0.1245, _rMin = 0.101, _rMid = 0.1128;

  // Velocidad de los carretes (0..1 de la velocidad de reproducción): sube/baja con resorte.
  double _speed = 0, _speedVel = 0;

  void _tick(Duration e) {
    final dt = (e - _last).inMicroseconds / 1e6;
    _last = e;
    if (dt <= 0 || dt > 0.5) return;
    // Resorte críticamente amortiguado con un pequeño rebote hacia la velocidad objetivo.
    final target = widget.playing ? 1.0 : 0.0;
    const k = 38.0, c = 9.0;
    _speedVel += (k * (target - _speed) - c * _speedVel) * dt;
    _speed += _speedVel * dt;
    if (_speed < 0) _speed = 0;
    if (!widget.playing && _speed < 0.002 && _speedVel.abs() < 0.01) {
      _speed = 0;
      _speedVel = 0;
      _ticker.stop();
      return;
    }
    final o = _st.overall;
    final rl = _rMax - (_rMax - _rMin) * o;
    final rr = _rMin + (_rMax - _rMin) * o;
    const w0 = 2.6; // rad/s con el rollo a medio radio
    // Antihorario. El carrete con menos cinta (radio menor) gira más rápido; el de salida
    // acelera a medida que avanza el cassette.
    _st.aL -= w0 * _rMid / rl * dt * _speed;
    _st.aR -= w0 * _rMid / rr * dt * _speed;
    _st.tick();
  }

  void _sync() {
    if (widget.playing && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.playing && _ticker.isActive) {
      // Se queda corriendo hasta que el resorte frene los carretes.
    } else if (!widget.playing && !_ticker.isActive && _speed > 0) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  VoidCallback? _releaseTilt;

  void _onTilt() {
    _st.light = (0.5 + 0.5 * Tilt.instance.value.value.dx).clamp(0.0, 1.0).toDouble();
    if (!_ticker.isActive) _st.tick();
  }

  @override
  void initState() {
    super.initState();
    _releaseTilt = Tilt.instance.acquire();
    Tilt.instance.value.addListener(_onTilt);
    _sync();
  }

  @override
  void didUpdateWidget(covariant CassetteDeck old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    Tilt.instance.value.removeListener(_onTilt);
    _releaseTilt?.call();
    _ticker.dispose();
    _st.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    final n = math.max(1, v.tracks.length);
    final overall = ((widget.trackIndex + widget.progress) / n).clamp(0.0, 1.0).toDouble();
    final sideB = n > 1 && widget.trackIndex >= (n / 2).ceil();
    final tint = HSLColor.fromAHSL(1, v.hue % 360, 0.62, 0.5).toColor();
    _st.overall = overall;
    _st.tint = tint;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cw = w * 0.84;
      final ch = cw / 1.57; // proporción real de un cassette
      return Container(
        padding: EdgeInsets.fromLTRB(w * 0.04, w * 0.035, w * 0.04, w * 0.04),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.04),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF34373A), Color(0xFF232527), Color(0xFF17181A)],
          ),
          border: Border.all(color: const Color(0xFF4A4D50), width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Franja superior: rejilla del parlante, LED y marca.
            SizedBox(
              height: w * 0.075,
              child: Row(
                children: [
                  CassetteScrew(w * 0.03),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: CustomPaint(painter: _GrillePainter(), size: Size.infinite),
                  ),
                  SizedBox(width: w * 0.03),
                  Text('STEREO',
                      style: TextStyle(
                          color: const Color(0xFF8C9094),
                          fontSize: w * 0.026,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800)),
                  SizedBox(width: w * 0.025),
                  Container(
                    width: w * 0.024,
                    height: w * 0.024,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.playing ? const Color(0xFF42F56B) : const Color(0xFF2A3A2E),
                      boxShadow: widget.playing
                          ? const [BoxShadow(color: Color(0xAA42F56B), blurRadius: 8)]
                          : null,
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  CassetteScrew(w * 0.03),
                ],
              ),
            ),
            SizedBox(height: w * 0.02),
            // Bahía del cassette con tapa de vidrio.
            Container(
              padding: EdgeInsets.all(w * 0.03),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(w * 0.025),
                color: const Color(0xFF070708),
                border: Border.all(color: const Color(0xFF55585B), width: 1.4),
                boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6, spreadRadius: -1)],
              ),
              child: SizedBox(
                width: cw,
                height: ch,
                child: KeyedSubtree(
                  key: widget.bayKey,
                  child: Opacity(
                    opacity: widget.hideCassette ? 0 : 1,
                    child: RepaintBoundary(
                      child: CassetteBody(vinyl: v, label: widget.label, sideB: sideB, st: _st),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: w * 0.035),
            // Teclas mecánicas.
            Container(
              padding: EdgeInsets.fromLTRB(w * 0.02, w * 0.012, w * 0.02, w * 0.02),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3A3C3E)),
              ),
              child: Row(
                children: [
                  _Key('REW', Icons.fast_rewind, widget.onPrev),
                  _Key('PLAY', Icons.play_arrow, widget.onPlay, pressed: widget.playing),
                  _Key('PAUSE', Icons.pause, widget.onPause),
                  _Key('F.F', Icons.fast_forward, widget.onNext),
                  _Key('EJECT', Icons.eject, widget.onEject),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _GrillePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xFF0A0A0B);
    final hi = Paint()..color = const Color(0x22FFFFFF);
    const step = 7.0;
    for (var y = step / 2; y < s.height; y += step) {
      for (var x = step / 2; x < s.width; x += step) {
        canvas.drawCircle(Offset(x, y + 0.6), 1.5, hi);
        canvas.drawCircle(Offset(x, y), 1.5, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.icon, this.onTap, {this.pressed = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onTap!();
              },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 8.5,
                      letterSpacing: 0.6,
                      color: Color(0xFF9A9EA2),
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 46,
                margin: EdgeInsets.only(top: pressed ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: pressed
                        ? const [Color(0xFF3A3C3F), Color(0xFF2A2B2D)]
                        : const [Color(0xFF6A6D71), Color(0xFF3F4144)],
                  ),
                  border: Border.all(color: const Color(0xFF16171A)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black,
                        offset: Offset(0, pressed ? 1 : 4),
                        blurRadius: pressed ? 1 : 2),
                  ],
                ),
                child: Center(
                  child: Icon(icon,
                      size: 20,
                      color: pressed ? const Color(0xFF7CF59A) : const Color(0xFFD4D6D9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
