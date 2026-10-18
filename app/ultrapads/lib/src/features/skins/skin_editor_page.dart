import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/settings_state.dart';
import '../perform/pad_mapping.dart';
import 'skins_sheet.dart';

/// 自定义皮肤编辑器：基于内置皮肤，调整 semantic token（颜色 / 数值），
/// 实时预览，保存到本机，导出 / 导入 JSON（`UpSkin` schema）。
class SkinEditorPage extends ConsumerStatefulWidget {
  const SkinEditorPage({super.key, this.skinId});

  /// 编辑已有自定义皮肤；null 表示新建。
  final String? skinId;

  @override
  ConsumerState<SkinEditorPage> createState() => _SkinEditorPageState();
}

class _SkinEditorPageState extends ConsumerState<SkinEditorPage> {
  late String _base;
  late String _id;
  late final TextEditingController _name;
  UpSemanticOverrides _overrides = const UpSemanticOverrides.empty();
  String _group = 'pad';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    UpSkin? existing;
    for (final s in settings.customSkins) {
      if (s.id == widget.skinId) existing = s;
    }
    final currentBase = ref.read(upThemeProvider).baseId;
    _base = existing?.baseId ?? currentBase;
    _id = existing?.id ?? 'custom-${DateTime.now().millisecondsSinceEpoch}';
    _overrides = existing?.overrides ?? const UpSemanticOverrides.empty();
    _name = TextEditingController(text: existing?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  UpTheme get _theme =>
      UpTheme.custom(UpThemes.byId(_base), _overrides, id: _id);

  UpSkin _skin(BuildContext context) => UpSkin(
    id: _id,
    name: _name.text.trim().isEmpty
        ? context.l10n.skinCustom
        : _name.text.trim(),
    baseId: _base,
    overrides: _overrides,
  );

  void _set(String key, Object value) =>
      setState(() => _overrides = _overrides.put(key, value));

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: encodeSkin(_skin(context))));
    if (mounted) showUpToast(context, context.l10n.shareLinkCopied);
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    try {
      var ignored = 0;
      final json = (jsonDecode(data?.text ?? '') as Map)
          .cast<String, Object?>();
      final skin = UpSkin.fromJson(json, onUnknownKey: (_) => ignored++);
      setState(() {
        _base = skin.baseId;
        _overrides = skin.overrides;
        _name.text = skin.name;
      });
      if (ignored > 0) {
        showUpToast(context, l10n.skinEditorImportIgnored(ignored));
      }
    } catch (_) {
      showUpToast(context, l10n.skinEditorImportInvalid);
    }
  }

  void _save() {
    ref.read(settingsProvider.notifier).saveCustomSkin(_skin(context));
    showUpToast(context, context.l10n.skinApplied);
    context.pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await showUpConfirm(
      context,
      title: l10n.skinEditorDeleteTitle,
      confirm: l10n.commonDelete,
      cancel: l10n.commonCancel,
      danger: true,
    );
    if (!ok || !mounted) return;
    ref.read(settingsProvider.notifier).deleteCustomSkin(_id);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final theme = _theme;
    final groups = <String, String>{
      'pad': l10n.skinEditorGroupPad,
      'surface': l10n.skinEditorGroupSurface,
      'text': l10n.skinEditorGroupText,
      'accent': l10n.skinEditorGroupAccent,
    };
    final tokens = UpSemantic.tokens
        .where((t) => t.group == _group && t.type != UpSemanticType.gradient)
        .toList();
    final exists = ref
        .watch(settingsProvider)
        .customSkins
        .any((s) => s.id == _id);

    return Scaffold(
      backgroundColor: c.surfacePage,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              leading: UpIconButton(
                icon: Icons.close_rounded,
                semanticLabel: l10n.commonClose,
                onPressed: () => context.pop(),
              ),
              title: l10n.skinEditorTitle,
              centerTitle: true,
              trailing: [
                UpButton(
                  label: l10n.commonSave,
                  size: UpButtonSize.sm,
                  onPressed: _save,
                ),
              ],
            ),
            // 实时预览：用编辑中的主题渲染一块演奏区（AnimatedTheme 插值过渡）。
            AnimatedTheme(
              data: theme.toThemeData(),
              duration: UpMotion.duration(context, UpDurations.medium),
              child: Builder(
                builder: (context) => Container(
                  height: UpBannerTokens.height,
                  color: UpTheme.of(context).colors.surfacePads,
                  padding: const EdgeInsets.all(UpSpacing.md),
                  child: Row(
                    spacing: UpSpacing.md,
                    children: [
                      Expanded(
                        child: PadGrid(
                          pads: _previewPads,
                          bank: 0,
                          onPadDown: (_, _) {},
                          onPadUp: (_, _) {},
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: UpSpacing.sm,
                        children: [
                          UpChip(
                            label: l10n.navSongs,
                            icon: Icons.music_note_rounded,
                            variant: UpChipVariant.selected,
                          ),
                          UpChip(
                            label: l10n.performTutorial,
                            icon: Icons.school_rounded,
                          ),
                          UpButton(
                            label: l10n.commonApply,
                            size: UpButtonSize.sm,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(UpPageTokens.paddingX),
              child: Column(
                spacing: UpSpacing.md,
                children: [
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      hintText: l10n.skinEditorNameHint,
                    ),
                  ),
                  Row(
                    spacing: UpSpacing.sm,
                    children: [
                      UpText(
                        l10n.skinEditorBasedOn(skinName(context, _base)),
                        role: UpTextRole.label,
                        color: c.textSecondary,
                      ),
                      for (final id in UpThemes.ids)
                        UpChip(
                          label: skinName(context, id),
                          variant: id == _base
                              ? UpChipVariant.selected
                              : UpChipVariant.normal,
                          onTap: () => setState(() => _base = id),
                        ),
                    ],
                  ),
                  UpSegmentTabs(
                    labels: groups.values.toList(),
                    index: groups.keys.toList().indexOf(_group),
                    onChanged: (i) =>
                        setState(() => _group = groups.keys.elementAt(i)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: UpPageTokens.paddingX,
                ),
                itemCount: tokens.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: UpSpacing.xs),
                itemBuilder: (_, i) => _TokenRow(
                  info: tokens[i],
                  value: theme.colors.valueOf(tokens[i].key),
                  overridden: _overrides.values.containsKey(tokens[i].key),
                  onChanged: (v) => _set(tokens[i].key, v),
                  onReset: () => setState(
                    () => _overrides = _overrides.remove(tokens[i].key),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(UpPageTokens.paddingX),
              child: Wrap(
                spacing: UpSpacing.md,
                runSpacing: UpSpacing.md,
                alignment: WrapAlignment.center,
                children: [
                  UpText(
                    l10n.skinEditorChangeCount(_overrides.values.length),
                    role: UpTextRole.caption,
                    color: c.textSecondary,
                  ),
                  UpButton(
                    label: l10n.skinEditorResetAll,
                    variant: UpButtonVariant.ghost,
                    size: UpButtonSize.sm,
                    onPressed: () => setState(
                      () => _overrides = const UpSemanticOverrides.empty(),
                    ),
                  ),
                  UpButton(
                    label: l10n.skinEditorExport,
                    variant: UpButtonVariant.secondary,
                    size: UpButtonSize.sm,
                    onPressed: _export,
                  ),
                  UpButton(
                    label: l10n.skinEditorImport,
                    variant: UpButtonVariant.secondary,
                    size: UpButtonSize.sm,
                    onPressed: _import,
                  ),
                  if (exists)
                    UpButton(
                      label: l10n.commonDelete,
                      variant: UpButtonVariant.danger,
                      size: UpButtonSize.sm,
                      onPressed: _delete,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final List<PadData> _previewPads = [
    for (var i = 0; i < PadId.total; i++)
      PadData(
        role: i % ColorRole.values.length,
        loop: i % PadId.columns == 1,
        state: i == 4 ? PadVisualState.playing : PadVisualState.idle,
        label: padNumberLabel(i % PadId.padsPerBank),
      ),
  ];
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.info,
    required this.value,
    required this.overridden,
    required this.onChanged,
    required this.onReset,
  });

  final UpSemanticTokenInfo info;
  final Object value;
  final bool overridden;
  final ValueChanged<Object> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final trailing = switch (value) {
      Color color => UpSwatch(
        color: color,
        onTap: () async {
          final picked = await showColorDialog(context, color);
          if (picked != null) onChanged(picked);
        },
      ),
      double v => SizedBox(
        width: UpButtonTokens.wideWidth / 2,
        child: UpSlider(
          value: v,
          max: v > 1 ? v * 2 : 1,
          semanticLabel: info.key,
          onChanged: onChanged,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
    return UpListItem(
      title: info.key,
      subtitle: info.description,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          trailing,
          if (overridden)
            UpIconButton(
              icon: Icons.undo_rounded,
              color: c.accentPrimary,
              semanticLabel: l10n.skinEditorResetToken,
              onPressed: onReset,
            ),
        ],
      ),
    );
  }
}

/// RGBA 颜色选择对话框（四个滑块 + 预览）。
Future<Color?> showColorDialog(BuildContext context, Color initial) {
  final l10n = context.l10n;
  var color = initial;
  return showUpDialog<Color>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => UpDialog(
        title: l10n.kitEditorColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: UpSpacing.md,
          children: [
            Container(
              height: UpSizes.controlLg,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(UpRadii.lg),
              ),
            ),
            for (final (i, get) in [
              (0, (Color c) => c.r),
              (1, (Color c) => c.g),
              (2, (Color c) => c.b),
              (3, (Color c) => c.a),
            ])
              UpSlider(
                value: get(color),
                onChanged: (v) => setState(() {
                  // up-lint-ignore: skin editor constructs the user-picked override colour
                  color = Color.from(
                    alpha: i == 3 ? v : color.a,
                    red: i == 0 ? v : color.r,
                    green: i == 1 ? v : color.g,
                    blue: i == 2 ? v : color.b,
                  );
                }),
              ),
          ],
        ),
        actions: [
          UpButton(
            label: l10n.commonCancel,
            variant: UpButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
          ),
          UpButton(
            label: l10n.commonApply,
            onPressed: () => Navigator.pop(ctx, color),
          ),
        ],
      ),
    ),
  );
}
