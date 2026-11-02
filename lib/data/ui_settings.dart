import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo se ve el menú principal y el interior de cada biblioteca.
class UiSettings {
  /// Menú principal en anillo 360° (si no, el clásico de cajones).
  static final ValueNotifier<bool> homeRing = ValueNotifier<bool>(true);

  /// Interior de cada biblioteca en anillos 360° (si no, la caja de discos clásica).
  static final ValueNotifier<bool> libRing = ValueNotifier<bool>(true);

  /// Animaciones al abrir un disco o cassette.
  static final ValueNotifier<bool> animations = ValueNotifier<bool>(true);

  static Future<void> setAnimations(bool v) async {
    animations.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('ui_animations', v);
    } catch (_) {}
  }

  /// Modo ahorro: apaga shader, sensores, desgaste, sombras dinámicas y animaciones 3D.
  static final ValueNotifier<bool> powerSave = ValueNotifier<bool>(false);

  /// Efectos visuales activos (lo contrario del modo ahorro).
  static bool get fx => !powerSave.value;

  static Future<void> setPowerSave(bool v) async {
    powerSave.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('ui_power_save', v);
    } catch (_) {}
  }

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      homeRing.value = p.getBool('ui_home_ring') ?? true;
      libRing.value = p.getBool('ui_lib_ring') ?? true;
      animations.value = p.getBool('ui_animations') ?? true;
      powerSave.value = p.getBool('ui_power_save') ?? false;
    } catch (_) {}
  }

  static Future<void> setHome(bool v) async {
    homeRing.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('ui_home_ring', v);
    } catch (_) {}
  }

  static Future<void> setLib(bool v) async {
    libRing.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('ui_lib_ring', v);
    } catch (_) {}
  }
}
