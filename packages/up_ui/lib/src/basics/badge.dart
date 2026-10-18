import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

enum UpBadgeKind { neutral, isNew, top }

class UpBadge extends StatelessWidget {
  const UpBadge({
    super.key,
    required this.label,
    this.kind = UpBadgeKind.neutral,
  });
  final String label;
  final UpBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final (Color bg, Color fg) = switch (kind) {
      UpBadgeKind.neutral => (c.badgeBackground, c.badgeForeground),
      UpBadgeKind.isNew => (c.badgeNew, c.badgeForeground),
      UpBadgeKind.top => (c.badgeTop, c.badgeTopForeground),
    };
    return Container(
      height: UpBadgeTokens.height,
      padding: const EdgeInsets.symmetric(horizontal: UpBadgeTokens.paddingX),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(UpBadgeTokens.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [UpText(label, role: UpTextRole.labelSm, color: fg)],
      ),
    );
  }
}
