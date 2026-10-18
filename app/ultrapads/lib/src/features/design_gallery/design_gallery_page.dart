import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../routing/routes.dart';
import '../../state/settings_state.dart';
import '../skins/skins_sheet.dart';
import 'component_gallery.dart';
import 'motion_gallery.dart';
import 'token_browser.dart';

/// 应用内设计画廊（Storybook 式，替代 Figma，ADR-0001 #13 修订）：
/// ① token 浏览 ② 组件状态 ③ 主题与 16 套皮肤预设（实时 lerp）④ 动效演示。
///
/// 入口：设置 → 开发者 → 设计画廊；或 `--dart-define=UP_GALLERY=true` 直接进入。
class DesignGalleryPage extends ConsumerStatefulWidget {
  const DesignGalleryPage({super.key, this.initialTab = 0, this.initialSkin});

  final int initialTab;

  /// 画廊内预览的皮肤 id（null = 跟随应用当前皮肤）。
  final String? initialSkin;

  @override
  ConsumerState<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends ConsumerState<DesignGalleryPage> {
  late int _tab = widget.initialTab;
  late String? _skin = widget.initialSkin;

  /// 画廊可预览的全部皮肤 id：内置主题 + 内置预设 + 自定义。
  List<String> _skinIds(AppSettings s) => [
    ...UpThemes.ids,
    for (final p in [
      ...UpSkinPresets.all,
    ]..sort((a, b) => a.order.compareTo(b.order)))
      '$presetPrefix${p.id}',
    for (final k in s.customSkins) k.id,
  ];

  UpTheme _themeFor(String id, AppSettings s) {
    for (final k in s.customSkins) {
      if (k.id == id) return UpTheme.fromSkin(k);
    }
    if (id.startsWith(presetPrefix)) {
      for (final p in UpSkinPresets.all) {
        if ('$presetPrefix${p.id}' == id) return p.toTheme();
      }
    }
    return UpThemes.byId(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final skin = _skin ?? settings.skinId;
    final theme = _themeFor(skin, settings);
    final tabs = [
      l10n.settingsGalleryTokens,
      l10n.settingsGalleryComponents,
      l10n.settingsGallerySkins,
      l10n.settingsGalleryMotion,
    ];

    // AnimatedTheme：切换皮肤时 UpTheme.lerp 逐 token 插值。
    return AnimatedTheme(
      data: theme.toThemeData(),
      duration: UpMotion.duration(context, UpDurations.slow),
      curve: UpEasings.quadOut,
      child: Builder(
        builder: (context) {
          final c = UpTheme.of(context).colors;
          return Scaffold(
            backgroundColor: c.surfacePage,
            body: SafeArea(
              child: Column(
                children: [
                  UpTopBar(
                    leading: UpIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: l10n.commonBack,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.perform),
                    ),
                    title: l10n.settingsDesignGallery,
                    centerTitle: true,
                    trailing: [
                      UpIconButton(
                        icon: Icons.check_rounded,
                        semanticLabel: l10n.skinApply,
                        onPressed: () {
                          ref.read(settingsProvider.notifier).setSkin(skin);
                          showUpToast(context, l10n.skinApplied);
                        },
                      ),
                    ],
                  ),
                  SizedBox(
                    height: UpChipTokens.height + UpSpacing.lg,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: UpPageTokens.paddingX,
                        vertical: UpSpacing.sm,
                      ),
                      children: [
                        for (final id in _skinIds(settings))
                          Padding(
                            padding: const EdgeInsets.only(right: UpSpacing.sm),
                            child: UpChip(
                              label:
                                  settings.customSkins
                                      .where((k) => k.id == id)
                                      .firstOrNull
                                      ?.name ??
                                  skinName(context, id),
                              variant: id == skin
                                  ? UpChipVariant.selected
                                  : UpChipVariant.normal,
                              onTap: () => setState(() => _skin = id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  UpSegmentTabs(
                    labels: tabs,
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  Expanded(
                    child: switch (_tab) {
                      0 => const TokenBrowser(),
                      1 => const ComponentGallery(),
                      2 => _SkinGrid(
                        ids: _skinIds(settings),
                        selected: skin,
                        themeFor: (id) => _themeFor(id, settings),
                        onSelect: (id) => setState(() => _skin = id),
                      ),
                      _ => const MotionGallery(),
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ③ 主题与皮肤：所有皮肤的预览网格，点选后整页实时过渡。
class _SkinGrid extends ConsumerWidget {
  const _SkinGrid({
    required this.ids,
    required this.selected,
    required this.themeFor,
    required this.onSelect,
  });
  final List<String> ids;
  final String selected;
  final UpTheme Function(String id) themeFor;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return GridView.extent(
      maxCrossAxisExtent: UpSkinItemTokens.size,
      padding: const EdgeInsets.all(UpPageTokens.paddingX),
      mainAxisSpacing: UpSpacing.lg,
      crossAxisSpacing: UpSpacing.md,
      childAspectRatio: UpSkinItemTokens.thumbSize / UpSkinItemTokens.size,
      children: [
        for (final id in ids)
          SkinTile(
            theme: themeFor(id),
            name:
                settings.customSkins
                    .where((k) => k.id == id)
                    .firstOrNull
                    ?.name ??
                skinName(context, id),
            selected: id == selected,
            onTap: () => onSelect(id),
          ),
      ],
    );
  }
}
