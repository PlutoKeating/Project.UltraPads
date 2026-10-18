import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart';

/// 加载 `.riv` 资源的组件（后续交互动画用）。资源缺失时显示 [fallback]。
class RiveAssetView extends StatefulWidget {
  const RiveAssetView({
    super.key,
    required this.asset,
    required this.fallback,
    this.artboard,
    this.stateMachine,
    this.fit = BoxFit.contain,
    this.onInit,
  });

  final String asset;
  final String? artboard;
  final String? stateMachine;
  final BoxFit fit;
  final WidgetBuilder fallback;

  /// 状态机就绪后回调，可用于读写输入。
  final ValueChanged<StateMachineController>? onInit;

  @override
  State<RiveAssetView> createState() => _RiveAssetViewState();
}

class _RiveAssetViewState extends State<RiveAssetView> {
  late Future<RiveFile?> _file = _load();

  Future<RiveFile?> _load() async {
    try {
      return await RiveFile.asset(widget.asset);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(RiveAssetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) _file = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RiveFile?>(
    future: _file,
    builder: (context, snap) {
      final file = snap.data;
      if (file == null) return widget.fallback(context);
      return RiveAnimation.direct(
        file,
        artboard: widget.artboard,
        fit: widget.fit,
        stateMachines: [?widget.stateMachine],
        onInit: (artboard) {
          final sm = widget.stateMachine;
          if (sm == null) return;
          final ctrl = StateMachineController.fromArtboard(artboard, sm);
          if (ctrl == null) return;
          artboard.addController(ctrl);
          widget.onInit?.call(ctrl);
        },
      );
    },
  );
}
