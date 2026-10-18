// Loop 描边呼吸：沿圆角矩形描边的亮度随相位呼吸，并有一段流光绕边旋转。
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // pad 尺寸
uniform float uRadius;  // 圆角（px）
uniform float uWidth;   // 描边宽（px）
uniform float uPhase;   // 0..1（一圈）
uniform vec4 uColor;
uniform float uMin;     // 呼吸最低亮度

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 p = FlutterFragCoord().xy - uSize * 0.5;
  float d = sdRoundRect(p, uSize * 0.5 - vec2(uWidth * 0.5), uRadius);
  float stroke = 1.0 - smoothstep(uWidth * 0.5 - 0.75, uWidth * 0.5 + 0.75, abs(d));
  float halo = exp(-abs(d) / max(uWidth * 2.0, 1.0)) * 0.35;
  float breathe = mix(uMin, 1.0, 0.5 + 0.5 * cos(uPhase * 6.2831853));
  float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
  float sweep = pow(fract(ang - uPhase), 6.0);
  float a = clamp((stroke + halo) * (breathe + sweep * 0.8) * uColor.a, 0.0, 1.0);
  fragColor = vec4(uColor.rgb * a, a);
}
