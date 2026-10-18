import 'package:flutter/material.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 录音按钮：点击开始 → 过渡动画（recTransition）→ 循环脉冲（recLoop），
/// 与 APK `bt_rec_transition` / `bt_rec_animation` 时序一致。
/// 私有 Lottie 可用时由应用通过 [lottieTransition]/[lottieLoop] 传入。
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.recording,
    required this.onPressed,
    this.elapsedLabel,
    this.semanticLabel,
    this.lottieLoop,
  });

  final bool recording;
  final VoidCallback? onPressed;
  final String? elapsedLabel;
  final String? semanticLabel;

  /// 私有 Lottie（`bt_rec_animation`）资源键。
  final String? lottieLoop;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  late final AnimationController _transition = AnimationController(
    vsync: this,
    duration: UpTrackCardTokens.recTransition,
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: UpTrackCardTokens.recLoop,
  );

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recording != widget.recording) _sync();
  }

  Future<void> _sync() async {
    if (widget.recording) {
      if (FxMotion.reduce(context)) {
        _transition.value = 1;
        return;
      }
      await _transition.forward(from: 0);
      if (mounted && widget.recording) _loop.repeat();
    } else {
      _loop.stop();
      _loop.value = 0;
      await _transition.reverse();
    }
  }

  @override
  void dispose() {
    _transition.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final size = UpTopBarTokens.recIconSize;
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      toggled: widget.recording,
      child: PressScale(
        onTap: widget.onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: UpSpacing.xs,
          children: [
            SizedBox.square(
              dimension: size,
              child: AnimatedBuilder(
                animation: Listenable.merge([_transition, _loop]),
                builder: (context, _) {
                  final t = _transition.value;
                  final pulse = 1 - (_loop.value * 2 - 1).abs();
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color.lerp(
                              c.iconPrimary,
                              c.statusRecording,
                              t,
                            )!,
                            width: UpBorderWidths.regular,
                          ),
                        ),
                      ),
                      Container(
                        width:
                            size *
                            (UpOpacities.strong - pulse * UpOpacities.subtle),
                        height:
                            size *
                            (UpOpacities.strong - pulse * UpOpacities.subtle),
                        decoration: BoxDecoration(
                          color: c.statusRecording,
                          borderRadius: BorderRadius.circular(
                            size * (1 - t * UpOpacities.strong) / 2,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (widget.recording && widget.elapsedLabel != null)
              UpText(
                widget.elapsedLabel!,
                role: UpTextRole.numeric,
                color: c.statusRecording,
              ),
          ],
        ),
      ),
    );
  }
}
