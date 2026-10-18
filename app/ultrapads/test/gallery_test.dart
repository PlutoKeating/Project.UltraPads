import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/features/design_gallery/component_gallery.dart';
import 'package:ultrapads/src/features/design_gallery/token_browser.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';
import 'package:ultrapads/src/state/settings_state.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import 'harness.dart';

/// 画廊截图用高一点的画布，尽量多展示组件。
const tall = Size(414, 1600);

void main() {
  testWidgets('gallery: tabs, skin switch, apply skin', (t) async {
    final h = await pumpApp(t);
    h.container.read(routerProvider).push(Routes.gallery);
    await settle(t);
    expect(find.byType(TokenBrowser), findsOneWidget);
    expect(find.byType(ColorChip), findsWidgets);

    // 组件页
    await t.tap(find.byType(UpSegmentTabs).first);
    await t.tap(
      find.text('COMPONENTS').evaluate().isEmpty
          ? find.text('Components')
          : find.text('COMPONENTS'),
    );
    await settle(t);
    expect(find.byType(ComponentGallery), findsOneWidget);
    expect(find.byType(UpPad), findsWidgets);

    // 切换预设皮肤 + 应用
    final presetChip = find.widgetWithText(UpChip, 'Default').evaluate().isEmpty
        ? find.byType(UpChip).at(UpThemes.ids.length)
        : find.widgetWithText(UpChip, 'Default');
    await t.tap(presetChip);
    await settle(t);
    await t.tap(find.byIcon(Icons.check_rounded).first);
    await settle(t);
    expect(h.container.read(settingsProvider).skinId, isNot('neon'));
  });

  testWidgets('gallery motion tab: pad press + bank flip', (t) async {
    final h = await pumpApp(t, size: tall);
    h.container.read(routerProvider).push('${Routes.gallery}?tab=3');
    await settle(t);
    final pad = find.byType(UpPad).first;
    final g = await t.startGesture(t.getCenter(pad));
    await t.pump(const Duration(milliseconds: 50));
    expect(t.widget<UpPad>(pad).pressed, isTrue);
    await g.up();
    await t.tap(find.byType(BankButton));
    await settle(t);
    await shot(t, 'gallery_motion');
  });

  // 每个主题 / 皮肤预设一份 golden（组件页）。
  final ids = [
    ...UpThemes.ids,
    for (final p in UpSkinPresets.all) '$presetPrefix${p.id}',
  ];
  for (final id in ids) {
    testWidgets('gallery golden $id', (t) async {
      final h = await pumpApp(t, size: tall);
      h.container
          .read(routerProvider)
          .push('${Routes.gallery}?tab=1&skin=${Uri.encodeComponent(id)}');
      await shot(t, 'gallery_${id.replaceAll(presetPrefix, 'preset_')}');
    });
  }

  testWidgets('gallery token browser golden', (t) async {
    final h = await pumpApp(t, size: tall);
    h.container.read(routerProvider).push(Routes.gallery);
    await shot(t, 'gallery_tokens');
  });
}
