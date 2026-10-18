import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../assets/private_assets.dart';
import '../../routing/routes.dart';
import '../../state/engine_state.dart';
import '../../state/perform_state.dart';
import '../../state/settings_state.dart';
import '../../update/update_controller.dart';
import '../recorder/save_recording_sheet.dart';
import '../skins/skins_sheet.dart';
import '../onboarding/first_guide.dart';
import 'keyboard_map.dart';
import 'pad_mapping.dart';
import 'perform_layout.dart';
import 'perform_toolbar.dart';

/// 演奏页用到的引擎投影字段。只订阅这些：走带位置（播放时约 60 Hz）不触发整页重建。
typedef _PerformView = ({
  List<PadParams> pads,
  List<PadPlayState> padStates,
  KitSummary? kit,
  RecorderState recorder,
  double recordElapsed,
  bool controllerMode,
});

_PerformView _performView(EngineView v) => (
  pads: v.pads,
  padStates: v.padStates,
  kit: v.kit,
  recorder: v.recorder,
  recordElapsed: v.recordElapsed,
  controllerMode: v.controllerMode,
);

/// 演奏页（启动页），布局以 App Store 4.7.0（`ScreenPads/Main`）为准：
///
/// ```
/// [♫ SONGS] KIT <名称>                     [速度 1.0（教程模式）]
/// [🎓 LEARN TO PLAY | ⋮]  ⇄  [● ◐ ✎ ⤴ ⚙ ◀]               [ A ]
///   教程模式：[▶/■ ———————o——— ✕]
/// ┌────┬────┬────┐
/// │    │    │    │  3 × 4，A/B 两页横移切换
/// └────┴────┴────┘
/// ```
class PerformPage extends ConsumerStatefulWidget {
  const PerformPage({super.key});

  @override
  ConsumerState<PerformPage> createState() => _PerformPageState();
}

class _PerformPageState extends ConsumerState<PerformPage> {
  final _focus = FocusNode(debugLabel: 'perform-keyboard');
  final Map<PhysicalKeyboardKey, int> _heldKeys = {};
  final Set<int> _keyPressed = {};
  final Set<String> _reported = {};
  StreamSubscription<EngineEvent>? _events;
  bool _toolsExpanded = false;

