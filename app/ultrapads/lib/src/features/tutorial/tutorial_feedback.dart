import 'package:flutter/material.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/perform_state.dart';
import 'tutorial_timing.dart';

/// 判定反馈（4.7.0：PERFECT 底块上浮 + 绿色圆扩散；TOO FAST / TOO SLOW 旋转 ∓ 上浮）。
/// 显示在被按 pad 的位置，[TutorialTiming.feedback] 后消失。
class TutorialFeedbackLayer extends StatefulWidget {
  const TutorialFeedbackLayer({
    super.key,
    required this.feedback,
    required this.bank,
  });
  final TutorialFeedback? feedback;
  final int bank;

  @override
  State<TutorialFeedbackLayer> createState() => _TutorialFeedbackLayerState();
}

class _TutorialFeedbackLayerState extends State<TutorialFeedbackLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: TutorialTiming.feedback,
  );

  @override
  void didUpdateWidget(TutorialFeedbackLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedback != null &&
        widget.feedback!.serial != oldWidget.feedback?.serial) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = widget.feedback;
    if (fb == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final (String label, Color color, double tilt) = switch (fb.judgement) {
      TutorialJudgement.perfect => (l10n.tutorialPerfect, c.statusSuccess, 0.0),
      TutorialJudgement.tooFast => (
        l10n.tutorialTooFast,
        c.statusWarning,
        -TutorialTiming.missTilt,
      ),
      TutorialJudgement.tooSlow => (
        l10n.tutorialTooSlow,
        c.statusWarning,
        TutorialTiming.missTilt,
      ),
      TutorialJudgement.miss => (l10n.tutorialMiss, c.statusDanger, 0.0),
    };
    final reduce = FxMotion.reduce(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final flat = fb.flat;
          var center = box.biggest.center(Offset.zero);
          if (flat != null && flat ~/ PadId.padsPerBank == widget.bank) {
            final id = PadId.flat(flat);
            final w = box.maxWidth / PadId.columns;
            final h = box.maxHeight / PadId.rows;
            center = Offset(w * (id.column + 0.5), h * (id.row + 0.5));
          }
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              if (t == 0 || t == 1) return const SizedBox.shrink();
              final rise = reduce
                  ? 0.0
                  : UpTutorialTokens.perfectRise *
                        UpEasings.quadOut.transform(t);
              final fade = t < UpOpacities.muted
                  ? 1.0
                  : 1 - (t - UpOpacities.muted) / (1 - UpOpacities.muted);
              final ring = fb.judgement == TutorialJudgement.perfect && !reduce
                  ? t
                  : 0.0;
              return Stack(
                children: [
                  if (ring > 0)
                    Positioned(
                      left: center.dx - UpSizes.controlXl * ring,
                      top: center.dy - UpSizes.controlXl * ring,
                      width: UpSizes.controlXl * ring * 2,
                      height: UpSizes.controlXl * ring * 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.statusSuccess.withValues(
                            alpha: (1 - ring) * UpOpacities.muted,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: center.dx - UpButtonTokens.minWidth,
                    width: UpButtonTokens.minWidth * 2,
                    top: center.dy - rise - UpChipTokens.height / 2,
                    child: Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: tilt,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: UpSpacing.md,
                              vertical: UpSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: c.surfaceRaised,
                              borderRadius: BorderRadius.circular(UpRadii.md),
                            ),
                            child: UpText(
                              label,
                              role: UpTextRole.label,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
