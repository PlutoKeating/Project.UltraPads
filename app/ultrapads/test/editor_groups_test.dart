import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_ui/up_ui.dart';

import 'harness.dart';

void main() {
  testWidgets('editor: add, move and delete sound groups (live in engine)', (
    t,
  ) async {
    final h = await pumpApp(t, size: const Size(414, 1200));
    h.container.read(routerProvider).push(Routes.editor);
    await settle(t);

    // 演示 Kit 只有 A 组：新增一个空的 B 组
    expect(find.byKey(const ValueKey('editor-group-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-group-1')), findsNothing);
    await t.tap(find.byKey(const ValueKey('editor-add-group')));
    await settle(t);
    expect(find.byKey(const ValueKey('editor-group-1')), findsOneWidget);

    // A 组右移：原 A 组的 pad 移到 B 组，引擎实时同步
    final firstA = h.engine.snapshot().paramsOf(const PadId(0, 0));
    expect(firstA.isEmpty, isFalse);
    await t.tap(find.byKey(const ValueKey('editor-group-0')));
    await settle(t);
    await t.tap(find.byIcon(Icons.chevron_right_rounded));
    await settle(t);
    expect(
      h.engine.snapshot().paramsOf(const PadId(1, 0)).sample,
      firstA.sample,
    );
    expect(h.engine.snapshot().paramsOf(const PadId(0, 0)).isEmpty, isTrue);

    // 删除有声音的组需要确认；删除后后面的组前移
    await t.tap(find.byKey(const ValueKey('editor-delete-group')));
    await settle(t);
    expect(find.byType(UpDialog), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byType(UpDialog),
        matching: find.byWidgetPredicate(
          (w) => w is UpButton && w.variant == UpButtonVariant.danger,
        ),
      ),
    );
    await settle(t);
    expect(find.byKey(const ValueKey('editor-group-1')), findsNothing);
    expect(h.engine.snapshot().paramsOf(const PadId(1, 0)).isEmpty, isTrue);
  });
}
