import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 曲库顶部 Banner 轮播：居中项放大，左右露出相邻项，自动播放。
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onTap,
    this.autoplay = true,
    this.showIndicator = true,
    this.itemWidth = UpBannerTokens.width,
    this.itemHeight = UpBannerTokens.height,
    this.holderHeight = UpBannerTokens.holderHeight,
  });

  /// 单项尺寸（默认 featured banner 300×160；Kit 封面条用 kitCard.carousel*）。
  final double itemWidth;
  final double itemHeight;
  final double holderHeight;

  final int itemCount;
  final Widget Function(BuildContext context, int index, bool focused)
  itemBuilder;
  final ValueChanged<int>? onTap;
  final bool autoplay;
  final bool showIndicator;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  PageController? _controller;
  double _fraction = 0;
  Timer? _timer;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (!widget.autoplay || widget.itemCount < 2 || FxMotion.reduce(context)) {
      return;
    }
    _timer = Timer.periodic(UpBannerTokens.autoplay, (_) {
      final c = _controller;
      if (c == null || !c.hasClients) return;
      final next = (_page + 1) % widget.itemCount;
      c.animateToPage(
        next,
        duration: UpBannerTokens.transition,
        curve: UpBannerTokens.transitionCurve,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  PageController _controllerFor(double width) {
    final f = (widget.itemWidth / width).clamp(
      UpOpacities.faint,
      UpOpacities.full,
    );
    if (_controller == null || f != _fraction) {
      _controller?.dispose();
      _fraction = f;
      _controller = PageController(viewportFraction: f, initialPage: _page);
    }
    return _controller!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.holderHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final controller = _controllerFor(box.maxWidth);
              return PageView.builder(
                controller: controller,
                itemCount: widget.itemCount,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final page =
                        controller.hasClients &&
                            controller.position.haveDimensions
                        ? controller.page ?? _page.toDouble()
                        : _page.toDouble();
                    final d = (page - i).abs().clamp(0.0, 1.0);
                    final scale =
                        UpKitCardTokens.focusScale -
                        (UpKitCardTokens.focusScale - UpOpacities.full) * d -
                        d * UpOpacities.faint;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: GestureDetector(
                    onTap: widget.onTap == null ? null : () => widget.onTap!(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UpSpacing.xxs,
                      ),
                      child: Center(
                        child: SizedBox(
                          height: widget.itemHeight,
                          width: widget.itemWidth,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              UpBannerTokens.radius,
                            ),
                            child: widget.itemBuilder(context, i, i == _page),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.showIndicator && widget.itemCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: UpSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: UpBannerTokens.indicatorGap,
              children: [
                for (var i = 0; i < widget.itemCount; i++)
                  AnimatedContainer(
                    duration: UpMotion.duration(context, UpDurations.fast),
                    width: UpBannerTokens.indicatorSize,
                    height: UpBannerTokens.indicatorSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? c.bannerIndicatorActive
                          : c.bannerIndicator,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
