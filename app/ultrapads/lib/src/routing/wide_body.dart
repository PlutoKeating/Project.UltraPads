import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

/// 宽屏（平板 / 桌面）时把手机布局的页面限宽居中，两侧用 [gutter] 色填充
/// （默认 `surface.page`）。手机宽度下等同于直接显示 [child]。
///
/// 演奏页有自己的 fixed_height 布局（`PerformLayout`），设计画廊需要全宽，二者不用。
class WideBody extends StatelessWidget {
  const WideBody({super.key, required this.child, this.gutter});

  final Widget child;
  final Color? gutter;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: gutter ?? UpTheme.of(context).colors.surfacePage,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: UpPadGridTokens.maxWidth),
        child: child,
      ),
    ),
  );
}
