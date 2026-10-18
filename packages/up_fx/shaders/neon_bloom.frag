// 霓虹 bloom：围绕圆角矩形的柔光晕（画布比 pad 大 2*spread）。
// uniforms 全部由 Dart 端从 token 传入。
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;       // 画布尺寸（含外扩）
uniform vec2 uRectSize;   // pad 尺寸
uniform float uRadius;    // pad 圆角（px）
uniform float uSpread;    // 光晕外扩（px）
uniform vec4 uColor;      // 光晕颜色（预乘前的 rgba）
uniform float uIntensity; // 0..1

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 p = FlutterFragCoord().xy - uSize * 0.5;
  float d = sdRoundRect(p, uRectSize * 0.5, uRadius);
  // 外侧指数衰减 + 内侧轻微溢光
  float outside = max(d, 0.0) / max(uSpread, 1.0);
  float glow = exp(-outside * outside * 4.0) * step(0.0, d);
  float inner = (1.0 - step(0.0, d)) * 0.15;
  float a = clamp((glow + inner) * uIntensity * uColor.a, 0.0, 1.0);
  fragColor = vec4(uColor.rgb * a, a);
}
