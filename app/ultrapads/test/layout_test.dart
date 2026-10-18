import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/features/perform/perform_layout.dart';
import 'package:ultrapads/src/features/settings/settings_page.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import 'harness.dart';

/// 宽屏 / 平板布局（4.7.0 fixed_height）：网格按高度等比、水平居中。
void main() {
  test('grid aspect comes from the 4.7.0 cell geometry', () {
    expect(PerformLayout.gridAspect, closeTo(404.5 / 518, 1e-9));
  });

  test('phone: grid fills the width (unchanged)', () {
    expect(PerformLayout.isWide(phone), isFalse);
    expect(PerformLayout.columnWidth(phone), phone.width);
  });

  test('wide: grid width follows height and is narrower than the screen', () {
    const desktop = Size(1280, 800);
    final w = PerformLayout.columnWidth(desktop);
    expect(PerformLayout.isWide(desktop), isTrue);
    expect(w, lessThan(desktop.width));
    final gridH =
        desktop.height - PerformLayout.chromeTop - PerformLayout.chromeBottom;
    expect(
      w - 2 * UpPadGridTokens.pageInset,
      closeTo(gridH * PerformLayout.gridAspect, 1e-6),
    );
    final g = PerformLayout.gridSize(const Size(2000, 500));
    expect(g.width / g.height, closeTo(PerformLayout.gridAspect, 1e-9));
  });

  testWidgets('other pages are width-limited and centred on desktop', (
    t,
  ) async {
    final h = await pumpApp(t, size: const Size(1280, 800));
    h.container.read(routerProvider).push(Routes.settings);
    await settle(t);
    final page = t.getRect(find.byType(SettingsPage));
    expect(page.width, UpPadGridTokens.maxWidth);
    expect(page.center.dx, closeTo(640, 1));
    await shot(t, 'settings_desktop_1280x800');
  });

  for (final (name, size) in const [
    ('perform_desktop_1280x800', Size(1280, 800)),
    ('perform_desktop_1024x768', Size(1024, 768)),
    ('perform_tablet_768x1024', Size(768, 1024)),
  ]) {
    testWidgets('$name: grid centred with design aspect', (t) async {
      await pumpApp(t, size: size);
      final grid = t.getRect(find.byType(PadGrid));
      expect(grid.center.dx, closeTo(size.width / 2, 1));
      expect(grid.width / grid.height, closeTo(PerformLayout.gridAspect, 0.01));
      // A/B 与顶栏同列：A/B 按钮在网格右边缘之内。
      final bank = find.byType(BankButton);
      if (bank.evaluate().isNotEmpty) {
        expect(
          t.getRect(bank).right,
          lessThanOrEqualTo(grid.right + UpPadGridTokens.pageInset + 1),
        );
      }
      await shot(t, name);
    });
  }
}
