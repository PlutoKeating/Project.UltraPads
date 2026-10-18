import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';

/// 从 token（stiffness / damping / mass）构造的弹簧参数。
@immutable
class SpringSpec {
  const SpringSpec({
    required this.stiffness,
    required this.damping,
    required this.mass,
  });

  final double stiffness;
  final double damping;
  final double mass;

  SpringDescription get description =>
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping);

  /// 从 [from] 到 [to] 的弹簧模拟。
  SpringSimulation simulate(double from, double to, {double velocity = 0}) =>
      SpringSimulation(description, from, to, velocity);
}

/// 以弹簧物理驱动缩放：[scale] 变化时从当前值弹到新值。
/// 减少动效时直接跳变。
class SpringScale extends StatefulWidget {
  const SpringScale({
    super.key,
    required this.scale,
    required this.spring,
    required this.child,
  });

  final double scale;
  final SpringSpec spring;
  final Widget child;

  @override
  State<SpringScale> createState() => _SpringScaleState();
}

class _SpringScaleState extends State<SpringScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.scale,
  );

  @override
  void didUpdateWidget(SpringScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scale != widget.scale) {
      if (FxMotion.reduce(context)) {
        _c.value = widget.scale;
      } else {
        _c.animateWith(
          widget.spring.simulate(_c.value, widget.scale, velocity: _c.velocity),
        );
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => Transform.scale(scale: _c.value, child: child),
  );
}
