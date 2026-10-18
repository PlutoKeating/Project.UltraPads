# up_fx

动效与光效。所有时长、曲线、颜色、尺寸由调用方从 `up_tokens` 传入，本包不含魔法数。

| 模块 | 内容 |
|---|---|
| `SegmentedLottie` | pad 按下分段播放（按下 0→split，松手 split→1，Launchpad 整段），循环模式；资源缺失 / 关闭动画 / 减少动效时显示 fallback |
| `NeonGlow` | 霓虹 bloom（`shaders/neon_bloom.frag`），低端回退 `BoxShadow`（token 光晕配方） |
| `PressRipple` | 按下波纹（`shaders/press_ripple.frag`），回退为淡出圆 |
| `LoopBreathe` | Loop 描边呼吸 + 流光（`shaders/loop_breathe.frag`），回退为透明度呼吸描边 |
| `FxShaders` | `FragmentProgram` 预加载与缓存，失败返回 null |
| `FxScope` / `FxTier` | 设备分级：full（shader）/ lite（BoxShadow，Web 和测试）/ minimal（减少动效）；「动画 Pad」开关 |
| `FxMotion` | `MediaQuery.disableAnimations` 适配：时长归零、曲线线性 |
| `SpringSpec` / `SpringScale` | 由 token（stiffness / damping / mass）构造的弹簧与弹簧缩放 |
| `RiveAssetView` | 加载 `.riv`（可选状态机），缺失时 fallback（rive 0.13，纯 Dart 渲染） |

着色器在 `pubspec.yaml` 的 `flutter.shaders` 中声明。
