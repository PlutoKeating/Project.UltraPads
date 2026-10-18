import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../assets/private_assets.dart';
import '../../routing/routes.dart';
import '../../state/settings_state.dart';

/// 皮肤显示名：内置预设（`UpSkinPreset.nameKey`）或内置主题；未知 id 显示 id 本身。
String skinName(BuildContext context, String id) {
  final l10n = context.l10n;
  final presetId = id.startsWith(presetPrefix)
      ? id.substring(presetPrefix.length)
      : null;
  if (presetId != null) {
    final p = UpSkinPresets.all.where((p) => p.id == presetId).firstOrNull;
    if (p != null) return presetName(l10n, p.nameKey);
  }
  return switch (id) {
    'neon' => l10n.skinNeon,
    'outline' => l10n.skinOutline,
    'light' => l10n.skinLight,
    _ => id,
  };
}

/// `skinPreset*` i18n key → 文案。
String presetName(UpL10n l10n, String key) => switch (key) {
  'skinPresetDefault' => l10n.skinPresetDefault,
  'skinPresetNumber' => l10n.skinPresetNumber,
  'skinPresetChristmas' => l10n.skinPresetChristmas,
  'skinPresetPets' => l10n.skinPresetPets,
  'skinPresetCover' => l10n.skinPresetCover,
  'skinPresetBroken' => l10n.skinPresetBroken,
  'skinPresetMuertos' => l10n.skinPresetMuertos,
  'skinPresetCrazy' => l10n.skinPresetCrazy,
  'skinPresetLaunchpad' => l10n.skinPresetLaunchpad,
  'skinPresetCrafts' => l10n.skinPresetCrafts,
  'skinPresetPolished' => l10n.skinPresetPolished,
  'skinPresetClean' => l10n.skinPresetClean,
  'skinPresetCircle' => l10n.skinPresetCircle,
  'skinPresetSquare' => l10n.skinPresetSquare,
  'skinPresetLgbt' => l10n.skinPresetLgbt,
  'skinPresetHalloween' => l10n.skinPresetHalloween,
  _ => key,
};

/// 私有缩略图（参考设计 `ScreenPads__img_skins_*` / `ScreenPads__skin_*`）。
ImageProvider? skinThumbnail(PrivateAssets assets, String id) {
  final presetId = id.startsWith(presetPrefix)
      ? id.substring(presetPrefix.length)
      : id;
  final file = switch (presetId) {
    'neon' || 'default' => 'ScreenPads__img_skins_normal.png',
    'outline' => 'ScreenPads__img_skins_outline.png',
    'number' => 'ScreenPads__img_skins_normal_number.png',
    'christmas' => 'ScreenPads__img_skins_chrismas.png',
    'crafts' => 'ScreenPads__img_skins_craft.png',
    'lgbt' => 'ScreenPads__skin_lgbt.png',
    'halloween' => 'ScreenPads__skin_halloween.png',
    'pets' ||
    'cover' ||
    'broken' ||
    'muertos' ||
    'crazy' ||
    'launchpad' ||
    'polished' ||
    'clean' ||
    'circle' ||
    'square' => 'ScreenPads__img_skins_$presetId.png',
    _ => null,
  };
  return file == null ? null : assets.image(assets.key('ios/ui/$file'));
}

/// 皮肤面板：从底部滑入（参考设计 `modalSkins`，0.4 s QuadOut），横向列表。
Future<void> showSkinsSheet(BuildContext context) =>
    showUpSheet<void>(context, builder: (_) => const SkinsSheet());

class SkinsSheet extends ConsumerWidget {
  const SkinsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final settings = ref.watch(settingsProvider);
    final assets = ref.watch(privateAssetsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    return UpSheet(
      title: l10n.skinTitle,
      scrollable: false,
      children: [
        SizedBox(
          height: UpSkinItemTokens.size,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: UpSkinItemTokens.marginStart,
            ),
            children: [
              for (final p in [
                ...UpSkinPresets.all,
              ]..sort((a, b) => a.order.compareTo(b.order)))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UpSpacing.sm),
                  child: SkinTile(
                    theme: p.toTheme(),
                    name: presetName(l10n, p.nameKey),
                    selected: settings.skinId == '$presetPrefix${p.id}',
                    thumbnail: skinThumbnail(assets, p.id),
                    onTap: () => ctrl.setSkin('$presetPrefix${p.id}'),
                  ),
                ),
              for (final id in UpThemes.ids)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UpSpacing.sm),
                  child: SkinTile(
                    theme: UpThemes.byId(id),
                    name: skinName(context, id),
                    selected: settings.skinId == id,
                    thumbnail: skinThumbnail(assets, id),
                    onTap: () => ctrl.setSkin(id),
                  ),
                ),
              for (final skin in settings.customSkins)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UpSpacing.sm),
                  child: GestureDetector(
                    onLongPress: () => context.push(
                      '${Routes.skinEditor}?id=${Uri.encodeComponent(skin.id)}',
                    ),
                    child: SkinTile(
                      theme: UpTheme.fromSkin(skin),
                      name: skin.name,
                      selected: settings.skinId == skin.id,
                      onTap: () => ctrl.setSkin(skin.id),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: UpSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: UpSpacing.xs,
                  children: [
                    PressScale(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(Routes.skinEditor);
                      },
                      child: Container(
                        width: UpSkinItemTokens.thumbSize,
                        height: UpSkinItemTokens.thumbSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            UpSkinItemTokens.radius,
                          ),
                          border: Border.all(
                            color: c.borderDefault,
                            width: UpBorderWidths.regular,
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: c.iconSecondary,
                          size: UpSizes.iconLg,
                        ),
                      ),
                    ),
                    UpText(
                      l10n.skinEditorNew,
                      role: UpTextRole.labelSm,
                      color: c.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
