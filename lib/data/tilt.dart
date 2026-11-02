import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'ui_settings.dart';

/// Inclinación del teléfono (acelerómetro, ~30 Hz) para el brillo del vinilo y del plástico.
/// Se activa solo con efectos activos (no en modo ahorro) y se cancela en segundo plano.
class Tilt with WidgetsBindingObserver {
  Tilt._();
  static final Tilt instance = Tilt._();

  /// x, y en -1..1 (suavizados).
  final ValueNotifier<Offset> value = ValueNotifier<Offset>(Offset.zero);

  StreamSubscription<AccelerometerEvent>? _sub;
  int _users = 0;
  int _lastMs = 0;
  bool _observing = false;

  /// Pide el sensor (cuenta de usuarios); devuelve una función para soltarlo.
  VoidCallback acquire() {
    _users++;
    _update();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _users--;
      _update();
    };
  }

  void _update() {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      UiSettings.powerSave.addListener(_update);
      _observing = true;
    }
    final want = _users > 0 && UiSettings.fx && _foreground;
    if (want && _sub == null) {
      try {
        _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(_onEvent, onError: (_) {});
      } catch (_) {}
    } else if (!want && _sub != null) {
      _sub!.cancel();
      _sub = null;
    }
  }

  bool _foreground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  void _onEvent(AccelerometerEvent e) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 33) return; // ~30 Hz
    _lastMs = now;
    final x = (e.x / 9.8).clamp(-1.0, 1.0).toDouble();
    final y = (e.y / 9.8).clamp(-1.0, 1.0).toDouble();
    final o = value.value;
    value.value = Offset(o.dx + (x - o.dx) * 0.25, o.dy + (y - o.dy) * 0.25);
  }
}

/// Carga única del shader de brillo (null si el dispositivo no lo soporta: se usa el degradado).
class SheenShader {
  static ui.FragmentProgram? program;
  static bool _tried = false;

  static Future<void> load() async {
    if (_tried) return;
    _tried = true;
    try {
      program = await ui.FragmentProgram.fromAsset('shaders/vinyl_sheen.frag');
    } catch (_) {
      program = null;
    }
  }
}