  @override
  void initState() {
    super.initState();
    _events = ref.read(engineProvider).events.listen(_onEngineEvent);
    // 启动后静默检查一次新版本（设置可关）；有新版时由 _onUpdate 提示一次
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(updateProvider.notifier).autoCheck(),
    );
  }

  static const _kUpdateNotified = 'updateNotified';

  /// 每个新版本只提示一次（详情与操作在设置 → 关于 → 软件更新）。
  void _onUpdate(UpdateState? prev, UpdateState next) {
    final latest = next.info?.latest;
    if (next.phase != UpdatePhase.available || latest == null) return;
    final prefs = ref.read(prefsProvider);
    if (prefs.getString(_kUpdateNotified) == latest) return;
    prefs.setString(_kUpdateNotified, latest);
    showUpToast(context, context.l10n.settingsUpdateAvailableToast(latest));
  }

  @override
  void dispose() {
    _events?.cancel();
    _focus.dispose();
    super.dispose();
  }

  EngineClient get _engine => ref.read(engineProvider);

  void _onEngineEvent(EngineEvent e) {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (e) {
      case KitLoadedEvent():
        showUpToast(context, l10n.performKitLoaded);
      case ErrorEvent(:final error):
        final key = error is EngineNotImplemented
            ? error.function
            : error.code.name;
        if (_reported.add(key)) {
          showUpToast(
            context,
            error is EngineNotImplemented
                ? l10n.errorEngineUnsupported
                : l10n.errorGeneric,
          );
        }
      case RecorderEvent(:final track?):
        showSaveRecordingSheet(context, track);
      default:
        break;
    }
  }

  // ---------------------------------------------------------------- pads

  void _padDown(int bank, int index) {
    final id = PadId(bank, index);
    _engine.padDown(id); // 同步 FFI：只推命令进无锁队列，UI 不等回执
  }

  void _padUp(int bank, int index) => _engine.padUp(PadId(bank, index));

  /// 切换音色组：已触发的声音（包括 Loop）继续播放，只影响接下来触摸的 pad。
  void _selectGroup(int group) => ref.read(bankProvider.notifier).set(group);

  /// 键盘 Tab：依次切到下一组。
  void _nextGroup() {
    final v = ref.read(engineViewProvider);
    final count = groupCountOf(v.kit, v.pads);
    _selectGroup((ref.read(bankProvider) + 1) % count);
  }

  // ------------------------------------------------------------ keyboard

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!ref.read(settingsProvider).keyboardEnabled) {
      return KeyEventResult.ignored;
    }
    final key = e.physicalKey;
    final index = PadKeyboardMap.pads[key];
    if (e is KeyRepeatEvent) {
      return index != null ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (index != null) {
      final bank = ref.read(bankProvider);
      if (e is KeyDownEvent && !_heldKeys.containsKey(key)) {
        final flat = bank * PadId.padsPerBank + index;
        if (ref.read(engineViewProvider).pads[flat].isEmpty) {
          return KeyEventResult.handled;
        }
        _heldKeys[key] = flat;
        _padDown(bank, index);
        setState(() => _keyPressed.add(flat));
      } else if (e is KeyUpEvent) {
        final flat = _heldKeys.remove(key);
        if (flat != null) {
          _engine.padUp(PadId.flat(flat));
          setState(() => _keyPressed.remove(flat));
        }
      }
      return KeyEventResult.handled;
    }
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == PadKeyboardMap.switchBank) {
      _nextGroup();
    } else if (key == PadKeyboardMap.stopAll) {
      _engine.send(const StopAllCmd());
    } else if (key == PadKeyboardMap.record) {
      _toggleRecord();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------- actions

  void _toggleRecord() {
    final recording =
        ref.read(engineViewProvider).recorder == RecorderState.recording;
    _engine.send(
      recording ? const StopRecordingCmd() : const StartRecordingCmd(),
    );
  }

  void _shareKit() {
    final kit = ref.read(engineViewProvider).kit;
    if (kit == null) return;
    SharePlus.instance.share(
      ShareParams(text: context.l10n.shareKitMessage(kit.name)),
    );
  }

  // 首次引导（4.7.0 FirstGuide）的目标。
  final _gridKey = GlobalKey(debugLabel: 'guide-grid');
  final _groupsKey = GlobalKey(debugLabel: 'guide-groups');
  final _moreKey = GlobalKey(debugLabel: 'guide-more');
  final _songsKey = GlobalKey(debugLabel: 'guide-songs');

  List<FirstGuideStep> _guideSteps(BuildContext context) {
    final l10n = context.l10n;
    return [
      FirstGuideStep(
        target: _gridKey,
        text: l10n.tutorialFirstGuidePad,
        // 只高亮第一个 pad（网格左上角一格）。
        hole: (r) => Rect.fromLTWH(
          r.left,
          r.top,
          (r.width - (PadGrid.columns - 1) * UpPadTokens.gap) / PadGrid.columns,
          (r.height - (PadGrid.rows - 1) * UpPadTokens.gap) / PadGrid.rows,
        ),
      ),
      FirstGuideStep(target: _groupsKey, text: l10n.performFirstGuideGroups),
      FirstGuideStep(target: _moreKey, text: l10n.tutorialFirstGuideMore),
      FirstGuideStep(target: _songsKey, text: l10n.tutorialFirstGuideSongs),
    ];
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = UpTheme.of(context);
    final c = theme.colors;
    ref.listen(updateProvider, _onUpdate);
    final view = ref.watch(engineViewProvider.select(_performView));
    final bank = ref.watch(bankProvider);
    final settings = ref.watch(settingsProvider);
    final assets = ref.watch(privateAssetsProvider);
    final pads = padDataFrom(view.pads, view.padStates);
    final groupCount = groupCountOf(view.kit, view.pads);
    final recording = view.recorder == RecorderState.recording;

    final row = PerformToolbar(
      expanded: _toolsExpanded,
      recording: recording,
      recordElapsed: view.recordElapsed,
      hasKit: view.kit != null,
      groupCount: groupCount,
      group: bank.clamp(0, groupCount - 1),
      onGroup: _selectGroup,
      onExpand: (v) => setState(() => _toolsExpanded = v),
      onRecord: _toggleRecord,
      onSkins: () => showSkinsSheet(context),
      onEdit: () => context.push(Routes.editor),
      onShare: _shareKit,
      groupsKey: _groupsKey,
      moreKey: _moreKey,
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          _scaffold(
            context,
            c,
            l10n,
            view,
            row,
            pads,
            bank,
            settings,
            assets,
          ),
          // 首次引导：完成 / 跳过后写入设置。
          if (!settings.firstGuideSeen)
            Positioned.fill(
              child: FirstGuideOverlay(
                steps: _guideSteps(context),
                onDone: () =>
                    ref.read(settingsProvider.notifier).setFirstGuideSeen(true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scaffold(
    BuildContext context,
    UpSemantic c,
    UpL10n l10n,
    _PerformView view,
    Widget row,
    List<PadData> pads,
    int bank,
    AppSettings settings,
    PrivateAssets assets,
  ) {
    return Scaffold(
      backgroundColor: c.surfacePads,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, body) => Center(
            child: SizedBox(
              width: PerformLayout.columnWidth(body.biggest),
              child: Column(
                children: [
                  UpTopBar(
                    background: c.surfacePads,
                    leading: UpChip(
                      key: _songsKey,
                      label: l10n.navSongs,
                      icon: Icons.music_note_rounded,
                      variant: UpChipVariant.selected,
                      onTap: () => context.push(Routes.kits),
                    ),
                    titleWidget: _KitTitle(name: view.kit?.name),
                    trailing: [
                      // 顶栏最右：设置入口（4.7.0 btnYoutube 的位置）。
                      TopBarTileButton(
                        key: const ValueKey('perform-settings'),
                        icon: Icons.settings_rounded,
                        label: l10n.navSettings,
                        semanticLabel: l10n.navSettings,
                        onTap: () => context.push(Routes.settings),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: UpTopBarTokens.bankButtonSize,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: row),
                      ],
                    ),
                  ),
                  if (view.controllerMode) const _ControllerBanner(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        UpPadGridTokens.pageInset,
                        UpPadGridTokens.marginTop,
                        UpPadGridTokens.pageInset,
                        UpPadGridTokens.marginBottom,
                      ),
                      // 宽屏：按 4.7.0 fixed_height 等比计算网格尺寸并居中（PerformLayout）。
                      child: LayoutBuilder(
                        builder: (context, box) => Center(
                          child: SizedBox.fromSize(
                            key: _gridKey,
                            size: PerformLayout.gridSize(box.biggest),
                            child: PadGrid(
                              pads: pads,
                              bank: bank,
                              onPadDown: _padDown,
                              onPadUp: _padUp,
                              externallyPressed: _keyPressed,
                              lottie: settings.classicPads
                                  ? classicLottieSkin(assets)
                                  : null,
                              // image 类皮肤：注入了 4.7.0 位图时用位图。
                              image: imageSkinFor(assets, settings.skinId),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶栏标题：直接显示歌曲（Kit）名。
class _KitTitle extends StatelessWidget {
  const _KitTitle({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) => UpText(
    name ?? context.l10n.performNoKit,
    role: UpTextRole.title,
    color: UpTheme.of(context).colors.textPrimary,
  );
}

class _ControllerBanner extends ConsumerWidget {
  const _ControllerBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = UpTheme.of(context).colors;
    final hub = ref.watch(hubViewProvider);
    return Container(
      color: c.hubOnline,
      padding: const EdgeInsets.symmetric(
        horizontal: UpSpacing.xl,
        vertical: UpSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.cast_connected_rounded,
            size: UpSizes.iconSm,
            color: c.textOnAccent,
          ),
          const SizedBox(width: UpSpacing.sm),
          Expanded(
            child: UpText(
              context.l10n.hubControlling(hub.controllerPeer?.name ?? ''),
              role: UpTextRole.labelSm,
              color: c.textOnAccent,
            ),
          ),
          UpIconButton(
            icon: Icons.close_rounded,
            color: c.textOnAccent,
            semanticLabel: context.l10n.commonClose,
            onPressed: () =>
                tryEngine(ref.read(engineProvider).hubControllerDisconnect),
          ),
        ],
      ),
    );
  }
}
