// 按下波纹：从触点扩散的亮环，裁剪在圆角矩形内。
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;      // pad 尺寸
uniform vec2 uCenter;    // 触点（px）
uniform float uProgress; // 0..1
uniform float uRadius;   // 圆角（px）
uniform vec4 uColor;     // 波纹颜色
uniform float uPeak;     // 最大不透明度

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float inside = 1.0 - smoothstep(-1.0, 0.5, sdRoundRect(frag - uSize * 0.5, uSize * 0.5, uRadius));
  float maxR = length(uSize);
  float r = uProgress * maxR;
  float dist = length(frag - uCenter);
  float width = maxR * 0.18;
  float ring = smoothstep(r - width, r, dist) * (1.0 - smoothstep(r, r + width * 0.35, dist));
  float fill = (1.0 - smoothstep(0.0, r, dist)) * 0.35;
  float a = clamp((ring + fill) * (1.0 - uProgress) * uPeak * uColor.a, 0.0, 1.0) * inside;
  fragColor = vec4(uColor.rgb * a, a);
}
