import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';

import '../features/catalog/catalog_state.dart';
import '../routing/router.dart';
import '../state/settings_state.dart';

class UltraPadsApp extends ConsumerWidget {
  const UltraPadsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(upThemeProvider);
    final locale = ref.watch(localeControllerProvider);
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    // 常驻：登录状态恢复后立刻把待发的收藏 / 最近使用同步出去（不依赖打开曲库页）。
    ref.listen(cloudStateProvider, (_, _) {});
    // 字体加载完成后重建（UpThemes 按 UpFonts.revision 缓存）。
    return ValueListenableBuilder<int>(
      valueListenable: UpFonts.revision,
      builder: (context, _, _) => MaterialApp.router(
        onGenerateTitle: (c) => UpL10n.of(c).localeNativeName,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        // 皮肤切换：ThemeData.lerp → UpTheme.lerp 逐 token 插值。
        theme: theme.toThemeData(),
        themeAnimationDuration: UpDurations.slow,
        themeAnimationCurve: UpEasings.standard,
        locale: locale.locale,
        supportedLocales: UpL10n.supportedLocales,
        localizationsDelegates: UpL10n.localizationsDelegates,
        localeListResolutionCallback: UpLocales.resolutionCallback,
        builder: (context, child) => FxScope(
          animatePads: settings.animatePads,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
