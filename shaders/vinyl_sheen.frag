#version 460 core
#include <flutter/runtime_effect.glsl>

// Brillo angular del vinilo (anisotrópico): dos lóbulos opuestos que giran con el disco
// y se desplazan según la inclinación del teléfono.
uniform vec2 uSize;
uniform float uAngle;      // rotación del disco + luz
uniform vec2 uTilt;        // inclinación del teléfono (-1..1)
uniform float uIntensity;  // 0..1

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy / uSize - vec2(0.5);
  float r = length(p) * 2.0;
  if (r > 0.985 || r < 0.12) {
    fragColor = vec4(0.0);
    return;
  }
  float a = atan(p.y, p.x);
  // Dirección de la luz según la inclinación.
  float la = uAngle + atan(uTilt.y + 0.001, uTilt.x + 0.001);
  float d = cos(2.0 * (a - la));
  float lobe = pow(max(d, 0.0), 14.0);
  // Brillo fino adicional que cambia con el radio (efecto "arcoíris" sutil de los surcos).
  float fine = 0.5 + 0.5 * cos(r * 70.0 + 3.0 * (a - la));
  float tiltMag = clamp(length(uTilt), 0.0, 1.0);
  float k = (0.20 + 0.45 * tiltMag) * uIntensity;
  float v = lobe * (0.55 + 0.45 * fine) * k;
  vec3 tint = mix(vec3(1.0), vec3(0.75, 0.85, 1.0), 0.5 * fine);
  fragColor = vec4(tint * v, v);
}
