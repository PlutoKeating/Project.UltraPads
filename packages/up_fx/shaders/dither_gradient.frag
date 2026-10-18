// pad 主体渐变（3 色标，径向或自上而下线性），带三角分布抖动。
//
// 为什么需要：Impeller（Android Vulkan / 模拟器 SwiftShader）对大面积、低对比的
// 径向渐变不做抖动，8 bit 量化后会看到一圈圈同心「色带」；在着色器里加 ±1/255 的
// 三角噪声把量化误差打散，肉眼不再看到环。Skia（Linux）默认对渐变抖动，所以 Linux
// 上本来就看不到。
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // 绘制区域（px）
uniform float uCorner;  // 圆角（px）
uniform float uRadial;  // 1 = 径向（中心），0 = 线性（上→下）
uniform float uExtent;  // 径向半径（占短边的比例，与 RadialGradient.radius 相同）
uniform vec4 uC0;       // 色标 0（非预乘 RGBA）
uniform vec4 uC1;
uniform vec4 uC2;
uniform vec3 uStops;    // 色标位置

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float t;
  if (uRadial > 0.5) {
    float extent = min(uSize.x, uSize.y) * uExtent;
    t = length(frag - uSize * 0.5) / max(extent, 1.0);
  } else {
    t = frag.y / max(uSize.y, 1.0);
  }
  t = clamp(t, 0.0, 1.0);
  vec4 c;
  if (t <= uStops.x) {
    c = uC0;
  } else if (t <= uStops.y) {
    c = mix(uC0, uC1, (t - uStops.x) / max(uStops.y - uStops.x, 1e-5));
  } else if (t <= uStops.z) {
    c = mix(uC1, uC2, (t - uStops.y) / max(uStops.z - uStops.y, 1e-5));
  } else {
    c = uC2;
  }
  // 三角分布抖动（两个均匀噪声之差），幅度 ±1/255。
  float n = hash(frag) - hash(frag + vec2(17.0, 31.0));
  c.rgb += n / 255.0;
  float inside = 1.0 - smoothstep(-0.5, 0.5, sdRoundRect(frag - uSize * 0.5, uSize * 0.5, uCorner));
  float a = clamp(c.a, 0.0, 1.0) * inside;
  fragColor = vec4(clamp(c.rgb, 0.0, 1.0) * a, a);
}
